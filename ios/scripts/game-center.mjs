import { fileURLToPath } from "node:url";
import { createAppStoreConnectApi, paginate, resolveApp } from "./app-store-connect.mjs";
import { bundleId } from "./release-config.mjs";

// Keep these IDs in sync with GameCenter.Board in ios/LittleDill/GameCenter.swift.
export const leaderboards = [
  { id: "ld.arena.mass", name: "Brine Royale biggest dill", suffix: " mass" },
  { id: "ld.daily", name: "Daily crunch", suffix: " pts" },
  { id: "ld.arcade.hunt", name: "Heart hunt", suffix: " pts" },
  { id: "ld.arcade.memory", name: "Dill says", suffix: " pts" },
  { id: "ld.arcade.catch", name: "Brine catch", suffix: " pts" },
  { id: "ld.arcade.hop", name: "Countertop escape", suffix: " pts" },
  { id: "ld.arcade.chop", name: "Cuke chop", suffix: " pts" },
  { id: "ld.arcade.toss", name: "Jar toss", suffix: " pts" },
];

async function ensureCapability(api, log) {
  const ids = (await paginate(api, `/v1/bundleIds?${new URLSearchParams({ "filter[identifier]": bundleId })}`))
    .filter((entry) => entry.attributes.identifier === bundleId);
  if (ids.length !== 1) throw new Error(`Expected one bundle ID for ${bundleId}`);
  const capabilities = await paginate(api, `/v1/bundleIds/${ids[0].id}/bundleIdCapabilities`);
  if (capabilities.some((entry) => entry.attributes.capabilityType === "GAME_CENTER")) return;
  await api("POST", "/v1/bundleIdCapabilities", { data: {
    type: "bundleIdCapabilities", attributes: { capabilityType: "GAME_CENTER" },
    relationships: { bundleId: { data: { type: "bundleIds", id: ids[0].id } } },
  } });
  log("Enabled Game Center on the App ID. Create a new App Store profile before the next release.");
}

export async function syncGameCenter(api, log = console.log) {
  await ensureCapability(api, log);
  const app = await resolveApp(api, bundleId);
  const detail = (await api("GET", `/v1/apps/${app.id}/gameCenterDetail`)).data;
  const existing = new Set((await paginate(api, `/v1/gameCenterDetails/${detail.id}/gameCenterLeaderboards?limit=200`))
    .map((entry) => entry.attributes.vendorIdentifier));
  for (const board of leaderboards) {
    if (existing.has(board.id)) continue;
    const created = await api("POST", "/v1/gameCenterLeaderboards", { data: {
      type: "gameCenterLeaderboards",
      attributes: { referenceName: board.name, vendorIdentifier: board.id, defaultFormatter: "INTEGER", submissionType: "BEST_SCORE", scoreSortType: "DESC" },
      relationships: { gameCenterDetail: { data: { type: "gameCenterDetails", id: detail.id } } },
    } });
    await api("POST", "/v1/gameCenterLeaderboardLocalizations", { data: {
      type: "gameCenterLeaderboardLocalizations",
      attributes: { locale: "en-US", name: board.name, formatterSuffix: board.suffix, formatterSuffixSingular: board.suffix },
      relationships: { gameCenterLeaderboard: { data: { type: "gameCenterLeaderboards", id: created.data.id } } },
    } });
    log(`Created leaderboard ${board.id}`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await syncGameCenter(createAppStoreConnectApi());
