# Hugo Experiment for vcpkg-registry

This directory contains an experimental Hugo static site generator setup as an alternative/complement to the existing MkDocs documentation.

## Overview

**Status:** Experimental ✨  
**Hugo Version:** v0.153.2+extended  
**Theme:** [Hugo Book](https://github.com/alex-shpak/hugo-book)

## What's Been Done

### ✅ Phase 1: Setup Complete
- Hugo extended version installed via Go
- Initial Hugo site structure created
- Hugo Book theme installed for technical documentation
- Configuration file (`hugo.toml`) created with:
  - Repository metadata
  - Multi-language support (English + Korean)
  - Theme-specific settings
  - Markdown rendering options

### ✅ Phase 2: Content Migration
- Existing documentation copied from `docs/` directory
- Front matter added to key guide files
- Homepage (`_index.md`) created with navigation
- Site structure organized for Hugo

### ✅ Phase 3: Build & Test
- Site successfully builds with Hugo
- Development server tested and working
- Output generates 20 pages in English, 8 in Korean
- All static assets properly included

## Directory Structure

```
hugo-site/
├── archetypes/       # Content templates
├── assets/          # CSS, JS, images to be processed
├── content/         # Markdown documentation files
│   ├── _index.md   # Homepage
│   ├── guide-create-port.md
│   ├── guide-update-port.md
│   └── ... (other docs)
├── data/            # Data files for content generation
├── i18n/            # Internationalization files
├── layouts/         # Custom HTML templates
├── static/          # Static files (copied as-is)
├── themes/          # Hugo themes
│   └── hugo-book/  # Documentation theme
├── hugo.toml       # Main configuration file
└── public/         # Generated static site (not committed)
```

## Usage

### Build the Site

```bash
cd hugo-site
hugo --cleanDestinationDir
```

The generated site will be in the `public/` directory.

### Run Development Server

```bash
cd hugo-site
hugo server --bind 0.0.0.0 --port 8080
```

Then visit: http://localhost:8080/vcpkg-registry/

### Configuration

Key configuration is in `hugo.toml`:
- **baseURL**: Set to GitHub Pages URL
- **theme**: hugo-book
- **languages**: English (en) and Korean (ko)
- **params**: Book theme customization

## Comparison with MkDocs

| Feature | MkDocs | Hugo |
|---------|--------|------|
| **Language** | Python | Go |
| **Speed** | Medium | Very Fast |
| **Theme** | Material | Hugo Book |
| **Multi-language** | Manual | Native |
| **Build time** | ~seconds | <1 second |
| **Dependencies** | Python + pip packages | Single binary |
| **Search** | Built-in | Theme-dependent |

## Next Steps

### Pending Tasks
- [ ] Test all documentation pages for proper rendering
- [ ] Configure GitHub Actions for Hugo builds
- [ ] Set up GitHub Pages deployment
- [ ] Add custom layouts if needed
- [ ] Test search functionality
- [ ] Verify all internal links work
- [ ] Add syntax highlighting for code blocks
- [ ] Compare output with MkDocs version
- [ ] Document migration process
- [ ] Create decision document for choosing between MkDocs and Hugo

### Future Considerations
- Custom shortcodes for common patterns
- Integration with existing CI/CD
- Performance benchmarks
- Theme customization options

## Notes

- The `themes/hugo-book` directory contains a git repository. It should be added as a git submodule or the `.git` directory should be removed before committing.
- The current setup preserves the existing `docs/` directory and MkDocs configuration for comparison.
- Hugo's build is significantly faster than MkDocs (milliseconds vs seconds).
- The Hugo Book theme provides good documentation-focused features out of the box.

## Resources

- [Hugo Documentation](https://gohugo.io/documentation/)
- [Hugo Book Theme](https://github.com/alex-shpak/hugo-book)
- [Hugo Book Theme Demo](https://hugo-book-demo.netlify.app/)
- [vcpkg-registry Repository](https://github.com/luncliff/vcpkg-registry)
