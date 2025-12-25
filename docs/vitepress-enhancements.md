# VitePress Enhancements Guide

This guide covers additional enhancements and customizations for the VitePress documentation.

## Syntax Highlighting

### Adding Language Support

VitePress uses Shiki for syntax highlighting. To add support for missing languages:

1. Install the language grammar:

```bash
npm install -D shiki
```

2. Update `docs/.vitepress/config.mts` to include custom language grammars:

```typescript
import { defineConfig } from 'vitepress'

export default defineConfig({
  // ... other config
  
  markdown: {
    theme: {
      light: 'github-light',
      dark: 'github-dark'
    },
    languages: [
      // Add custom language grammars here
      // Example: PowerShell
      {
        id: 'powershell',
        scopeName: 'source.powershell',
        path: './path-to-powershell.tmLanguage.json'
      }
    ]
  }
})
```

### Current Missing Languages

The following languages show warnings:

- `pwsh` (PowerShell) - Used in command examples
- `dot` (Graphviz DOT) - Used for diagrams
- `pc` (Package Configuration) - Custom format

**Workaround**: These languages fall back to plain text syntax, which is acceptable for now.

## Custom Theme Components

### Creating Custom Components

VitePress supports Vue components in markdown. Create components in `docs/.vitepress/theme/`:

1. Create theme directory:

```bash
mkdir -p docs/.vitepress/theme/components
```

2. Create a custom component (e.g., `PortExample.vue`):

```vue
<template>
  <div class="port-example">
    <h3>{{ title }}</h3>
    <slot />
  </div>
</template>

<script setup lang="ts">
defineProps<{
  title: string
}>()
</script>

<style scoped>
.port-example {
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  padding: 1rem;
  margin: 1rem 0;
}
</style>
```

3. Register the component in `docs/.vitepress/theme/index.ts`:

```typescript
import DefaultTheme from 'vitepress/theme'
import PortExample from './components/PortExample.vue'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('PortExample', PortExample)
  }
}
```

4. Use in markdown:

```markdown
<PortExample title="Example Port">

Your content here

</PortExample>
```

## Custom Containers

VitePress supports custom containers for callouts similar to MkDocs admonitions:

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

::: details Click to expand
Hidden content here
:::

::: info
Information message
:::
```

To customize container styles, create `docs/.vitepress/theme/custom.css`:

```css
:root {
  /* Custom container colors */
  --vp-custom-block-tip-border: #42b983;
  --vp-custom-block-warning-border: #e7c000;
  --vp-custom-block-danger-border: #c00;
}
```

## Adding a Logo

1. Add logo file to `docs/public/logo.svg`
2. Update config to reference it (already configured in `config.mts`)

## Markdown Extensions

### Code Groups

Show multiple code examples with tabs:

```markdown
::: code-group

\`\`\`bash [Classic Mode]
vcpkg install --overlay-ports=./ports zlib-ng
\`\`\`

\`\`\`json [Manifest Mode]
{
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/luncliff/vcpkg-registry"
    }
  ]
}
\`\`\`

:::
```

### Badge

Add badges inline:

```markdown
- [Feature <Badge type="tip" text="new" />](/feature)
- [Guide <Badge type="warning" text="experimental" />](/guide)
- [API <Badge type="danger" text="deprecated" />](/api)
```

## Performance Optimization

### Build Performance

1. **Reduce Bundle Size**: Use dynamic imports for heavy components
2. **Optimize Images**: Use WebP format and proper sizing
3. **Code Splitting**: VitePress automatically splits code by page

### Runtime Performance

1. **Lazy Loading**: Components are loaded on demand
2. **Prefetching**: VitePress prefetches linked pages
3. **Search Index**: Built at build time for fast runtime

## SEO and Social

### Open Graph Meta Tags

Already configured in `config.mts`. To add more:

```typescript
head: [
  ['meta', { property: 'og:image', content: '/og-image.png' }],
  ['meta', { property: 'og:description', content: 'Your description' }],
  ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
]
```

### Sitemap

Install sitemap plugin:

```bash
npm install -D vite-plugin-sitemap
```

Add to config:

```typescript
import { defineConfig } from 'vitepress'
import { SitemapStream } from 'sitemap'

export default defineConfig({
  // ... other config
  
  sitemap: {
    hostname: 'https://luncliff.github.io/vcpkg-registry'
  }
})
```

## Analytics

### Google Analytics

Add to `config.mts`:

```typescript
head: [
  [
    'script',
    { async: '', src: 'https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX' }
  ],
  [
    'script',
    {},
    `window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'G-XXXXXXXXXX');`
  ]
]
```

## Internationalization (i18n)

To add English documentation alongside Korean:

1. Create `docs/en/` directory
2. Update config with locales:

```typescript
export default defineConfig({
  locales: {
    root: {
      label: '한국어',
      lang: 'ko',
    },
    en: {
      label: 'English',
      lang: 'en',
      themeConfig: {
        nav: [
          { text: 'Home', link: '/en/' },
          { text: 'Guides', link: '/en/guides' }
        ]
      }
    }
  }
})
```

3. Add translated files to `docs/en/`

## Deployment

### GitHub Actions Workflow

Create `.github/workflows/deploy-docs.yml`:

```yaml
name: Deploy VitePress Documentation

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          
      - name: Install dependencies
        run: npm ci
        
      - name: Build VitePress
        run: npm run docs:build
        
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: docs/.vitepress/dist

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

### Netlify

Create `netlify.toml`:

```toml
[build]
  command = "npm run docs:build"
  publish = "docs/.vitepress/dist"

[[redirects]]
  from = "/*"
  to = "/404.html"
  status = 404
```

### Vercel

Create `vercel.json`:

```json
{
  "buildCommand": "npm run docs:build",
  "outputDirectory": "docs/.vitepress/dist"
}
```

## Resources

- [VitePress Guide](https://vitepress.dev/guide/what-is-vitepress)
- [VitePress Theme API](https://vitepress.dev/guide/custom-theme)
- [VitePress Markdown Extensions](https://vitepress.dev/guide/markdown)
- [Shiki Languages](https://github.com/shikijs/shiki/blob/main/docs/languages.md)
