---
layout: base.njk
title: Eleventy Setup Guide
---

# Eleventy Documentation Setup

This directory contains an [Eleventy](https://www.11ty.dev/) (11ty) static site generator setup as an experimental alternative to MkDocs for the vcpkg-registry documentation.

## Overview

Eleventy is a simpler, more flexible static site generator that:
- Has zero configuration by default
- Supports multiple template engines (Nunjucks, Markdown, HTML)
- Provides faster build times
- Offers flexible customization options
- Works well with Korean language content

## Prerequisites

- Node.js 18+ (currently using v20.19.6)
- npm 10+ (currently using v10.8.2)

## Installation

From the repository root:

```bash
npm install
```

This installs Eleventy and required plugins:
- `@11ty/eleventy` - Core static site generator
- `@11ty/eleventy-plugin-syntaxhighlight` - Syntax highlighting for code blocks
- `markdown-it` - Markdown parser
- `markdown-it-attrs` - Add custom attributes to markdown elements

## Usage

### Development Server

Start a local development server with live reload:

```bash
npm start
```

The site will be available at `http://localhost:8080/`

### Build for Production

Generate the static site:

```bash
npm run build
```

Output files are generated in the `_site/` directory.

### Watch Mode

Build and watch for changes without starting a server:

```bash
npm run watch
```

### Debug Mode

Run with detailed debug information:

```bash
npm run debug
```

## Directory Structure

```
/home/runner/work/vcpkg-registry/vcpkg-registry/
├── .eleventy.js          # Eleventy configuration
├── package.json           # Node.js dependencies and scripts
├── docs/                  # Source documentation files
│   ├── _layouts/          # Page layout templates (Nunjucks)
│   │   └── base.njk       # Base layout with header, nav, footer
│   ├── _includes/         # Reusable template partials (future use)
│   ├── _data/             # Global data files (future use)
│   ├── index.md           # Homepage
│   ├── references.md      # References page
│   ├── guide-*.md         # Guide documents
│   └── troubleshooting.md # Troubleshooting guide
└── _site/                 # Generated static site (gitignored)
```

## Configuration

The `.eleventy.js` file contains the Eleventy configuration:

- **Input directory**: `docs/`
- **Output directory**: `_site/`
- **Template formats**: Markdown (`.md`), Nunjucks (`.njk`), HTML (`.html`)
- **Markdown engine**: Nunjucks
- **Plugins**: Syntax highlighting, markdown-it with attributes

### Adding Front Matter

All markdown files should include front matter at the top:

```markdown
---
layout: base.njk
title: Page Title
---

# Page Content
```

## Features

### Search Functionality

The site includes [Pagefind](https://pagefind.app/) for fast, client-side search:

- **Bilingual Support**: Indexes both English and Korean content
- **Instant Results**: No server required, all search happens in the browser
- **Smart Highlighting**: Search terms are highlighted in results
- **Korean Translations**: Search UI translated for Korean users

The search is automatically generated during the build process:
```bash
npm run build  # Builds site and indexes search
```

Search index is stored in `_site/pagefind/` and includes:
- Full-text index of all documentation pages
- Excerpts with highlighted matches
- Page titles and URLs

### Syntax Highlighting

Code blocks are automatically highlighted using Prism.js:

```javascript
// Example code
function hello() {
  console.log("Hello, world!");
}
```

### Korean Language Support

The base layout (`docs/_layouts/base.njk`) is configured for Korean language:
- `lang="ko"` attribute on HTML element
- Nanum Gothic font for Korean text
- Cascade Mono font for code

### Navigation

Navigation is defined in the base layout template. To modify navigation:
1. Edit `docs/_layouts/base.njk`
2. Update the `<nav>` section with new links

### Styling

The base layout includes inline CSS with a dark theme inspired by Material Design:
- Background: Dark slate (#1e1e1e)
- Primary: Indigo (#3949ab)
- Accent: Blue (#42a5f5)
- Font: Nanum Gothic (Korean), Cascade Mono (code)

## Comparison with MkDocs

| Feature | MkDocs | Eleventy |
|---------|---------|----------|
| Language | Python | JavaScript/Node.js |
| Setup | `pip install` | `npm install` |
| Configuration | `mkdocs.yml` | `.eleventy.js` |
| Build Speed | Moderate | Fast (0.35s for 13 pages) |
| Template Engine | Jinja2 | Multiple (Nunjucks, Liquid, etc.) |
| Flexibility | Themed | Highly customizable |
| Korean Support | ✅ | ✅ |
| Search | Built-in | Pagefind (client-side) |
| Search Korean | ✅ | ✅ |

## Future Enhancements

Potential improvements for this setup:

1. **Enhanced Navigation**
   - Add breadcrumbs
   - Implement sidebar navigation
   - Add table of contents for long pages

2. **Image Optimization**
   - Add `@11ty/eleventy-img` plugin
   - Optimize images during build
   - Support responsive images

3. **RSS Feed**
   - Generate RSS feed for documentation updates
   - Add atom feed support

4. **Asset Pipeline**
   - Separate CSS into external files
   - Add JavaScript bundling
   - Minify assets for production
   - Add PostCSS for CSS processing

5. **Search Improvements**
   - Add search filters by document type
   - Implement search analytics
   - Add keyboard shortcuts for search

## Troubleshooting

### Build Errors

If you encounter build errors:

1. Clear the output directory:
   ```bash
   rm -rf _site/
   ```

2. Clear npm cache:
   ```bash
   npm cache clean --force
   ```

3. Reinstall dependencies:
   ```bash
   rm -rf node_modules/ package-lock.json
   npm install
   ```

### Port Already in Use

If port 8080 is already in use, Eleventy will automatically find another port. Check the console output for the actual URL.

### Front Matter Issues

Ensure all markdown files have valid YAML front matter:
- Must start with `---` on line 1
- Must end with `---`
- Must include `layout` and `title` fields

## Resources

- [Eleventy Documentation](https://www.11ty.dev/docs/)
- [Eleventy Starter Projects](https://www.11ty.dev/docs/starter/)
- [Nunjucks Template Documentation](https://mozilla.github.io/nunjucks/)
- [Markdown-it Documentation](https://github.com/markdown-it/markdown-it)

## License

This setup follows the repository's license: [The Unlicense](https://unlicense.org) and [CC0 1.0 Public Domain](https://creativecommons.org/publicdomain/zero/1.0/deed.ko).
