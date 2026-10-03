const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');

const project = '    MARKETING_VERSION: "1.0.0"\n';
const generated = 'MARKETING_VERSION = 1.0.0;\nMARKETING_VERSION = 1.0.0;';

test('release tags match both checked-in version sources', async () => {
  const { releaseVersion } = await import('../ios/scripts/release-config.mjs');
  assert.equal(releaseVersion(project, generated, 'branch', 'main'), '1.0.0');
  for (const suffix of ['', '-alpha.1', '-beta.2', '-rc.3'])
    assert.equal(releaseVersion(project, generated, 'tag', `v1.0.0${suffix}`), `1.0.0${suffix}`);
  for (const tag of ['v2.0.0', 'v1.0', 'v1.0.0-../../secret', 'v1.0.0-beta.0', 'v01.0.0'])
    assert.throws(() => releaseVersion(project, generated, 'tag', tag));
  assert.throws(() => releaseVersion(project, `${generated}\nMARKETING_VERSION = 0.9.0;`, 'branch', 'main'));
});

test('build numbering includes every page and in-progress uploads', async () => {
  const { selectBuildNumber } = await import('../ios/scripts/build-number.mjs');
  const calls = [];
  const api = async (method, route) => {
    assert.equal(method, 'GET');
    calls.push(route);
    if (route.startsWith('/v1/apps?')) return { data: [{ id: 'app', attributes: { bundleId: 'com.littledill.ios' } }] };
    if (route.startsWith('/v1/builds?')) return { data: [{ attributes: { version: '7' } }], links: { next: '/v1/builds-page2' } };
    if (route === '/v1/builds-page2') return { data: [{ attributes: { version: '23' } }] };
    if (route === '/v1/apps/app/buildUploads?limit=200')
      return { data: [{ attributes: { cfBundleVersion: '30' } }], links: { next: '/v1/uploads-page2' } };
    if (route === '/v1/uploads-page2') return { data: [{ attributes: { cfBundleVersion: '35' } }] };
    throw new Error(route);
  };
  assert.equal(await selectBuildNumber(api, '1'), '36');
  assert.equal(calls.length, 5);
});

test('build number floor supports recovery and rejects malformed values', async () => {
  const { nextBuildNumber } = await import('../ios/scripts/build-number.mjs');
  assert.equal(nextBuildNumber([]), '1');
  assert.equal(nextBuildNumber(['9', '12.3.1'], '20'), '20');
  assert.equal(nextBuildNumber(['20'], '20'), '21');
  for (const value of ['oops', '', '12beta', '-2']) assert.throws(() => nextBuildNumber([value]));
  for (const minimum of ['0', '-1', '2.1', 'NaN']) assert.throws(() => nextBuildNumber([], minimum));
});

test('an Apple lookup failure stops build allocation', async () => {
  const { selectBuildNumber } = await import('../ios/scripts/build-number.mjs');
  await assert.rejects(selectBuildNumber(async () => { throw new Error('Apple unavailable'); }), /Apple unavailable/);
});

test('branch validation cannot upload or distribute and PR checks have no secrets', () => {
  const root = path.resolve(__dirname, '..');
  const read = (name) => JSON.parse(execFileSync('ruby', ['-rjson', '-ryaml', '-e',
    'puts JSON.generate(YAML.load_file(ARGV[0]))', path.join(root, '.github/workflows', name)], { encoding: 'utf8' }));
  const workflow = read('testflight.yml');
  const triggers = workflow.on || workflow.true;
  assert.deepEqual(triggers.push, { tags: ['v*'] });
  assert.ok(Object.hasOwn(triggers, 'workflow_dispatch'));
  assert.equal(workflow.concurrency['cancel-in-progress'], false);
  assert.equal(workflow.concurrency.group, 'testflight-com-littledill-ios');
  const steps = workflow.jobs.release.steps;
  for (const name of ['Upload to TestFlight', 'Process and distribute external beta'])
    assert.equal(steps.find((step) => step.name === name).if, "github.ref_type == 'tag'");
  assert.equal(steps.find((step) => step.name === 'Remove signing material').if, 'always()');
  assert.equal(workflow.jobs.release.needs, 'checks');
  assert.equal(workflow.permissions.contents, 'read');
  const checks = fs.readFileSync(path.join(root, '.github/workflows/checks.yml'), 'utf8');
  assert.ok(!checks.includes('secrets.'));
  assert.ok(!checks.includes('pull_request_target'));
  assert.ok(!checks.includes('--upload-app'));
  assert.ok(read('checks.yml').jobs.ios.steps.some((step) => step.run?.includes('-only-testing:LittleDillTests')));
});
