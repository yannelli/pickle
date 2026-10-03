const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const apiModule = import("../ios/scripts/app-store-connect.mjs");
const distributionModule = import("../ios/scripts/distribute-testflight.mjs");

test("API signs fresh JWTs, bounds requests, and rejects foreign pagination URLs", async (t) => {
  const { createAppStoreConnectApi, paginate, resolveApp } = await apiModule;
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "dill-asc-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const { privateKey, publicKey } = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const keyPath = path.join(directory, "AuthKey_test.p8");
  fs.writeFileSync(keyPath, privateKey.export({ format: "pem", type: "pkcs8" }));
  const requests = [];
  let now = 1_800_000_000_000;
  const fetchApi = async (url, options) => {
    requests.push({ url, options });
    if (url.pathname === "/v1/apps") return Response.json({ data: [{ id: "app", attributes: { bundleId: "com.littledill.ios" } }] });
    return new Response(null, { status: 204 });
  };
  const api = createAppStoreConnectApi({ APPLE_API_KEY: "test", APPLE_API_ISSUER: "issuer", APPLE_API_KEY_PATH: keyPath }, fetchApi, () => now);
  assert.equal((await resolveApp(api, "com.littledill.ios")).id, "app");
  now += 20 * 60_000;
  assert.equal(await api("POST", "/v1/betaGroups/group/relationships/builds", { data: [] }), undefined);
  for (const [index, { url, options }] of requests.entries()) {
    assert.equal(url.origin, "https://api.appstoreconnect.apple.com");
    assert.equal(options.redirect, "error");
    assert.ok(options.signal instanceof AbortSignal);
    const [header, payload, signature] = options.headers.Authorization.slice(7).split(".");
    const claims = JSON.parse(Buffer.from(payload, "base64url"));
    assert.equal(claims.iat, 1_800_000_000 + index * 1200);
    assert.equal(claims.exp - claims.iat, 600);
    assert.equal(claims.aud, "appstoreconnect-v1");
    assert.ok(crypto.verify("sha256", Buffer.from(`${header}.${payload}`), { key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(signature, "base64url")));
  }
  await assert.rejects(api("GET", "https://example.com/v1/builds"), /Unexpected App Store Connect URL/);
  assert.equal(requests.length, 2);
  const pagedApi = createAppStoreConnectApi({ APPLE_API_KEY: "test", APPLE_API_ISSUER: "issuer", APPLE_API_KEY_PATH: keyPath },
    async () => Response.json({ data: [], links: { next: "https://example.com/v1/builds" } }));
  await assert.rejects(paginate(pagedApi, "/v1/builds"), /Unexpected App Store Connect URL/);
});

test("pagination follows every page and resolves the exact app", async () => {
  const { paginate, resolveApp } = await apiModule;
  const calls = [];
  const api = async (_method, route) => {
    calls.push(route);
    if (route.includes("cursor=2")) return { data: [{ id: "right", attributes: { bundleId: "com.littledill.ios" } }] };
    return { data: [{ id: "other", attributes: { bundleId: "com.other" } }], links: { next: "https://api.appstoreconnect.apple.com/v1/apps?cursor=2" } };
  };
  assert.equal((await resolveApp(api, "com.littledill.ios")).id, "right");
  assert.equal((await paginate(api, "/v1/apps?cursor=2")).length, 1);
  assert.equal(calls.length, 3);
});

function fixture() {
  const state = {
    processing: ["VALID"], external: "READY_FOR_BETA_SUBMISSION", expired: false,
    members: [], reviews: [], notify: false, clock: 0, notes: [], writes: [],
    ignoreNotes: false, ignoreAssignment: false, conflict: false, detailDelay: 0, readbackExternal: undefined,
  };
  const detail = () => ({ id: "detail", type: "buildBetaDetails", attributes: { externalBuildState: state.external, autoNotifyEnabled: state.notify } });
  const api = async (method, route, body) => {
    const url = new URL(route, "https://api.appstoreconnect.apple.com");
    const resource = url.pathname;
    if (method !== "GET") state.writes.push([method, resource]);
    if (method === "GET" && resource === "/v1/apps") return { data: [{ id: "app", attributes: { bundleId: "com.littledill.ios" } }] };
    if (method === "GET" && resource === "/v1/apps/app/betaGroups")
      return { data: [{ id: "group", attributes: { name: "Public Beta", isInternalGroup: false } }] };
    if (method === "GET" && resource === "/v1/builds") {
      assert.equal(url.searchParams.get("filter[app]"), "app");
      assert.equal(url.searchParams.get("filter[version]"), "7");
      assert.equal(url.searchParams.get("filter[preReleaseVersion.version]"), "1.2.3");
      assert.equal(url.searchParams.get("filter[preReleaseVersion.platform]"), "IOS");
      const processing = state.processing.length > 1 ? state.processing.shift() : state.processing[0];
      if (processing === "absent") return { data: [] };
      const build = { id: "build", attributes: { version: "7", processingState: processing, expired: state.expired },
        relationships: { app: { data: { id: "app" } }, preReleaseVersion: { data: { id: "release" } }, buildBetaDetail: { data: { id: "detail" } } } };
      return { data: [
        { ...build, id: "wrong-build", attributes: { ...build.attributes, version: "6" } },
        { ...build, id: "wrong-app", relationships: { ...build.relationships, app: { data: { id: "other" } } } },
        { ...build, id: "wrong-platform", relationships: { ...build.relationships, preReleaseVersion: { data: { id: "mac" } } } },
        build,
      ], included: [
        { id: "release", type: "preReleaseVersions", attributes: { version: "1.2.3", platform: "IOS" } },
        { id: "mac", type: "preReleaseVersions", attributes: { version: "1.2.3", platform: "MAC_OS" } },
        ...(state.detailDelay-- > 0 ? [] : [detail()]),
      ] };
    }
    if (method === "GET" && resource === "/v1/builds/build/betaBuildLocalizations") return { data: state.notes };
    if (method === "POST" && resource === "/v1/betaBuildLocalizations") {
      assert.equal(body.data.relationships.build.data.id, "build");
      if (!state.ignoreNotes) state.notes.push({ id: "english", attributes: body.data.attributes });
      return { data: { id: "english" } };
    }
    if (method === "PATCH" && resource === "/v1/betaBuildLocalizations/english") {
      Object.assign(state.notes.find((item) => item.id === "english").attributes, body.data.attributes);
      return { data: {} };
    }
    if (method === "PATCH" && resource === "/v1/buildBetaDetails/detail") {
      state.notify = body.data.attributes.autoNotifyEnabled;
      return { data: detail() };
    }
    if (method === "GET" && resource === "/v1/betaAppReviewSubmissions") return { data: state.reviews };
    if (method === "POST" && resource === "/v1/betaAppReviewSubmissions") {
      state.reviews.push({ attributes: { betaReviewState: "WAITING_FOR_REVIEW" } });
      state.external = "WAITING_FOR_BETA_REVIEW";
      if (state.conflict) throw Object.assign(new Error("Conflict"), { status: 409 });
      return { data: { id: "review" } };
    }
    if (resource === "/v1/betaGroups/group/relationships/builds") {
      if (method === "GET") return { data: state.members };
      if (!state.ignoreAssignment) state.members.push(...body.data);
      return undefined;
    }
    if (method === "GET" && resource === "/v1/builds/build/buildBetaDetail")
      return { data: { ...detail(), attributes: { ...detail().attributes, externalBuildState: state.readbackExternal ?? state.external } } };
    throw new Error(`Unexpected ${method} ${route}`);
  };
  const options = { api, version: "1.2.3", buildNumber: "7", notes: "Little Dill 1.2.3 (7): Try the arena.",
    now: () => state.clock, timeoutMs: 100, pollMs: 10,
    sleep: async (ms) => { state.clock += ms; }, log: () => {} };
  return { state, options };
}

test("distribution waits for the exact build, writes notes and review, and reads back external state", async () => {
  const { distributeTestFlight } = await distributionModule;
  const { state, options } = fixture();
  state.processing = ["absent", "PROCESSING", "VALID"];
  state.detailDelay = 1;
  state.notes.push({ id: "german", attributes: { locale: "de", whatsNew: "Keep" } });
  const result = await distributeTestFlight(options);
  assert.deepEqual(result, { buildId: "build", groupId: "group", externalBuildState: "WAITING_FOR_BETA_REVIEW" });
  assert.deepEqual(state.writes.map((item) => item[1]), [
    "/v1/betaBuildLocalizations", "/v1/buildBetaDetails/detail", "/v1/betaAppReviewSubmissions", "/v1/betaGroups/group/relationships/builds",
  ]);
  assert.equal(state.notes[0].attributes.whatsNew, "Keep");
  state.writes = [];
  await distributeTestFlight(options);
  assert.deepEqual(state.writes, []);
});

test("distribution reconciles review conflict and patches existing English notes", async () => {
  const { distributeTestFlight } = await distributionModule;
  const { state, options } = fixture();
  state.conflict = true;
  state.notes.push({ id: "english", attributes: { locale: "en-US", whatsNew: "Old" } });
  await distributeTestFlight(options);
  assert.equal(state.notes[0].attributes.whatsNew, options.notes);
  assert.equal(state.writes[0][0], "PATCH");
});

test("prerelease notes use the full version file while Apple matches the base version", async (t) => {
  const { distributeTestFlight, loadTestNotes } = await distributionModule;
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "dill-prerelease-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.mkdirSync(path.join(directory, "docs/testflight"), { recursive: true });
  fs.writeFileSync(path.join(directory, "docs/testflight/1.2.3-beta.2.md"), "Try the arena.");
  const { state, options } = fixture();
  options.version = "1.2.3-beta.2";
  options.notes = loadTestNotes(options.version, options.buildNumber, directory);
  assert.equal(options.notes, "Little Dill 1.2.3 (7): Try the arena.");
  const result = await distributeTestFlight(options);
  assert.equal(result.externalBuildState, "WAITING_FOR_BETA_REVIEW");
  assert.equal(state.notes[0].attributes.whatsNew, options.notes);
  assert.throws(() => loadTestNotes("1.2.3-beta.3", "7", directory), /ENOENT/);
  for (const suffix of ["alpha.1", "rc.3"]) {
    fs.writeFileSync(path.join(directory, `docs/testflight/1.2.3-${suffix}.md`), "Try the arena.");
    assert.equal(loadTestNotes(`1.2.3-${suffix}`, "7", directory), options.notes);
  }
});

test("final readback rejects failed, expired, and unsupported external states", async () => {
  const { distributeTestFlight } = await distributionModule;
  for (const external of ["BETA_REJECTED", "EXPIRED", "UNKNOWN"]) {
    const { state, options } = fixture();
    state.readbackExternal = external;
    await assert.rejects(distributeTestFlight(options), new RegExp(external));
  }
});

test("distribution fails invalid, expired, rejected, timeout, and failed readback states", async () => {
  const { distributeTestFlight } = await distributionModule;
  for (const [change, message] of [
    [(s) => { s.processing = ["INVALID"]; }, /INVALID/],
    [(s) => { s.expired = true; }, /expired/],
    [(s) => { s.external = "BETA_REJECTED"; }, /BETA_REJECTED/],
    [(s) => { s.processing = ["PROCESSING"]; }, /Timed out/],
    [(s) => { s.ignoreNotes = true; }, /failed verification/],
    [(s) => { s.ignoreAssignment = true; }, /failed verification/],
  ]) {
    const { state, options } = fixture();
    change(state);
    await assert.rejects(distributeTestFlight(options), message);
    if (!state.ignoreNotes && !state.ignoreAssignment) assert.equal(state.writes.length, 0);
  }
});

test("notes use the exact version file, prefix, and length limit", async (t) => {
  const { loadTestNotes } = await distributionModule;
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "dill-notes-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.mkdirSync(path.join(directory, "docs/testflight"), { recursive: true });
  const file = path.join(directory, "docs/testflight/1.2.3.md");
  fs.writeFileSync(file, "Try the arena.\n");
  assert.equal(loadTestNotes("1.2.3", "7", directory), "Little Dill 1.2.3 (7): Try the arena.");
  assert.throws(() => loadTestNotes("1.2.4", "7", directory), /ENOENT/);
  assert.throws(() => loadTestNotes("1.2.3", "0", directory), /positive integer/);
  fs.writeFileSync(file, "x".repeat(4000));
  assert.throws(() => loadTestNotes("1.2.3", "7", directory), /1 to 4000/);
});
