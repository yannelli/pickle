# Test saves

Generated: 2026-09-15T22:19:18.905Z

1. Open the app over HTTPS or localhost.
2. Choose Import save and select a `.dill` file from this folder.
3. Check the preview, then choose Restore this pickle.

Imports replace the current pickle. Undo import restores it during the same page visit.

Saves use real elapsed time. Regenerate before testing to reset ages, care conditions, and countdowns:

```sh
node tests/generate-saves.cjs
```

Run the command from the repository root with Node 24. It overwrites the generated saves in this folder.

| File | Starting condition |
| --- | --- |
| [new.dill](new.dill) | Choose a brine. |
| [brining.dill](brining.dill) | Hatches 1 minute after generation. |
| [naming.dill](naming.dill) | Unnamed hatchling, ready to name. |
| [baby.dill](baby.dill) | 0 days old. |
| [young.dill](young.dill) | 1 days old. |
| [adult.dill](adult.dill) | 3 days old. |
| [elder-first.dill](elder-first.dill) | Grandill, 14 days old. |
| [elder-last.dill](elder-last.dill) | The Eternal Dill, 107 days old. |
| [elder-second-lap.dill](elder-second-lap.dill) | Grandill, 110 days old. |
| [variety-gherkin.dill](variety-gherkin.dill) | Tiny Gherkin, adult. |
| [variety-garlic.dill](variety-garlic.dill) | Garlic Goblin, adult. |
| [variety-butter.dill](variety-butter.dill) | Butter Bean, adult. |
| [variety-chili.dill](variety-chili.dill) | Chili Dill, adult. |
| [variety-pepper.dill](variety-pepper.dill) | Pepper Punk, adult. |
| [sleeping.dill](sleeping.dill) | Adult asleep with 10 energy. |
| [low-energy.dill](low-energy.dill) | Adult awake with 0 energy; arcade entry is unavailable. |
| [sick.dill](sick.dill) | Adult with 5 food; feed to recover. |
| [near-death.dill](near-death.dill) | Empty food; 1 hour remains before death at generation. |
| [dead.dill](dead.dill) | Adult dead from neglect. |
| [eaten.dill](eaten.dill) | Adult after eating confirmation. |
| [legacy-v1.dill](legacy-v1.dill) | Encrypted v1 save; imports as a living elder named Little Dill. |

The baby, young, adult, and elder saves use Classic Dill. The variety files cover the other 5 varieties.
