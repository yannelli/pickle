# Image generation prompts

The banner was created with the built-in `image_gen` tool. Its PNG original is preserved in this asset folder. WebP files are delivery-sized exports. SVG logos and icons extend the site's original vector favicon; their wordmarks are outlined paths and have no runtime font dependency.

## Banner

```text
Use case: illustration-story
Asset type: wide website banner illustration for the existing "little dill." pocket-pickle virtual pet, also used as a repository banner.
Primary request: an exceptionally cute, polished editorial illustration of a tiny living pickle and its sage-green retro virtual-pet keychain, warm, gentle and nostalgic.
Existing brand: cream paper #f7f5e9, deep evergreen #304a35, olive sage #78954b, pale celery #ccda9d; tiny muted peach cheeks.
Subject: one friendly upright little pickle with a short rounded chunky body, a few dark green bumps, dark dot eyes, small U smile, tiny arms and feet and a tiny curved stem. It leans affectionately against an egg-shaped sage-green virtual pet keychain with a monochrome LCD, three cream round buttons and metal loop. On the LCD show a tiny simple pixel heart, no text.
Style: beautiful soft gouache and colored pencil with subtle paper grain, confidently rounded silhouettes, restrained hand-inked evergreen outlines. Cozy indie website art, simple enough to match the existing CSS pickle character.
Composition: panoramic 3:1 canvas, 1536 by 512 if possible. A small vignette in the central half with generous cream negative space on both sides. Entire subjects visible with generous margins. A few delicate sparkles and a soft ground shadow. Quiet, balanced, charming. Opaque cream background.
Constraints: no words, no lettering, no watermark, no frame, no UI mockup, no extra characters. Deliver one finished banner illustration.
```

## OG card: local composition

The 1200 × 630 card is composed locally from the generated banner and the outlined logo. Its editable source is `social/og.svg`; the illustration is embedded so the SVG is self-contained. The delivered sharing image is `social/og.png`.

- Cream paper background, evergreen logo and supporting copy, sage details.
- Existing logo on the left; a crop of the existing banner on the right, with softly faded edges.
- Exact supporting text: “THE ORIGINAL POCKET PICKLE”, “Your pocket pickle.”, “A little brine. A little love.”, “SMALL PET. BIG FEELINGS.”, “Stay a little salty.”
- All important content stays inside the 70-pixel safe margin.

## Mascot sticker: local vector export

`illustrations/mascot.svg` uses the existing `brand/mark.svg` character with a cream sticker outline on a transparent background. It is exported to 1024 × 1024 PNG and 512 × 512 lossless WebP. The original mark remains available without the sticker outline.

See the asset guide for regeneration commands.
