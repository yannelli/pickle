import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createAppStoreConnectApi, paginate, resolveApp } from './app-store-connect.mjs';
import { bundleId } from './release-config.mjs';

export function nextBuildNumber(values, minimum = '1') {
  if (!/^[1-9]\d*$/.test(String(minimum))) throw new Error('IOS_BUILD_NUMBER_MIN must be a positive integer');
  let highest = Number(minimum) - 1;
  for (const value of values) {
    if (!/^\d+(?:\.\d+){0,2}$/.test(String(value))) throw new Error('Unexpected Apple build number');
    highest = Math.max(highest, Number(String(value).split('.')[0]));
  }
  if (!Number.isSafeInteger(highest + 1)) throw new Error('Build number exceeds the safe integer range');
  return String(highest + 1);
}

export async function selectBuildNumber(api, minimum) {
  const app = await resolveApp(api, bundleId);
  const builds = await paginate(api, `/v1/builds?filter[app]=${app.id}&limit=200`);
  const uploads = await paginate(api, `/v1/apps/${app.id}/buildUploads?limit=200`);
  return nextBuildNumber([
    ...builds.map((build) => build.attributes.version),
    ...uploads.map((upload) => upload.attributes.cfBundleVersion),
  ], minimum);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const number = await selectBuildNumber(createAppStoreConnectApi(), process.env.IOS_BUILD_NUMBER_MIN || '1');
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, `build_number=${number}\n`);
  console.log(`Selected iOS build ${number}`);
}
