# 2025-12 Implementation Plan – Eleventy (11ty)

## 1. Objective & Branching
- **Goal:** Prototype Eleventy’s flexible pipeline, focusing on incremental adoption, custom navigation tags, and integrating a search plugin (Lunr/Pagefind).
- **Working branch suggestion:** `feat/docs-eleventy-plan`.
- **Deliverables:**
  - `website/eleventy/` project with `eleventy.config.js`, layouts, collections, and migrated content.
  - Documentation of custom features (copy buttons, i18n routing, search) for later comparison.
  - GitHub Actions workflow `.github/workflows/eleventy.yml` derived from research snippet.

## 2. Prerequisites
- Node.js 22.x, npm 10+.
- Basic knowledge of Liquid/Nunjucks (choose one template language; start with Nunjucks to match doc-style layouts).
- Optional dev dependencies: `@11ty/eleventy`, `@11ty/eleventy-navigation`, `@11ty/eleventy-plugin-syntaxhighlight`, `pagefind` or `lunr` builder script.

## 3. Implementation Steps
1. **Initialize Project**
   - `cd website && mkdir eleventy && cd eleventy`
   - `npm init -y`
   - `npm install @11ty/eleventy @11ty/eleventy-navigation @11ty/eleventy-plugin-syntaxhighlight`
   - Add `scripts` to `package.json`: `"dev": "eleventy --serve"`, `"build": "eleventy"`.
2. **Directory Layout**
   - Use `src/` as input dir. Mirror existing docs under `src/docs/…` and prompts under `src/prompts/…`.
   - Configure `eleventy.js` to copy static assets from `/assets`.
3. **Collections & Navigation**
   - Use `eleventy-navigation` plugin to auto-generate sidebars; define frontmatter fields:
     ```yaml
     eleventyNavigation:
       key: Guide:CreatePort
       parent: Guides
       order: 1
       tags:
         - prompts
     ```
   - Build custom shortcode to render "related documents" chips based on shared tags.
4. **Internationalization**
   - Approach A: Duplicate content with locale suffix (`index.en.md`, `index.ko.md`).
   - Approach B: Directory per locale (`src/en/docs`, `src/ko/docs`). Configure collections to filter by locale parameter.
   - Add language switcher component that links to equivalent slug via data cascade.
5. **Search**
   - Prototype with Pagefind CLI (works on Eleventy output). Add npm script `"search:index": "pagefind --source _site"`.
   - Alternatively, build Lunr index via Eleventy filter; embed JSON + client script.
6. **Syntax Highlighting & Copy Buttons**
   - Register `@11ty/eleventy-plugin-syntaxhighlight` (Prism). Ensure languages (CMake, PowerShell) loaded.
   - Create client-side JS to add copy buttons (inject via layout with `<script type="module">`).
7. **Diagrams**
   - Mermaid: include script + custom shortcode to wrap code fences.
   - Graphviz: rely on pre-generated SVG or use WASM library; document chosen path.
8. **Admonitions & Components**
   - Build shortcodes for MkDocs-style notes (e.g., `{% admonition "note" %}`) to simplify migration.
9. **Local Dev Experience**
   - Run `npm run dev` and confirm hot reload behavior (Eleventy dev server watchers).
   - Document limitations (e.g., full reload required for some template changes).
10. **Documentation**
    - Capture additional work required vs other SSGs (manual i18n, search setup) for final evaluation.

## 4. Local Launch Procedure
```bash
cd website/eleventy
npm install
npm run dev
```
- Access `http://localhost:8080`.
- Validate bilingual routes, navigation chips, search prototype, and diagrams.

## 5. CI/CD Plan (GitHub Pages)
- Workflow steps: checkout → setup node → `npm ci` → `npm run build` → optional `npm run search:index` → upload `_site/` artifact → deploy via `actions/deploy-pages@v4`.
- Cache npm dependencies for faster builds.
- Add a comment entry in `.github/workflows/gh-pages.yml` linking to this plan/branch so the paused legacy workflow status is traceable during Eleventy evaluation.

## 6. Acceptance Checklist
- [ ] `_site/` output contains EN + KO content with correct routing.
- [ ] Sidebar/related links driven by `eleventy-navigation` + tags.
- [ ] Search prototype functional (Pagefind or Lunr) and documented.
- [ ] Mermaid + Graphviz solutions demonstrated.
- [ ] Copy-to-clipboard script working across code blocks.
- [ ] Workflow file ready for PR.
- [ ] Notes outlining effort vs other SSG pilots captured.
