import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { setTimeout } from "node:timers/promises";
import { createAppStoreConnectApi, paginate, resolveApp } from "./app-store-connect.mjs";

const root = fileURLToPath(new URL("../../", import.meta.url));
const bundleId = "com.littledill.ios";
const readyStates = new Set([
  "READY_FOR_BETA_SUBMISSION", "WAITING_FOR_BETA_REVIEW", "IN_BETA_REVIEW",
  "BETA_APPROVED", "READY_FOR_BETA_TESTING", "IN_BETA_TESTING",
]);
const pendingStates = new Set(["PROCESSING", "IN_EXPORT_COMPLIANCE_REVIEW"]);
const acceptedReviews = new Set(["WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED"]);
const versionPattern = /^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?:alpha|beta|rc)\.[1-9]\d*)?$/;

export function loadTestNotes(version, buildNumber, directory = root) {
  if (!versionPattern.test(version) || !/^[1-9]\d*$/.test(String(buildNumber)))
    throw new Error("Pass --version X.Y.Z[-(alpha|beta|rc).N] and --build as a positive integer");
  const file = path.join(directory, "docs/testflight", `${version}.md`);
  const body = fs.readFileSync(file, "utf8").trim();
  const notes = `Little Dill ${version.split("-")[0]} (${buildNumber}): ${body}`;
  if (!body || notes.length > 4000) throw new Error(`Testing notes must contain 1 to 4000 characters: ${file}`);
  return notes;
}

async function findBuild(api, appId, version, buildNumber) {
  const query = new URLSearchParams({
    "filter[app]": appId, "filter[version]": String(buildNumber),
    "filter[preReleaseVersion.version]": version, "filter[preReleaseVersion.platform]": "IOS",
    include: "preReleaseVersion,buildBetaDetail", limit: "200",
  });
  let next = `/v1/builds?${query}`;
  const matches = [];
  const visited = new Set();
  while (next) {
    if (visited.has(next)) throw new Error("App Store Connect pagination loop");
    visited.add(next);
    const response = await api("GET", next);
    for (const build of response.data) {
      const release = response.included?.find((item) => item.type === "preReleaseVersions" && item.id === build.relationships?.preReleaseVersion?.data?.id);
      if (build.attributes.version !== String(buildNumber) || release?.attributes.version !== version || release.attributes.platform !== "IOS") continue;
      if (build.relationships?.app?.data?.id && build.relationships.app.data.id !== appId) continue;
      const detail = response.included?.find((item) => item.type === "buildBetaDetails" && item.id === build.relationships?.buildBetaDetail?.data?.id);
      matches.push({ build, detail });
    }
    next = response.links?.next;
  }
  if (matches.length > 1) throw new Error("Multiple builds match the app, version, build number, and platform");
  return matches[0];
}

async function waitForBuild(api, appId, version, buildNumber, { sleep, now, timeoutMs, pollMs, log }) {
  const deadline = now() + timeoutMs;
  while (now() < deadline) {
    const match = await findBuild(api, appId, version, buildNumber);
    const { build, detail } = match ?? {};
    if (build?.attributes.expired) throw new Error("The uploaded TestFlight build has expired");
    const processing = build?.attributes.processingState;
    if (build && !["PROCESSING", "VALID"].includes(processing))
      throw new Error(`TestFlight processing failed: ${processing}`);
    const external = detail?.attributes.externalBuildState;
    if (processing === "VALID" && detail && !pendingStates.has(external)) {
      if (!readyStates.has(external)) throw new Error(`Cannot distribute TestFlight build in state ${external}`);
      return match;
    }
    log(`Waiting for TestFlight ${version} (${buildNumber}): ${external ?? processing ?? "not visible"}`);
    await sleep(Math.min(pollMs, Math.max(0, deadline - now())));
  }
  throw new Error("Timed out waiting for TestFlight processing");
}

async function saveNotes(api, buildId, notes) {
  const route = `/v1/builds/${buildId}/betaBuildLocalizations?limit=200`;
  const locale = (await paginate(api, route)).find((item) => item.attributes.locale === "en-US");
  if (locale && locale.attributes.whatsNew !== notes)
    await api("PATCH", `/v1/betaBuildLocalizations/${locale.id}`, {
      data: { type: "betaBuildLocalizations", id: locale.id, attributes: { whatsNew: notes } },
    });
  else if (!locale)
    await api("POST", "/v1/betaBuildLocalizations", {
      data: { type: "betaBuildLocalizations", attributes: { locale: "en-US", whatsNew: notes },
        relationships: { build: { data: { type: "builds", id: buildId } } } },
    });
  return route;
}

