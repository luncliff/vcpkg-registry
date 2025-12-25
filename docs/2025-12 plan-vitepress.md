# 2025-12 Implementation Plan – VitePress

## 1. Objective & Branching
- **Goal:** Evaluate VitePress as a lighter-weight replacement by migrating core docs, enabling built-in search, and validating bilingual routing.
- **Working branch suggestion:** `feat/docs-vitepress-plan`.
- **Deliverables:**
  - `website/vitepress/` project with content + locale config.
  - Local runbook documenting KO/EN switch, Mermaid, and copy buttons.
  - GitHub Actions workflow draft (`.github/workflows/vitepress.yml`).

## 2. Prerequisites
- Node.js 22.x, npm 10+ (or pnpm if preferred).
- Familiarity with Vue single-file components (for advanced customizations).
- Review of existing Markdown features (admonitions, tabs) to map onto VitePress Markdown extensions.

## 3. Implementation Steps
1. **Scaffold**
   - Run `npm init vitepress@latest website/vitepress` (select `docs` prompt options matching repo layout).
   - Commit `docs/.vitepress/config.ts`, `theme.ts`, and new Markdown structure under `website/vitepress/docs/`.
2. **Content Migration**
   - Copy docs from root `docs/` into `website/vitepress/docs/guide/` etc.
   - Add prompt catalog under `docs/prompts/` to test sidebar linking.
3. **Localization**
   - Configure `locales` in `.vitepress/config.ts` with `root` (English) and `ko` entries.
   - Directory layout: `docs/en/...` (optional) vs multi-root approach; choose whichever keeps paths clean.
   - Add locale switcher via `themeConfig.locales` labels.
4. **Navigation Enhancements**
   - Use `themeConfig.sidebar` to express step-by-step guides; include `badge` or `text` metadata for related resources.
   - For “related docs” tags, utilize Markdown frontmatter + custom layout component to surface chips.
5. **Search**
   - Start with built-in MiniSearch (`themeConfig.search.provider = 'local'`).
   - Optionally configure Algolia later for parity with Docusaurus.
6. **Syntax Highlighting & Copy Buttons**
   - Verify Shiki default theme meets needs; toggle `markdown.codeCopyButton = true` (default). Adjust theme colors if necessary.
7. **Diagrams**
   - Install `vitepress-plugin-mermaid` (or use built-in Markdown fence once upstream merges). Configure plugin in `.vitepress/theme/index.ts`.
   - For Graphviz/PlantUML, document approach (e.g., pre-rendered images or `@vitejs/plugin-vue` dynamic components).
8. **Multi-doc Navigation**
   - Explore `VPDocAsideSponsors` slot to surface “Related prompts” links.
   - Optionally create custom theme component injecting frontmatter-defined relationships.
9. **Local Scripts**
   - Add package scripts: `docs:dev`, `docs:build`, `docs:serve`.
10. **Documentation**
    - Capture migration caveats (e.g., admonition syntax differences) in README snippet.

## 4. Local Launch Procedure
```bash
cd website/vitepress
npm install
npm run docs:dev -- --host 0.0.0.0 --port 3001
```
- Test `http://localhost:3001`.
- Verify locale dropdown, search behavior, copy buttons, and Mermaid sample.

## 5. CI/CD Plan (GitHub Pages)
- Create `.github/workflows/vitepress.yml` from reference snippet.
- Ensure `docs/.vitepress/dist` path uploaded as artifact.
- Use `actions/setup-node@v4` with npm cache.
- If using Algolia, add secrets (`ALGOLIA_APP_ID`, etc.).
- Append a note to `.github/workflows/gh-pages.yml` explaining that the base workflow remains a placeholder while the VitePress-specific pipeline is evaluated in this branch.

## 6. Acceptance Checklist
- [ ] `npm run docs:build` produces static assets without warnings.
- [ ] Locale switch works; Korean copy displays even if placeholders.
- [ ] Built-in search indexes all docs, returns bilingual results when relevant.
- [ ] Mermaid diagrams render; Graphviz approach documented.
- [ ] Sidebar tags/links navigate to prompt docs.
- [ ] Workflow config reviewed (but not activated yet).
