# 2025-12 Implementation Plan – Astro + Starlight

## 1. Objective & Branching
- **Goal:** Prototype Astro’s Starlight starter to measure performance, built-in Pagefind search, and multi-framework extensibility for docs + prompts.
- **Working branch suggestion:** `feat/docs-astro-starlight-plan`.
- **Deliverables:**
  - `website/starlight/` Astro project containing migrated docs, KO/EN locales, and sample diagrams.
  - Local launch/testing log (optional) capturing performance metrics and DX notes.
  - GitHub Actions workflow (`.github/workflows/starlight.yml`).

## 2. Prerequisites
- Node.js 22.x, npm 10+ (Astro officially supports 18+).
- Familiarity with Astro file-based routing and MD/MDX content collections.
- Optional: pnpm for faster installs (Astro CLI detects automatically).
- Decide whether to keep docs in /docs vs /src/content/docs.

## 3. Implementation Steps
1. **Scaffold Starlight Project**
   - `npm create astro@latest -- --template starlight` targeting `website/starlight`.
   - Choose TypeScript + strict linting for parity with other pilots.
2. **Content Collections**
   - Map existing docs into `src/content/docs/` (Starlight default). Use `frontmatter` for metadata tags.
   - Create secondary collection for Copilot prompt docs to test cross-link navigation.
3. **Localization**
   - Enable `i18n` in `astro.config.mjs` with `defaultLocale: 'en'`, `locales: ['en', 'ko']`.
   - Duplicate `src/content/docs/` structure under `src/content/docs/@ko/` or use `translations` field.
   - Confirm locale switcher appears in header; customize labels.
4. **Navigation & Sidebar Tags**
   - Update `src/content/config.ts` sidebar entries with `label`, `badge`, and `links` fields.
   - Use Starlight’s `sidebar.slot` or `related` frontmatter to show “Guide ↔ Prompt” relationships.
5. **Search**
   - Pagefind enabled by default; verify bundler output and add Korean analyzer if needed.
   - Document how to switch to Algolia if scaling beyond Pagefind limits.
6. **Syntax Highlighting / Copy Buttons**
   - Confirm Expressive Code integration (ships with Starlight). Configure languages list to include CMake, PowerShell, Bash.
   - Copy buttons enabled out of box; customize theme tokens if necessary.
7. **Diagrams**
   - Install `@astrojs/markdoc` (if using Markdoc) or rely on Markdown + `@astrojs/mdx` for Mermaid support via `remark-mermaidjs`.
   - Alternative: embed `<Mermaid />` component; ensure SSR compatibility.
8. **Graphviz Support**
   - Document approach (pre-render via `dot` CLI, include as SVG) or evaluate `@hpcc-js/wasm` with client-side rendering.
9. **Local Dev Experience**
   - Add `scripts`: `dev`, `build`, `preview`. Configure `.env` for base/site settings.
10. **Content Adaptations**
    - Convert MkDocs-specific syntax (admonitions) to Starlight callouts (````admonition```` fences or MDX components).

## 4. Local Launch Procedure
```bash
cd website/starlight
npm install
npm run dev -- --host 0.0.0.0 --port 3002
```
- Test locale switch, Pagefind search, copy buttons, and Mermaid pages.
- Capture Lighthouse stats via `npm run preview` + `npm run astro check` if desired.

## 5. CI/CD Plan (GitHub Pages)
- Use official `withastro/action@v5` workflow from research report; store under `.github/workflows/starlight.yml`.
- Set `site` + `base` in `astro.config.mjs` for GitHub Pages URL.
- Upload build output (`dist/`).
- Document in `.github/workflows/gh-pages.yml` that Astro/Starlight testing is occurring on this branch so the legacy workflow remains disabled until a winner is selected.

## 6. Acceptance Checklist
- [ ] `npm run build` succeeds with locales.
- [ ] Pagefind search indexes EN/KO content.
- [ ] Sidebar badges/related links navigate between docs and prompts.
- [ ] Mermaid (and documented Graphviz workaround) verified.
- [ ] GitHub Pages workflow ready for PR.
- [ ] Notes on DX + performance recorded for cross-SSG comparison.
