# 2025-12 Implementation Plan – Docusaurus

## 1. Objective & Branching
- **Goal:** Stand up a Docusaurus prototype that mirrors the current MkDocs content, validates Korean/English locales, and exercises search, diagrams, and navigation tags.
- **Working branch suggestion:** `feat/docs-docusaurus-plan` (create from `main`).
- **Deliverables:**
  1. `docusaurus/` project folder with migrated docs and locale scaffolding.
  2. Local launch instructions + verification notes in `docs/notes-docusaurus.md` (optional log).
  3. Draft GitHub Actions workflow (`.github/workflows/docusaurus.yml`).

## 2. Prerequisites
- Node.js 22.x (align with workflow snippet) and npm 10+.
- pnpm/yarn optional; default to npm for consistency.
- GitHub personal access if Algolia DocSearch application is required (public doc site qualifies for free tier).
- Existing Markdown sources located under `docs/` (vcpkg-registry content) plus prompt docs in `.github/prompts/`.

## 3. Implementation Steps
1. **Scaffold Project**
   - `npx create-docusaurus@latest docusaurus-site classic --typescript` inside repo root (ignored by Git until ready).
   - Move scaffold to `website/docusaurus/` to avoid root clutter; update package metadata if needed.
2. **Content Migration**
   - Copy existing Markdown docs into `website/docusaurus/docs/`; preserve directory structure.
   - Split prompt documents into dedicated sidebar category (e.g., `category: Copilot Prompts`).
3. **Internationalization Setup**
   - Update `docusaurus.config.ts` `i18n` block with `defaultLocale: 'en'`, `locales: ['en', 'ko']`.
   - Run `npx docusaurus write-translations --locale ko` to seed translation files.
   - Place Korean docs under `i18n/ko/docusaurus-plugin-content-docs/current/` mirroring English slugs.
4. **Navigation & Labels**
   - Configure `sidebars.ts` with categories for "How-To", "Guides", "Prompts"; use `customProps` to surface tags/badges in UI.
   - Add `metadata.tags` in Markdown frontmatter to support contextual navigation.
5. **Search & Copy Buttons**
   - Configure Algolia later via `.env` placeholders (`ALGOLIA_APP_ID`, etc.); enable `contextualSearch` for locale filtering.
   - Ensure `@docusaurus/theme-classic` `codeBlockComponent` retains copy-to-clipboard (on by default).
6. **Diagrams**
   - Add `@docusaurus/theme-mermaid`; enable `markdown.mermaid: true`. Verify Mermaid blocks render.
7. **Graph/Sidebar Enhancements**
   - For Graphviz, add `mdx-mermaid` alternative or embed SVG exports; document trade-offs.
8. **Local Links & Assets**
   - Confirm relative links continue working; convert MkDocs-specific syntax (admonitions, tabs) to MDX equivalents.
9. **Environment Configuration**
   - Add `package.json` scripts: `"start": "docusaurus start"`, `"build": "docusaurus build"`, `"serve": "docusaurus serve"`.
10. **Documentation of Findings**
    - Record encountered gaps (e.g., manual translation needs) in the optional notes file.

## 4. Local Launch Procedure
```bash
cd website/docusaurus
npm install
npm run start -- --host 0.0.0.0 --port 3000
```
- Access via `http://localhost:3000`.
- Toggle locale selector to ensure KO/EN parity.
- Validate Mermaid blocks and copy buttons on sample pages.

## 5. CI/CD Plan (GitHub Pages)
- Add `.github/workflows/docusaurus.yml` using the research snippet.
- Ensure `package-lock.json` committed for deterministic installs.
- Configure `deployment_branch` as `gh-pages` (default for `deploy-pages`).
- Store Algolia keys as GitHub Actions secrets if/when granted.
- Update existing `.github/workflows/gh-pages.yml` comments to reference this plan/branch so reviewers know the legacy workflow is intentionally paused while Docusaurus is under evaluation.

## 6. Acceptance Checklist
- [ ] Local build succeeds (`npm run build`).
- [ ] EN + KO locales switch without broken links.
- [ ] Search modal wired (placeholder if Algolia pending).
- [ ] Mermaid sample renders; copy button present.
- [ ] Sidebar tagging/labels navigate to related docs.
- [ ] GitHub Actions workflow dry-run (if allowed) or documented plan.
- [ ] Summary of pros/cons vs MkDocs captured for later comparison.
