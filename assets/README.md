# little dill. web assets

Open [the gallery](preview.html) to preview and download the set.

## Files

| Asset | Files | Use |
| --- | --- | --- |
| Logo | `brand/logo.svg`, `brand/logo.png` | Evergreen wordmark and pickle; transparent, 466 × 128 SVG / 932 × 256 PNG |
| Light logo | `brand/logo-light.svg`, `brand/logo-light.png` | Cream wordmark for dark surfaces |
| Brand mark | `brand/mark.svg`, `brand/mark.png` | Standalone vector mascot; transparent 512 × 512 PNG |
| Banner | `illustrations/banner.png` | Original 2172 × 724 illustration |
| Web banner | `illustrations/banner.webp`, `illustrations/banner-small.webp` | 1536 × 512 and 768 × 256 responsive exports |
| Mascot sticker | `illustrations/mascot.svg`, `illustrations/mascot.png`, `illustrations/mascot.webp` | Transparent vector sticker with a cream outline; 1024 × 1024 PNG and 512 × 512 lossless WebP |
| Social image | `social/og.png` | 1200 × 630 Open Graph / Twitter card / GitHub social preview |
| Social source | `social/og.svg` | Editable layout with the banner illustration embedded and vector logo paths |
| App icon | `icons/icon.svg`, `icons/icon-192.png`, `icons/icon-512.png` | App / home-screen icon |
| Maskable icon | `icons/maskable.svg`, `icons/maskable-512.png` | Full-bleed icon with mascot inside the central safe zone |
| Browser icon | `../favicon.svg`, `../favicon.ico`, `icons/favicon-32.png` | Simplified face for small browser tabs; ICO includes 16, 32 and 48 px |
| Apple touch icon | `../apple-touch-icon.png` | Opaque 180 × 180 home-screen icon |
| Web app manifest | `../site.webmanifest` | Portable relative paths and app names |

## Palette

Cream `#f7f5e9` · Evergreen `#304a35` · Sage `#829f52` · Celery `#ccda9d` · Peach `#dcad86`

Keep the outlined logo's proportions and leave at least one eye-width of clear space. Use `logo-light` on dark backgrounds. The detailed illustration is for larger placements; use the simplified favicon at tiny sizes.

## Deployment

The deployment URL is not chosen yet. In `index.html`, replace the relative values of **both** `og:image` and `twitter:image` with the public HTTPS URL ending in `/assets/social/og.png`. Include any deployment subdirectory. Then add a canonical link and `og:url` using the final public page URL. Relative asset paths keep the app usable in local previews and subdirectory deployments until then.

Social crawlers must be able to fetch the page and PNG without authentication. A raw image URL from the private GitHub repository will not work for public cards. Once deployed, check the actual shared URL with the target service. The manifest provides branding metadata; offline caching comes from `../sw.js`.

## Sources and exports

The banner was made with the built-in image generator; [the exact prompt and local composition notes](PROMPTS.md) are included. The OG card combines that banner with the logo locally. The transparent sticker uses the vector mascot with a cream outline. The vector mark and favicon refine the site's original inline SVG. The logo lettering is stored as paths.

Raster icon/logo exports use `rsvg-convert` to preserve SVG strokes and transparency. For example:

```sh
rsvg-convert -w 512 -h 512 brand/mark.svg -o brand/mark.png
rsvg-convert -w 180 -h 180 -b '#f7f5e9' icons/icon.svg -o ../apple-touch-icon.png
magick illustrations/banner.png -resize 1536x -strip -quality 84 illustrations/banner.webp
rsvg-convert -w 1200 -h 630 social/og.svg -o social/og.png
rsvg-convert -w 1024 -h 1024 illustrations/mascot.svg -o illustrations/mascot.png
magick illustrations/mascot.png -resize 512x512 -strip -define webp:lossless=true illustrations/mascot.webp
```

These are optional authoring tools, not application dependencies. The OG source uses Avenir Next and Georgia with generic fallbacks for its supporting copy; the delivered PNG has no font dependency. No packages, external fonts, or remote image services are required to display the assets.
