# Website Directory

This directory contains experimental website implementations for the vcpkg-registry documentation.

## Docusaurus

The `docusaurus/` subdirectory contains a Docusaurus-based documentation site prototype.

### Quick Start

```bash
cd docusaurus
npm install
npm run start
```

Visit http://localhost:3000 to view the site.

### Building for Production

```bash
cd docusaurus
npm run build
npm run serve  # Preview the production build
```

### Documentation

See [docs/notes-docusaurus.md](../docs/notes-docusaurus.md) for detailed implementation notes.

### Features

- ✅ Modern React-based UI
- ✅ TypeScript support
- ✅ Multi-language support (English + Korean)
- ✅ Mermaid diagrams
- ✅ Algolia search (placeholders configured)
- ✅ GitHub Pages deployment workflow
- ✅ Mobile-responsive design
- ✅ Dark mode support

## Other Implementations

Future experiments with other static site generators may be added here following the pattern documented in `docs/2025-12 markdown-ssg-research.md`.
