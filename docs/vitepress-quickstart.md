# Quick Start Guide - VitePress

This is a quick reference for working with VitePress documentation.

## Installation

First time setup:

```bash
# Install Node.js dependencies
npm install
```

This installs VitePress and all required dependencies from `package.json`.

## Development

### Start Dev Server

```bash
npm run docs:dev
```

This starts a local development server at `http://localhost:5173/` with:
- Hot Module Replacement (HMR) - instant updates
- Built-in search
- All documentation pages

**Tip**: Keep this running while editing documentation for instant preview.

### Build for Production

```bash
npm run docs:build
```

This creates an optimized production build in `docs/.vitepress/dist/`.

### Preview Production Build

```bash
npm run docs:preview
```

This serves the production build locally at `http://localhost:4173/` to verify it works correctly.

## Common Tasks

### Adding a New Page

1. Create a new `.md` file in `docs/`:
   ```bash
   touch docs/my-new-page.md
   ```

2. Add content:
   ```markdown
   # My New Page
   
   Content goes here...
   ```

3. Add to navigation in `docs/.vitepress/config.mts`:
   ```typescript
   sidebar: [
     {
       text: 'My Section',
       items: [
         { text: 'My New Page', link: '/my-new-page' }
       ]
     }
   ]
   ```

### Editing Existing Pages

Just edit any `.md` file in `docs/`. If the dev server is running, changes will appear instantly.

### Updating Navigation

Edit `docs/.vitepress/config.mts`:
- `nav` - Top navigation bar
- `sidebar` - Left sidebar navigation

### Changing Theme Settings

Edit `docs/.vitepress/config.mts`:
- Colors, fonts, logo
- Search configuration
- Footer text
- Social links

## Markdown Features

### Basic Markdown

Standard markdown works as expected:

```markdown
# Heading 1
## Heading 2
### Heading 3

**bold** and *italic*

- List item 1
- List item 2

[Link text](https://example.com)

![Image](./image.png)
```

### Code Blocks

````markdown
```bash
vcpkg install package-name
```

```json
{
  "key": "value"
}
```
````

### Custom Containers

VitePress provides callout boxes:

```markdown
::: tip
This is a tip
:::

::: warning
This is a warning  
:::

::: danger
This is dangerous
:::

::: info
Informational note
:::

::: details Click me to expand
Hidden content here
:::
```

### Code Groups

Show multiple code examples with tabs:

````markdown
::: code-group

```bash [Linux]
export VCPKG_ROOT="/usr/local/share/vcpkg"
```

```powershell [Windows]
$env:VCPKG_ROOT="C:/vcpkg"
```

:::
````

### Badges

Add inline badges:

```markdown
New feature <Badge type="tip" text="new" />
Experimental <Badge type="warning" text="beta" />
Deprecated <Badge type="danger" text="deprecated" />
```

## Troubleshooting

### Build Fails

If build fails, check:
1. Node.js version (need 18+)
2. Dependencies installed (`npm install`)
3. No syntax errors in markdown files
4. No syntax errors in `config.mts`

### Dev Server Won't Start

```bash
# Clear cache and restart
rm -rf docs/.vitepress/cache
rm -rf node_modules/.vite
npm run docs:dev
```

### Search Not Working

Search is built at build time. If it's not working:
1. Rebuild: `npm run docs:build`
2. Check browser console for errors

### Syntax Highlighting Issues

If code blocks don't highlight:
- Check language is spelled correctly
- Some languages fall back to plain text (this is OK)

## NPM Scripts Reference

All available commands:

```bash
npm run docs:dev      # Start dev server (port 5173)
npm run docs:build    # Build for production
npm run docs:preview  # Preview production build (port 4173)
```

## Files and Directories

```
.
├── docs/                      # All documentation files
│   ├── .vitepress/           
│   │   ├── config.mts        # VitePress configuration
│   │   ├── cache/            # Build cache (gitignored)
│   │   └── dist/             # Production build (gitignored)
│   ├── index.md              # Home page
│   └── *.md                  # All other pages
├── package.json              # NPM dependencies and scripts
└── node_modules/             # Dependencies (gitignored)
```

## Getting Help

- [VitePress Documentation](https://vitepress.dev/)
- [Markdown Guide](https://vitepress.dev/guide/markdown)
- [Configuration Reference](https://vitepress.dev/reference/site-config)
- Repository: See [vitepress-experiment.md](./vitepress-experiment.md) for detailed info

## Next Steps

1. ✅ Install dependencies (`npm install`)
2. ✅ Start dev server (`npm run docs:dev`)
3. ⬜ Edit documentation files
4. ⬜ Test your changes locally
5. ⬜ Build for production (`npm run docs:build`)
6. ⬜ Deploy to hosting platform
