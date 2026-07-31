# CLAUDE.md

Project notes for this blog (**invariante**, published at invariante.co). This is a
static site generated with **Hakyll** (Haskell) and built with **Stack**.

## Building the site

The generator is the `site` executable defined in `site.hs` (standard Hakyll `main`,
so the usual subcommands are available):

```sh
stack build                 # compile the `site` generator (needed after editing site.hs)
stack exec site build       # generate the static site into _site/
stack exec site watch       # build + live-reload preview at http://localhost:8000
stack exec site rebuild     # clean + build (use when caching gets stale)
stack exec site clean       # remove _cache/ and _site/
```

## CSS is hand-written — do NOT use the SCSS

CSS is maintained **by hand as `.css` files**. The template (`templates/default.html`)
loads these, in order:

1. `css/markdown.css`
2. `css/syntax.css`
3. `assets/style.css`
4. `css/style.css`  ← main stylesheet, most rules live here

- **`css/style.scss` is stale/abandoned. Do not edit it and do not compile it** — it is
  missing rules that only exist in `css/style.css` (e.g. the global `img{}` block, the
  `.homepage__*` rules, `header>h1` sizing). Editing the `.scss` and recompiling would
  silently revert those. Edit the `.css` directly.
- Hakyll matches `css/*` and runs `compressCssCompiler`, copying/minifying into
  `_site/css/`. A `stack exec site build` (or `watch`) is required for CSS edits to show
  up in `_site/`.

## Content conventions

- Posts live in `posts/`, drafts in `drafts/`, filenames are `YYYY-MM-DD-slug.md`.
- Front matter keys in use: `title`, `description`, `tags`, `image`, `include_plotly`,
  `include_mermaid`, `og_fit`.

## Open Graph social cards (auto-generated)

- Set `image:` to the **real photo** you want to represent the post — no manual
  cropping/resizing. At build time `site.hs` generates a 1200×630 (1.91:1) card named
  `<image>-og.jpg` (compressed JPEG, well under 1 MB) and the template's `og:image` /
  `twitter:image` point at it, with `og:image:width/height`. Applies to `posts/`,
  `drafts/`, `shared-drafts/`.
- The generated `-og.jpg` files are **build artifacts** — they live only in `_site/`,
  never commit them to the source `images/` dir.
- `og_fit:` controls how a non-1.91:1 source is fit (default `cover`):
  - `cover` — center-crop to fill (punchy; best for photos).
  - `contain` — scale the whole image to fit, padded with its average color (never
    crops; use for book-cover collages, diagrams, charts, memes).
- **Non-raster sources (e.g. SVG) are skipped** — the original `image:` is used as the
  `og:image` and no width/height is emitted. Image processing is pure Haskell
  (JuicyPixels + JuicyPixels-extra), so it needs no external tools and runs on CI.
- Editing `site.hs` requires `stack build` before the new cards appear.
- Images use raw HTML in the markdown, styled by `css/style.css`:
  - `.image__article` (float right), `.image__article--left`, `.image__article--full`
  - `.gallery` — a `<div class="gallery">` with 2+ `<img>` is turned into a swipeable
    slideshow by `scripts/main.js` (`initGalleries`).
- YouTube/embeds are bare `<iframe>` tags. Responsive iframe CSS in `css/style.css`
  (`.main__container iframe`) handles sizing — see gotcha below.

## Deploy / branches

- Work happens on the **`hakyll`** branch (source). CI (`circle.yml`, CircleCI) builds
  on `hakyll`, then commits and pushes the generated output.
- **`_site/` is a git submodule** pointing at the same GitHub repo; the built site is
  published from there. `_site/`, `_cache/`, `.stack-work/` are gitignored in the parent.
- So: edit source on `hakyll`; the `master` branch is the published output.

## Gotchas learned

- **Testing responsive layout:** Playwright (Chromium) at device sizes is the reliable
  way to catch these. Measure `window.visualViewport.scale` (should be `1`; `<1` means
  shrink-to-fit is happening) and `documentElement.scrollWidth > innerWidth` (overflow).
  Use `waitUntil: 'domcontentloaded'` — a page with a YouTube embed never reaches
  `networkidle`.
- **Dark mode** is a `body.dark` class toggled by `scripts/main.js` (persisted in
  `localStorage`), styled under `body.dark {...}` in `css/style.css`.
