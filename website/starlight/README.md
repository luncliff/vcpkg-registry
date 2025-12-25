# vcpkg-registry Documentation (Starlight)

This directory contains the Astro Starlight documentation site for vcpkg-registry.

## Features

- 🌐 **Multi-language support**: English and Korean (한국어)
- 🔍 **Built-in search**: Pagefind search with language-specific indexing
- 📝 **Mermaid diagrams**: Full support for Mermaid diagram rendering
- 🎨 **Syntax highlighting**: Powered by Expressive Code with copy buttons
- 📱 **Responsive design**: Mobile-friendly documentation site

## Prerequisites

- Node.js 20.x or later
- npm 10+ or pnpm

## Local Development

### Install dependencies

```bash
npm install
```

### Install Playwright (for Mermaid diagram rendering)

```bash
npx playwright install chromium-headless-shell
```

### Start development server

```bash
npm run dev
```

This will start the development server at `http://0.0.0.0:3002` (or `http://localhost:3002`).

### Build for production

```bash
npm run build
```

The build output will be in the `dist/` directory.

### Preview production build

```bash
npm run preview
```

## Project Structure

```
website/starlight/
├── src/
│   ├── assets/           # Images and static assets
│   └── content/
│       └── docs/         # Documentation content
│           ├── index.mdx # Homepage
│           ├── guides/   # Guide documents
│           ├── reference/# Reference documents
│           └── ko/       # Korean translations
├── public/               # Static files
├── astro.config.mjs      # Astro configuration
├── package.json          # Node.js dependencies
└── tsconfig.json         # TypeScript configuration
```

## Content Guidelines

### Adding New Pages

1. Create a new `.md` or `.mdx` file in the appropriate directory under `src/content/docs/`
2. Add frontmatter at the top of the file:

```yaml
---
title: Your Page Title
description: A brief description of the page
---
```

3. Update the sidebar in `astro.config.mjs` if needed

### Adding Korean Translations

1. Create a corresponding file in `src/content/docs/ko/` with the same structure
2. The locale switcher will automatically appear in the header

### Using Mermaid Diagrams

Mermaid diagrams are supported out of the box. Just use standard Mermaid code blocks:

\`\`\`markdown
\`\`\`mermaid
graph TD
    A[Start] --> B[Process]
    B --> C[End]
\`\`\`
\`\`\`

## Syntax Highlighting

The following languages are supported by default:
- JavaScript/TypeScript
- Python
- Bash/Shell
- CMake
- PowerShell (use `pwsh` for proper highlighting)
- C/C++
- JSON/YAML

## Configuration

Main configuration is in `astro.config.mjs`:
- Site URL and base path for GitHub Pages
- Locale settings
- Sidebar navigation structure
- Social links
- Theme customization

## Deployment

The site is automatically deployed to GitHub Pages via the `.github/workflows/starlight.yml` workflow when changes are pushed to the configured branches.

## References

- [Astro Documentation](https://docs.astro.build/)
- [Starlight Documentation](https://starlight.astro.build/)
- [Pagefind Search](https://pagefind.app/)
