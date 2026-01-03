# VitePress Documentation Experiment

This document describes the VitePress implementation for the vcpkg-registry documentation.

## Overview

VitePress is a modern static site generator built on Vite and Vue. This experiment evaluates VitePress as an alternative to MkDocs for the repository documentation.

## Installation

The VitePress setup is included in the repository with all necessary dependencies defined in `package.json`.

### Prerequisites

- Node.js 18+ and npm

### Install Dependencies

```bash
npm install
```

## Usage

### Development Server

Start the development server with hot reload:

```bash
npm run docs:dev
```

The site will be available at `http://localhost:5173/`

### Build for Production

Build the static site:

```bash
npm run docs:build
```

Output will be in `docs/.vitepress/dist/`

### Preview Production Build

Preview the production build locally:

```bash
npm run docs:preview
```

## Configuration

VitePress configuration is located at `docs/.vitepress/config.mts`.

### Key Features

- **Bilingual Support**: Configured for Korean (한글) with plans for English
- **Built-in Search**: Fast local search without external plugins
- **Modern Theme**: Material-inspired design with dark mode support
- **Clean URLs**: No `.html` extensions in URLs
- **Korean Localization**: UI elements translated to Korean

### Navigation Structure

The navigation matches the existing MkDocs structure:

- **Home**: Main Korean documentation (vcpkg-for-kor.md)
- **References**: Quick reference links
- **Guides**: 
  - Create Port (with build and download sub-guides)
  - Update Port
  - Update Version Baseline
  - Troubleshooting
- **Development**: Prompt designs, checklists, and templates

## Comparison with MkDocs

### Advantages of VitePress

1. **Built-in Search**: No external plugins required (MkDocs requires mkdocs-material)
2. **Faster Build Times**: Vite-powered builds are significantly faster
3. **Modern Stack**: Vue 3, TypeScript, and modern JavaScript
4. **Smaller Bundle Size**: Optimized JavaScript bundles
5. **Better Developer Experience**: Hot Module Replacement (HMR) during development
6. **Active Development**: Regular updates and active community

### Considerations

1. **Syntax Highlighting**: Some languages (pwsh, dot, pc) require additional configuration
2. **Dead Links**: Links to files outside docs/ need to be ignored or transformed
3. **Migration Effort**: Minimal - existing markdown files work with minor adjustments
4. **Learning Curve**: Requires JavaScript/Vue knowledge for advanced customizations

### Missing Features

The following MkDocs/Material features may need workarounds:

- **Admonitions**: VitePress has container syntax but different from MkDocs
- **Tabbed Content**: Needs custom component or plugin
- **Offline Plugin**: Not built-in but can be added with PWA plugin

## Current Status

### Working Features ✅

- [x] VitePress installation and configuration
- [x] All documentation pages rendering correctly
- [x] Navigation structure matching MkDocs
- [x] Korean language support in UI
- [x] Built-in search functionality
- [x] Dark/light theme toggle
- [x] Development server with HMR
- [x] Production build
- [x] Preview server

### Known Issues ⚠️

- Syntax highlighting warnings for 'pwsh', 'dot', and 'pc' languages
- Dead link warnings for repository files outside docs/ (configured to ignore)

### Future Enhancements 🚀

- Add English localization
- Configure additional syntax highlighting languages
- Add custom Vue components for better content presentation
- Configure GitHub Pages deployment workflow
- Add PWA support for offline access
- Custom theme colors to match repository branding

## File Structure

```
.
├── docs/
│   ├── .vitepress/
│   │   ├── config.mts      # VitePress configuration
│   │   ├── cache/          # Build cache (gitignored)
│   │   └── dist/           # Production build output (gitignored)
│   ├── index.md            # Home page with hero layout
│   └── *.md                # Documentation pages
├── package.json            # NPM dependencies and scripts
└── node_modules/           # Dependencies (gitignored)
```

## Deployment

### GitHub Pages

To deploy to GitHub Pages, uncomment the `base` configuration in `config.mts`:

```typescript
base: '/vcpkg-registry/',
```

Then create a GitHub Actions workflow to build and deploy:

```yaml
name: Deploy VitePress

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run docs:build
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: docs/.vitepress/dist
```

## Resources

- [VitePress Documentation](https://vitepress.dev/)
- [VitePress GitHub](https://github.com/vuejs/vitepress)
- [Vue 3 Documentation](https://vuejs.org/)
