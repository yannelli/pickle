![A smiling little dill with a virtual-pet keychain](assets/illustrations/banner.webp)

# little dill.

A tiny pickle. A big responsibility. Your pocket pickle pet.

Open `index.html` to play, or serve this folder with any static web server. Progress saves in your browser.

## Web assets

[Browse the asset gallery](assets/preview.html) · [Asset guide and generation prompts](assets/README.md)

Includes an illustrated banner, transparent mascot sticker, outlined SVG logos, app icons, favicons, an Apple touch icon, and a 1200 × 630 OG image. The page includes Open Graph and Twitter card metadata and a web app manifest.

## Deploy

No build step. The repo root is the site.

**Cloudflare Workers** (static assets, config in `wrangler.jsonc`, uploads filtered by `.assetsignore`):

```sh
npx wrangler deploy
```

Or connect the repository in the Cloudflare dashboard under Workers & Pages and set the deploy command to `npx wrangler deploy`. Preview locally with `npx wrangler dev`.

**Vercel** (uploads filtered by `.vercelignore`): import the repository in the Vercel dashboard with framework preset "Other" and no build command, or run:

```sh
npx vercel
```

Once the public URL is known, follow the deployment notes in the asset guide to finish the sharing URLs.
