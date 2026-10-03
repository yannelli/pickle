import copy
import datetime
import importlib.util
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "signing", Path(__file__).resolve().parents[1] / "ios/scripts/signing-profile.py")
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.profile = {
            "UUID": "00000000-0000-0000-0000-000000000001",
            "ExpirationDate": datetime.datetime(2099, 1, 1),
            "TeamIdentifier": [signing.TEAM_ID],
            "Entitlements": {
                "application-identifier": f"{signing.TEAM_ID}.{signing.BUNDLE_ID}",
                "com.apple.developer.team-identifier": signing.TEAM_ID,
                "get-task-allow": False,
                "beta-reports-active": True,
                "com.apple.developer.associated-domains": [signing.DOMAIN],
            },
        }

    def test_accepts_matching_app_store_profile(self):
        self.assertEqual(signing.validate_profile(self.profile), self.profile["UUID"])
        self.profile["Entitlements"]["com.apple.developer.associated-domains"] = ["*"]
        signing.validate_profile(self.profile)

    def test_rejects_wrong_team_expired_and_device_profiles(self):
        for key, value in [("TeamIdentifier", ["OTHER"]), ("ExpirationDate", datetime.datetime(2000, 1, 1)),
                           ("ProvisionedDevices", ["device"]), ("ProvisionsAllDevices", True),
                           ("IsXcodeManaged", True), ("UUID", "../profile")]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                signing.validate_profile({**self.profile, key: value})

    def test_rejects_wrong_entitlements(self):
        for key, value in [("application-identifier", "other.app"), ("get-task-allow", True),
                           ("beta-reports-active", False), ("com.apple.developer.associated-domains", [])]:
            profile = copy.deepcopy(self.profile)
            profile["Entitlements"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                signing.validate_profile(profile)

    def test_export_preserves_selected_build(self):
        options = signing.export_options(self.profile["UUID"])
        self.assertFalse(options["manageAppVersionAndBuildNumber"])
        self.assertEqual(options["method"], "app-store-connect")
        self.assertEqual(options["provisioningProfiles"][signing.BUNDLE_ID], self.profile["UUID"])

    def test_exported_app_matches_version_and_entitlements(self):
        info = {"CFBundleIdentifier": signing.BUNDLE_ID,
                "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "25"}
        signing.validate_app(info, self.profile["Entitlements"], "1.0.0", "25")
        for key in info:
            with self.subTest(key=key), self.assertRaises(ValueError):
                signing.validate_app({**info, key: "wrong"}, self.profile["Entitlements"], "1.0.0", "25")
        with self.assertRaises(ValueError):
            signing.validate_app(info, {}, "1.0.0", "25")


if __name__ == "__main__":
    unittest.main()
