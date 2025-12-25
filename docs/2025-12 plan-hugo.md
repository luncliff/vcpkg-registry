# 2025-12 Implementation Plan – Hugo

## 1. Objective & Branching
- **Goal:** Evaluate Hugo’s Go-based pipeline for the docs site, focusing on multilingual structure, taxonomy-driven navigation, and third-party search integration.
- **Working branch suggestion:** `feat/docs-hugo-plan`.
- **Deliverables:**
  - `website/hugo/` project seeded via `hugo new site` with docs migrated into `content/`.
  - Scripts/instructions for local launch and search integration experiments.
  - GitHub Actions workflow `.github/workflows/hugo.yml` mirroring the research snippet.

## 2. Prerequisites
- Install latest Hugo Extended (v0.153.2 per reference) locally; ensure on PATH.
- Go runtime not required (Hugo binary includes everything) but useful for tooling.
- Node.js optional for asset pipelines (if theme requires).
- Understand frontmatter conversion from MkDocs to Hugo (YAML/TOML support).

## 3. Implementation Steps
1. **Project Scaffold**
   - `hugo new site website/hugo --format yaml`.
   - Add git submodule or vendored theme (recommend starting with `hugo-book` or `hugo-docsy`, though custom theme may be needed later).
2. **Content Migration**
   - Place docs under `content/docs/...`; prompts under `content/prompts/...`.
   - Use frontmatter fields `title`, `weight`, `tags`, `summary` to enable taxonomy + sidebar ordering.
3. **Multilingual Setup**
   - Configure `languages` in `hugo.yaml` with entries for `en` and `ko` (set `defaultContentLanguage = "en"`).
   - For each doc, create `/content/<section>/mydoc.en.md` and `/content/<section>/mydoc.ko.md` or use translated bundles.
4. **Navigation & Sidebar Tags**
   - Use `menu` entries (`[[menu.docs]]`) with `identifier`, `weight`, and `parent` for hierarchical sidebar.
   - Surface “related prompts” via taxonomy (e.g., `tags = ["prompt"]`) and add partial to show related content.
5. **Search Integration**
   - Option A: generate Lunr.js index during build using `assets/js/lunr.toml` + custom partial.
   - Option B: integrate Pagefind CLI (run post-build) to compare to other SSGs.
   - Note: Document extra steps needed vs built-in solutions elsewhere.
6. **Syntax Highlighting & Copy Buttons**
   - Enable Hugo’s Chroma with `pygmentsUseClasses = true`; configure `markup.highlight`.
   - Add custom JS to inject copy buttons (Docsy has built-in variant; otherwise write simple script).
7. **Diagrams**
   - Mermaid: embed script and fence using shortcode.
   - Graphviz: use Hugo Pipes to run `dot` (requires Graphviz installed) or pre-render.
8. **Static Assets & Shortcodes**
   - Recreate MkDocs admonitions via Hugo shortcodes (`{{< admonition type="note" >}}`).
   - Document conversions needed.
9. **Local Scripts**
   - Add `Makefile` or npm script (optional) for `hugo server -D` with `--disableFastRender` when editing.
10. **Documentation**
    - Track differences (lack of built-in search, manual copy button) in notes for comparison.

## 4. Local Launch Procedure
```bash
cd website/hugo
hugo server -D --bind 0.0.0.0 --baseURL http://localhost:1313
```
- Verify sidebar menus, bilingual switching (URL prefix), taxonomy-driven related docs, and diagram rendering.

## 5. CI/CD Plan (GitHub Pages)
- Adopt workflow from research report (install Hugo binary, run build, upload `public/`).
- Cache `hugo_cache` directory for faster builds.
- If Pagefind used, add step post-build to generate index before artifact upload.
- Update `.github/workflows/gh-pages.yml` to mention the Hugo experiment branch so reviewers know the default workflow stays dormant until the SSG decision.

## 6. Acceptance Checklist
- [ ] `hugo` build passes with KO/EN content.
- [ ] Navigation menus show parent/child hierarchy and tags/labels.
- [ ] Search solution (Lunr/Pagefind) documented and demoed.
- [ ] Mermaid/Graphviz diagrams render.
- [ ] Copy-to-clipboard script implemented.
- [ ] GitHub Actions workflow prepared for review.
- [ ] Notes comparing DX vs other SSGs captured.
