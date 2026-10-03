import crypto from "node:crypto";
import fs from "node:fs";

const origin = "https://api.appstoreconnect.apple.com";

export function createAppStoreConnectApi(env = process.env, fetchApi = fetch, now = Date.now) {
  const { APPLE_API_KEY, APPLE_API_ISSUER, APPLE_API_KEY_PATH } = env;
  for (const [name, value] of Object.entries({ APPLE_API_KEY, APPLE_API_ISSUER, APPLE_API_KEY_PATH }))
    if (!value) throw new Error(`Set ${name}`);
  const key = fs.readFileSync(APPLE_API_KEY_PATH);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  return async (method, path, body) => {
    const url = new URL(path, origin);
    if (url.origin !== origin || !url.pathname.startsWith("/v1/") || url.username || url.password)
      throw new Error("Unexpected App Store Connect URL");
    const issued = Math.floor(now() / 1000);
    const unsigned = `${encode({ alg: "ES256", kid: APPLE_API_KEY, typ: "JWT" })}.${encode({ iss: APPLE_API_ISSUER, iat: issued, exp: issued + 600, aud: "appstoreconnect-v1" })}`;
    const signature = crypto.sign("sha256", Buffer.from(unsigned), { key, dsaEncoding: "ieee-p1363" }).toString("base64url");
    const response = await fetchApi(url, {
      method,
      headers: { Authorization: `Bearer ${unsigned}.${signature}`, "Content-Type": "application/json" },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      signal: AbortSignal.timeout(30_000),
      redirect: "error",
    });
    if (!response.ok) {
      const error = new Error(`App Store Connect ${method} ${url.pathname} returned ${response.status}: ${await response.text()}`);
      error.status = response.status;
      throw error;
    }
    return response.status === 204 ? undefined : response.json();
  };
}

export async function paginate(api, path) {
  const entries = [];
  const visited = new Set();
  while (path) {
    if (visited.has(path)) throw new Error("App Store Connect pagination loop");
    visited.add(path);
    const response = await api("GET", path);
    entries.push(...response.data);
    path = response.links?.next;
  }
  return entries;
}

export async function resolveApp(api, bundleId) {
  const query = new URLSearchParams({ "filter[bundleId]": bundleId, limit: "200" });
  const matches = (await paginate(api, `/v1/apps?${query}`)).filter((app) => app.attributes.bundleId === bundleId);
  if (matches.length !== 1) throw new Error(`Expected one App Store Connect app for ${bundleId}`);
  return matches[0];
}
