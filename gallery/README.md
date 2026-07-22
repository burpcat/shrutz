# Creators Publish gallery

This directory holds the manifest that `shrutz gallery list`/`shrutz gallery install` fetch from GitHub (via `raw.githubusercontent.com`) — a small catalog of developer-curated wallpaper sets that any shrutz user can browse and optionally download. It is not bundled with a fresh install; `shrutz` ships with no images by default (see the installer's own prompt), and this is purely an opt-in "browse more sets" feature.

## Publishing a set

1. Build the set locally and run `shrutz export <name>` — this produces a zip with the exact shape the installer expects (a single top-level `<name>/` directory containing the images plus the `__init__` metadata file).
2. Upload that zip as a GitHub Release asset in this repo (not committed directly — keeps clone size small).
3. Add a thumbnail image under `gallery/thumbs/<name>.jpg` (small, a few hundred KB at most) and commit it normally.
4. Add an entry to `manifest.json`:

```json
{
  "name": "<name>",
  "author": "<github-username>",
  "description": "<one line>",
  "images": <count>,
  "thumbnail_url": "https://raw.githubusercontent.com/burpcat/shrutz/master/gallery/thumbs/<name>.jpg",
  "download_url": "https://github.com/burpcat/shrutz/releases/download/<release-tag>/<name>.zip"
}
```

`sha256` is an optional field on any entry — if present, `shrutz gallery install` verifies the downloaded zip against it before extracting.

## Current status

The `haasan` entry in `manifest.json` is a placeholder — its `download_url` doesn't point at a real release asset yet, and `images`/the thumbnail are unset. Fill these in once the actual `haasan.zip` (via `shrutz export haasan`) and thumbnail are uploaded.