async function submitReview(api, buildId) {
  const route = `/v1/betaAppReviewSubmissions?filter[build]=${encodeURIComponent(buildId)}&limit=200`;
  const status = async () => {
    const reviews = await paginate(api, route);
    if (reviews.some((item) => item.attributes.betaReviewState === "REJECTED")) throw new Error("TestFlight beta review was rejected");
    return reviews.some((item) => acceptedReviews.has(item.attributes.betaReviewState));
  };
  if (await status()) return;
  try {
    await api("POST", "/v1/betaAppReviewSubmissions", {
      data: { type: "betaAppReviewSubmissions", relationships: { build: { data: { type: "builds", id: buildId } } } },
    });
  } catch (error) {
    if (error.status !== 409 || !(await status())) throw error;
  }
}

export async function distributeTestFlight({
  api, identifier = bundleId, version, buildNumber, notes, groupName = process.env.TESTFLIGHT_GROUP || "Public Beta",
  sleep = setTimeout, now = Date.now, timeoutMs = 30 * 60_000, pollMs = 30_000, log = console.log,
}) {
  if (!versionPattern.test(version) || !/^[1-9]\d*$/.test(String(buildNumber)) || !notes?.trim() || notes.length > 4000)
    throw new Error("Invalid TestFlight version, build number, or testing notes");
  const app = await resolveApp(api, identifier);
  const groups = (await paginate(api, `/v1/apps/${app.id}/betaGroups?limit=200`))
    .filter((group) => group.attributes.name === groupName && group.attributes.isInternalGroup === false);
  if (groups.length !== 1) throw new Error(`Expected one external ${groupName} group for this app`);
  const group = groups[0];
  const { build, detail } = await waitForBuild(api, app.id, version.split("-")[0], buildNumber, { sleep, now, timeoutMs, pollMs, log });
  const notesRoute = await saveNotes(api, build.id, notes);
  if (!detail.attributes.autoNotifyEnabled)
    await api("PATCH", `/v1/buildBetaDetails/${detail.id}`, {
      data: { type: "buildBetaDetails", id: detail.id, attributes: { autoNotifyEnabled: true } },
    });
  if (detail.attributes.externalBuildState === "READY_FOR_BETA_SUBMISSION") await submitReview(api, build.id);
  const membershipRoute = `/v1/betaGroups/${group.id}/relationships/builds?limit=200`;
  if (!(await paginate(api, membershipRoute)).some((item) => item.id === build.id))
    await api("POST", `/v1/betaGroups/${group.id}/relationships/builds`, {
      data: [{ type: "builds", id: build.id }],
    });
  const savedNotes = (await paginate(api, notesRoute)).find((item) => item.attributes.locale === "en-US");
  const membership = await paginate(api, membershipRoute);
  const savedDetail = (await api("GET", `/v1/builds/${build.id}/buildBetaDetail`)).data.attributes;
  if (savedNotes?.attributes.whatsNew !== notes || !membership.some((item) => item.id === build.id) || !savedDetail.autoNotifyEnabled)
    throw new Error("TestFlight notes, group assignment, or automatic notification failed verification");
  if (!readyStates.has(savedDetail.externalBuildState))
    throw new Error(`Cannot distribute TestFlight build in state ${savedDetail.externalBuildState}`);
  log(`TestFlight ${version} (${buildNumber}) assigned to ${groupName}; external state: ${savedDetail.externalBuildState}`);
  return { buildId: build.id, groupId: group.id, externalBuildState: savedDetail.externalBuildState };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { values } = parseArgs({ options: {
    version: { type: "string" }, build: { type: "string" }, "check-notes": { type: "boolean" },
  } });
  const notes = loadTestNotes(values.version, values.build);
  if (values["check-notes"]) console.log(notes);
  else await distributeTestFlight({
    api: createAppStoreConnectApi(), version: values.version, buildNumber: values.build, notes,
  });
}
