import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

export const bundleId = 'com.littledill.ios';
export const teamId = '2P58V89SR7';
export const root = fileURLToPath(new URL('../../', import.meta.url));

export function releaseVersion(project, generatedProject, refType, refName) {
  const marketing = project.match(/^\s+MARKETING_VERSION: "(\d+\.\d+\.\d+)"$/m)?.[1];
  const generated = [...generatedProject.matchAll(/MARKETING_VERSION = ([\d.]+);/g)];
  if (!marketing || !generated.length || generated.some((match) => match[1] !== marketing))
    throw new Error('Regenerate the Xcode project with the matching MARKETING_VERSION');
  if (refType !== 'tag') return marketing;
  const version = refName.match(/^v((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?:alpha|beta|rc)\.[1-9]\d*)?)$/)?.[1];
  if (!version || version.split('-')[0] !== marketing)
    throw new Error('Release tag must match MARKETING_VERSION: vX.Y.Z or vX.Y.Z-beta.N');
  return version;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const version = releaseVersion(
    fs.readFileSync(`${root}/ios/project.yml`, 'utf8'),
    fs.readFileSync(`${root}/ios/LittleDill.xcodeproj/project.pbxproj`, 'utf8'),
    process.env.GITHUB_REF_TYPE, process.env.GITHUB_REF_NAME,
  );
  const output = `version=${version}\nmarketing_version=${version.split('-')[0]}\n`;
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, output);
  else process.stdout.write(output);
}
