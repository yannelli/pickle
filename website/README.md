# Little Dill website

The game introduction lives in `public/` and deploys as its own Cloudflare Worker. The playable game stays in the repository root with a separate deployment. No build step or package dependencies.

Run from `website/` with Node.js and Wrangler available:

```sh
npx wrangler dev
```

Open the address Wrangler prints. To deploy:

```sh
npx wrangler deploy
```

For Cloudflare Git integration, set the root directory to `website`, leave the build command empty, and use `npx wrangler deploy` as the deploy command. Add a custom domain in Cloudflare after deployment.

## Game address

Play buttons use `GAME_URL`. The default is `https://littledill.app`. Change `vars.GAME_URL` in `wrangler.jsonc`, or supply it when deploying:

```sh
npx wrangler deploy --var GAME_URL:https://play.example.com
```

Use an absolute HTTP or HTTPS address without credentials. Invalid configuration returns HTTP 500 for HTML requests. Local overrides go in an untracked `.dev.vars` file:

```dotenv
GAME_URL="http://localhost:4178"
```

Canonical and Open Graph addresses come from the request origin, so preview deployments link to the configured game while sharing their own website address. HTML responses disable caching. Other assets keep Cloudflare's response headers.

## Checks

From the repository root:

```sh
node --test website/tests/*.test.mjs
npx wrangler deploy --config website/wrangler.jsonc --dry-run
```

Node tests use an `HTMLRewriter` test double. Wrangler preview exercises Cloudflare's runtime and static asset routing.
