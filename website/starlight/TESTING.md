# Testing Checklist

This document tracks testing results for the Starlight documentation site.

## Local Development Testing

### ✅ Build Tests
- [x] `npm install` succeeds
- [x] `npm run build` succeeds without errors
- [x] Build generates static files in `dist/`
- [x] Pagefind search indexing completes
- [x] Mermaid diagrams render in build

### ✅ Development Server Tests
- [x] `npm run dev` starts successfully
- [x] Server accessible on http://localhost:3002/vcpkg-registry
- [x] Hot reload works for content changes

### Content Tests
- [x] Homepage loads with splash layout
- [x] All guide pages accessible
- [x] All reference pages accessible
- [x] Korean locale pages accessible
- [x] Locale switcher appears in header

### Search Tests
- [ ] Pagefind search indexes EN content
- [ ] Pagefind search indexes KO content
- [ ] Search returns relevant results
- [ ] Search works across both locales

### Navigation Tests
- [x] Sidebar navigation structure correct
- [x] All sidebar links work
- [x] GitHub social link present
- [ ] Breadcrumbs work correctly

### Diagram Tests
- [x] Mermaid code blocks render during build
- [x] Diagram support documentation page exists
- [x] SVG approach for Graphviz documented

### Syntax Highlighting Tests
- [x] Bash/Shell code blocks highlight correctly
- [x] JavaScript/TypeScript code blocks highlight correctly
- [x] JSON/YAML code blocks highlight correctly
- [x] CMake code blocks highlight correctly
- ⚠️ PowerShell code blocks fall back to txt (known limitation)
- ⚠️ Graphviz DOT code blocks fall back to txt (expected)

### Mobile Responsive Tests
- [ ] Homepage renders correctly on mobile
- [ ] Navigation works on mobile
- [ ] Search works on mobile
- [ ] Content readable on mobile

## CI/CD Tests

### GitHub Actions Workflow
- [ ] Workflow file syntax valid
- [ ] Node.js setup works
- [ ] Playwright installation succeeds
- [ ] Build succeeds in CI
- [ ] Deployment to GitHub Pages works

## Known Issues

1. **PowerShell Syntax Highlighting**: The `pwsh` language is not included in the default Expressive Code bundle. Code blocks fall back to plain text. This is acceptable but could be improved by adding PowerShell language support.

2. **Graphviz DOT Syntax**: DOT language is not supported for syntax highlighting. This is expected and documented as intentional - users should pre-render to SVG.

## Performance Metrics

Build Performance:
- Initial `npm install`: ~28s
- `npm run build`: ~3.8s
- Dev server start: ~3.3s
- Page generation: 21 pages in ~200ms

Search Indexing:
- Total pages indexed: 22 (EN + KO)
- Total words indexed: 3,118
- Languages: en, ko
- Index generation time: ~0.18s

## Next Steps

1. Complete remaining manual tests (search, mobile, breadcrumbs)
2. Deploy to GitHub Pages and verify
3. Gather performance metrics from production
4. Consider adding PowerShell language support if needed
5. Complete Korean translations for remaining pages
