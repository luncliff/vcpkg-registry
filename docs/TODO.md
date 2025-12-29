# Hugo Menu & Docs TODO

This file explains how the Hugo menu and docs mapping work in this repository.

## How the Docs Are Mapped

- Hugo site lives under `hugo-site/`.
- Source markdown lives in `docs/` at the repo root.
- `hugo-site/hugo.toml` uses `module.mounts` to expose docs as site content:
  - Each core English guide is mounted into the `docs` section as `content/docs/*.en.md`.
  - Korean docs under `docs/ko` are mounted as a separate `ko` language tree.
  - Experimental English pages under `docs/en` are mounted to `content/en/experiments`.

To add a new English doc page that should appear under the docs section:

1. Create the markdown file under `docs/`, for example:
   - `docs/new-guide.md`
2. Add a new mount entry in `hugo-site/hugo.toml` under `[module]`:

   ```toml
   [[module.mounts]]
   source = "../docs/new-guide.md"
   target = "content/docs/new-guide.en.md"
   ```

3. Restart `hugo server` (or rebuild) and the page will be available at:
   - `/docs/new-guide/` (with full baseURL prefix in production).

## How the Menu Works

The main navigation and social links are driven by the `[menu]` section in `hugo-site/hugo.toml`:

- `[[menu.main]]` entries appear in the top navigation bar.
- `[[menu.social]]` entries are rendered as social icons in the left sidebar by the Stack theme.

Current key entries:

- `menu.main` includes a link to the GitHub repository.
- `menu.social` includes a GitHub social icon that points to the same repository URL.

To add a new top-level menu item for a docs page:

1. Decide the target URL (Hugo will map from the content path), for example `/docs/guide-create-port/`.
2. Add an item under `[menu]` in `hugo-site/hugo.toml`:

   ```toml
   [[menu.main]]
   name = 'Create Port'
   url = '/docs/guide-create-port/'
   weight = 20
   ```

3. Use `weight` to control ordering (smaller value = earlier in the menu).

## Search Page

- The Hugo Stack theme expects a page with `layout: search` to enable the search UI.
- This repo provides `hugo-site/content/search.md` with that layout.
- The theme widgets configuration in `hugo.toml` enables the search widget on the homepage and normal pages.

## Sidebar Avatar

- The Stack theme shows a 150x150-like avatar image if `params.sidebar.avatar.enabled = true`.
- In this repo, the avatar is disabled in `hugo-site/hugo.toml`:

  ```toml
  [params.sidebar.avatar]
  enabled = false
  ```

If you later want to enable an explicit avatar:

1. Place an image file (e.g. `docs/avatar.png`) in the repo.
2. Mount it into the Hugo assets tree or reference it directly via a static folder.
3. Update `hugo-site/hugo.toml`:

   ```toml
   [params.sidebar.avatar]
   enabled = true
   local = true
   src = "img/avatar.png"  # Adjust if you store it elsewhere
   ```

Then rebuild or restart `hugo server`.
