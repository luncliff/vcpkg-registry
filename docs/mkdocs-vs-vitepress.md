# MkDocs vs VitePress Comparison

This document provides a detailed comparison between MkDocs (current) and VitePress (experimental) for the vcpkg-registry documentation.

## Quick Summary

| Feature | MkDocs + Material | VitePress | Winner |
|---------|-------------------|-----------|--------|
| **Setup Complexity** | Medium (Python) | Easy (Node.js) | VitePress |
| **Build Speed** | ~5-10s | ~3-5s | VitePress |
| **Bundle Size** | ~2MB | ~500KB | VitePress |
| **Search** | Plugin required | Built-in | VitePress |
| **i18n Support** | Plugin required | Built-in | VitePress |
| **Markdown Extensions** | Excellent | Good | MkDocs |
| **Theme Customization** | Excellent | Good | Tie |
| **Learning Curve** | Low | Medium | MkDocs |
| **Community Size** | Large (Python) | Growing (JS) | MkDocs |
| **Documentation Quality** | Excellent | Excellent | Tie |

## Detailed Comparison

### Installation & Setup

**MkDocs**
```bash
# Python required
pip install mkdocs mkdocs-material
```

**VitePress**
```bash
# Node.js required
npm install -D vitepress
```

**Winner**: VitePress - Modern JavaScript tooling is more common in web development workflows.

### Build Performance

**MkDocs**
- Build time: ~5-10 seconds for this repository
- Incremental builds: Not supported
- Hot reload: Basic

**VitePress**
- Build time: ~3-5 seconds for this repository
- Incremental builds: Yes (Vite HMR)
- Hot reload: Excellent (instant updates)

**Winner**: VitePress - Significantly faster builds and superior development experience.

### Bundle Size

**MkDocs Material**
- JavaScript: ~1.5MB
- CSS: ~500KB
- Total: ~2MB uncompressed

**VitePress**
- JavaScript: ~300KB
- CSS: ~200KB
- Total: ~500KB uncompressed

**Winner**: VitePress - 4x smaller bundle size means faster page loads.

### Search Functionality

**MkDocs**
- Requires `mkdocs-material` premium or search plugin
- Search index built at build time
- Good search quality
- Multi-language support available

**VitePress**
- Built-in local search (no plugins)
- Search index built at build time
- Excellent search quality
- Multi-language support included

**Winner**: VitePress - Built-in without additional plugins or cost.

### Internationalization (i18n)

**MkDocs**
- Requires `mkdocs-static-i18n` plugin
- Manual configuration per language
- File structure: `docs/en/`, `docs/ko/`

**VitePress**
- Built-in locales support
- Clean configuration
- File structure: `docs/en/`, `docs/ko/` or `root`

**Winner**: VitePress - Native support without plugins.

### Markdown Features

**MkDocs Material**

Supported out of the box:
- ✅ Admonitions (notes, warnings, tips)
- ✅ Code blocks with syntax highlighting
- ✅ Tabbed content
- ✅ Definition lists
- ✅ Footnotes
- ✅ Task lists
- ✅ Icons & Emojis
- ✅ Math (KaTeX/MathJax)
- ✅ Mermaid diagrams

**VitePress**

Supported out of the box:
- ⚠️ Containers (similar to admonitions)
- ✅ Code blocks with syntax highlighting
- ✅ Code groups (similar to tabs)
- ❌ Definition lists (needs custom component)
- ✅ Footnotes
- ✅ Task lists
- ✅ Emojis
- ⚠️ Math (needs markdown-it-mathjax3)
- ⚠️ Mermaid (needs plugin)

**Winner**: MkDocs - More markdown extensions work out of the box.

### Theme & Customization

**MkDocs Material**
- Highly polished Material Design theme
- Extensive configuration options
- Color schemes, fonts, icons
- Custom CSS/JS support
- Block overrides for HTML customization

**VitePress**
- Clean, modern default theme
- Good configuration options
- Color schemes with CSS variables
- Full Vue component system
- Complete theme override capability

**Winner**: Tie - Both excellent but different approaches.

### SEO & Social

**MkDocs Material**
- Good meta tag support
- Social cards generation (premium feature)
- Sitemap generation

**VitePress**
- Good meta tag support
- Social cards (manual setup)
- Sitemap (needs plugin)

**Winner**: Tie - Both support modern SEO needs.

### Deployment

**MkDocs**
```bash
mkdocs gh-deploy  # Built-in GitHub Pages deploy
```

**VitePress**
```bash
# Manual setup with GitHub Actions
npm run docs:build
# Deploy dist/ folder
```

**Winner**: MkDocs - Built-in deployment command is convenient.

### Development Experience

**MkDocs**
- Python ecosystem
- Slower hot reload
- Less modern tooling
- Stable and mature

**VitePress**
- JavaScript/Vue ecosystem
- Instant hot reload (HMR)
- Modern Vite tooling
- Active development

**Winner**: VitePress - Superior developer experience with modern tooling.

### Long-term Maintenance

**MkDocs**
- Mature project (10+ years)
- Large community
- Stable releases
- Python dependency management

**VitePress**
- Newer project (3+ years)
- Growing rapidly
- Backed by Vue.js team
- npm dependency management

**Winner**: MkDocs - More mature but VitePress is catching up fast.

## Migration Considerations

### Easy to Migrate

- ✅ Markdown files work in both systems
- ✅ Most content needs no changes
- ✅ File structure can remain the same
- ✅ Navigation can be mapped 1:1

### Requires Adjustment

- ⚠️ Admonitions → Containers (syntax change)
- ⚠️ Tabs → Code groups (syntax change)
- ⚠️ Some links may need updating
- ⚠️ Custom CSS needs conversion

### Effort Estimate

- **Time**: 2-4 hours for this repository
- **Complexity**: Low to Medium
- **Risk**: Low (can run both in parallel)

## Recommendations

### Use MkDocs If:

- ✅ You prefer Python ecosystem
- ✅ You need Material Design out of the box
- ✅ You want maximum markdown extension support
- ✅ You prioritize stability over performance
- ✅ Your team is familiar with Python

### Use VitePress If:

- ✅ You prefer JavaScript/Node.js ecosystem
- ✅ You want faster builds and better DX
- ✅ You need smaller bundle sizes
- ✅ You want built-in search and i18n
- ✅ Your team is familiar with Vue/JavaScript
- ✅ You want modern web development tooling

## Conclusion

Both tools are excellent choices for documentation. 

**For vcpkg-registry specifically:**

- Current setup (MkDocs) is working well
- VitePress offers performance benefits
- Migration would be straightforward
- Could run both systems in parallel during transition

**Recommendation**: Consider gradual migration to VitePress for:
1. Better performance (faster builds, smaller bundles)
2. Superior development experience (HMR, modern tooling)
3. Built-in features (search, i18n)
4. Long-term benefits (growing ecosystem, active development)

However, MkDocs remains a solid choice if the team prefers the Python ecosystem or requires specific Material theme features.

## Next Steps

1. ✅ Complete VitePress setup (Done)
2. ✅ Test with existing content (Done)
3. ⬜ Gather team feedback
4. ⬜ Decide on migration timeline
5. ⬜ Set up deployment pipeline
6. ⬜ Train team on VitePress (if needed)
7. ⬜ Migrate or maintain both systems
