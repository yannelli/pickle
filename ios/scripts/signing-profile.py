import datetime
import hashlib
import os
from pathlib import Path
import plistlib
import re
import sys

BUNDLE_ID = "com.littledill.ios"
TEAM_ID = "2P58V89SR7"
DOMAIN = "applinks:arena.littledill.app"


def validate_profile(profile, now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc)
    expiry = profile["ExpirationDate"].replace(tzinfo=datetime.timezone.utc)
    entitlements = profile["Entitlements"]
    if expiry <= now:
        raise ValueError("The App Store provisioning profile has expired")
    if profile.get("TeamIdentifier") != [TEAM_ID]:
        raise ValueError("The profile must belong to Little Dill's team")
    if entitlements.get("application-identifier") != f"{TEAM_ID}.{BUNDLE_ID}":
        raise ValueError("The profile must match Little Dill's bundle identifier")
    if (profile.get("ProvisionedDevices") is not None or profile.get("ProvisionsAllDevices")
            or entitlements.get("get-task-allow") or not entitlements.get("beta-reports-active")
            or profile.get("IsXcodeManaged")):
        raise ValueError("A manual App Store distribution profile is required")
    domains = entitlements.get("com.apple.developer.associated-domains", [])
    if "*" not in domains and DOMAIN not in domains:
        raise ValueError("The profile must support Little Dill's Associated Domains")
    if not re.fullmatch(r"[A-Fa-f0-9-]{36}", profile["UUID"]):
        raise ValueError("Invalid provisioning profile UUID")
    return profile["UUID"]


def export_options(uuid):
    return {
        "method": "app-store-connect", "destination": "export",
        "teamID": TEAM_ID, "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {BUNDLE_ID: uuid},
        "manageAppVersionAndBuildNumber": False, "uploadSymbols": True,
    }


def validate_app(info, entitlements, version, build):
    expected = {"CFBundleIdentifier": BUNDLE_ID, "CFBundleShortVersionString": version,
                "CFBundleVersion": build}
    if any(info.get(key) != value for key, value in expected.items()):
        raise ValueError("Exported IPA bundle identifier, version, or build differs from the selected release")
    if (entitlements.get("application-identifier") != f"{TEAM_ID}.{BUNDLE_ID}"
            or entitlements.get("com.apple.developer.team-identifier") != TEAM_ID
            or entitlements.get("get-task-allow")
            or not entitlements.get("beta-reports-active")
            or DOMAIN not in entitlements.get("com.apple.developer.associated-domains", [])):
        raise ValueError("Exported IPA has incorrect distribution entitlements")


def read_plist(file):
    with open(file, "rb") as stream:
        return plistlib.load(stream)


if __name__ == "__main__":
    mode, directory = sys.argv[1:3]
    directory = Path(directory)
    profile = read_plist(directory / "profile.plist")
    uuid = validate_profile(profile)
    if mode == "prepare":
        identities = (directory / "identities.txt").read_text()
        allowed = [hashlib.sha1(cert).hexdigest().upper() for cert in profile["DeveloperCertificates"]]
        matches = [identity for identity in allowed if re.search(
            rf'\b{identity}\b\s+"Apple Distribution:', identities)]
        if len(matches) != 1:
            raise ValueError("The keychain must contain one valid Apple Distribution identity matching the profile")
        with open(directory / "ExportOptions.plist", "wb") as stream:
            plistlib.dump(export_options(uuid), stream)
        with open(os.environ["GITHUB_ENV"], "a") as stream:
            stream.write(f"PROFILE_UUID={uuid}\nSIGNING_IDENTITY={matches[0]}\n")
    elif mode == "verify":
        validate_app(read_plist(directory / "app-info.plist"),
                     read_plist(directory / "app-entitlements.plist"), *sys.argv[3:5])
        signer = (directory / "signer0").read_bytes()
        if signer not in profile["DeveloperCertificates"]:
            raise ValueError("The exported signer is absent from the embedded profile")
    else:
        raise ValueError("Unknown signing operation")
