# Markdown SSG Research Report: Alternatives to MkDocs

**Date:** December 25, 2025  
**Context:** Evaluating static site generators (SSGs) to replace MkDocs for vcpkg-registry documentation

## Executive Summary

This report compares five leading static site generators suitable for documentation sites with a focus on GitHub Pages deployment, multilingual support (Korean/English), search functionality, and extensibility through plugins. The evaluated tools are:

1. **Docusaurus** (React-based, Meta/Facebook)
2. **VitePress** (Vue-based, Vue.js team)
3. **Astro/Starlight** (Multi-framework, Astro team)
4. **Hugo** (Go-based, independent)
5. **Eleventy** (JavaScript-based, independent)

Based on the requirements prioritization (GitHub Pages integration > Search > Plugin ecosystem > Multilingual support), **Docusaurus** and **VitePress** emerge as the strongest candidates, with **Astro/Starlight** as a compelling alternative for teams comfortable with modern JavaScript frameworks.

---

## Requirements Recap

| Priority | Requirement | Details |
|----------|-------------|---------|
| **Highest** | GitHub Pages Integration | Simple deployment workflow |
| **High** | Search Functionality | Algolia or local/self-hosted search |
| **High** | Multilingual Support | Korean + English |
| **High** | Plugin Ecosystem | Diagrams (Mermaid/Graphviz), syntax highlighting, copy-to-clipboard |
| **Medium** | Navigation UX | Sidebar tags/labels for related docs |
| **Medium** | Local Dev Server | Fast hot-reload for content editing |
| **Optional** | Multi-doc View | Parallel page view (nice-to-have) |
| **Non-requirement** | Version Management | Not needed |

---

## Detailed Tool Comparison

### 1. Docusaurus

**Website:** https://docusaurus.io/  
**Stack:** React, Node.js  
**Maintained by:** Meta (Facebook)

#### Features

- **Search:** 
  - **Algolia DocSearch** (free for open source, hosted)
  - Optional local search plugins available
  - Built-in contextual search with language/version filtering
- **i18n:** 
  - Native internationalization support
  - Simple file-based structure (`i18n/[locale]/...`)
  - Supports multiple locales with minimal configuration
- **Syntax Highlighting:** 
  - Built-in Prism.js integration
  - Supports 100+ languages including PowerShell, CMake, Bash
- **Copy-to-Clipboard:** 
  - Built-in copy button for code blocks
- **Diagrams:** 
  - Mermaid support via `@docusaurus/theme-mermaid` plugin
  - Community plugins for other diagram types
- **Navigation:** 
  - Sidebar with tags/badges support
  - Frontmatter-based categorization
  - Related docs via metadata linking
- **Local Dev Server:** 
  - Fast hot-reload with webpack/Vite
  - Instant content updates

#### Pros

- ✅ **Best-in-class documentation UX** out of the box
- ✅ **Strong search** with free Algolia integration for OSS projects
- ✅ **Excellent i18n support** with simple configuration
- ✅ **Rich plugin ecosystem** (React components)
- ✅ **Large community** (used by Meta, Babel, Jest, Redux)
- ✅ **GitHub Pages deployment** is well-documented and straightforward
- ✅ **Built-in features** reduce need for custom development

#### Cons

- ❌ **React knowledge helpful** for deep customization
- ❌ **Heavier bundle size** compared to minimal SSGs
- ❌ **Node.js dependency** (not a concern per requirements)

#### Learning Curve

- **Getting Started:** Easy (scaffold with `npx create-docusaurus`)
- **Basic Usage:** Easy (Markdown-focused, familiar structure)
- **Advanced Customization:** Moderate (React/TypeScript knowledge beneficial)

#### GitHub Actions Workflow

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build website
        run: npm run build
      
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v4
        with:
          path: ./build

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

---

### 2. VitePress

**Website:** https://vitepress.dev/  
**Stack:** Vue.js, Vite  
**Maintained by:** Vue.js core team

#### Features

- **Search:** 
  - **Built-in local search** (MiniSearch-based)
  - Optional Algolia DocSearch integration
  - No external dependencies for basic search
- **i18n:** 
  - Native internationalization support
  - Locale-based routing (`/en/`, `/ko/`)
  - Frontmatter-based translation
- **Syntax Highlighting:** 
  - Shiki-based (better than Prism, supports more languages)
  - Built-in line highlighting and focus
- **Copy-to-Clipboard:** 
  - Built-in copy button
- **Diagrams:** 
  - Community Mermaid plugin (`vitepress-plugin-mermaid`)
  - Vue component integration for custom diagrams
- **Navigation:** 
  - Flexible sidebar with frontmatter control
  - Can add badges/tags via frontmatter
- **Local Dev Server:** 
  - **Extremely fast** (<100ms updates via Vite HMR)

#### Pros

- ✅ **Blazing fast dev server** (Vite-powered)
- ✅ **Built-in local search** (no external service needed)
- ✅ **Lightweight and performant** (smaller bundle than Docusaurus)
- ✅ **Excellent syntax highlighting** (Shiki)
- ✅ **Simple configuration** for most use cases
- ✅ **Native i18n support**
- ✅ **GitHub Pages deployment** is straightforward

#### Cons

- ❌ **Smaller community** than Docusaurus
- ❌ **Fewer plugins** compared to Docusaurus
- ❌ **Vue knowledge helpful** for customization

#### Learning Curve

- **Getting Started:** Easy (similar to MkDocs simplicity)
- **Basic Usage:** Very Easy (Markdown-focused)
- **Advanced Customization:** Moderate (Vue.js knowledge beneficial)

#### GitHub Actions Workflow

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0  # For lastUpdated feature
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run docs:build
      
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v4
        with:
          path: docs/.vitepress/dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

---

### 3. Astro with Starlight

**Website:** https://starlight.astro.build/  
**Stack:** Astro (multi-framework), Node.js  
**Maintained by:** Astro core team

#### Features

- **Search:** 
  - **Built-in** with Pagefind (static search)
  - Algolia DocSearch integration available
  - Fast, client-side full-text search
- **i18n:** 
  - First-class internationalization
  - Automatic language routing
  - RTL language support
- **Syntax Highlighting:** 
  - Built-in Shiki integration
  - Supports code annotations and highlights
- **Copy-to-Clipboard:** 
  - Built-in copy button
- **Diagrams:** 
  - Mermaid support via integration
  - Can use any JavaScript diagram library
- **Navigation:** 
  - Auto-generated sidebar from file structure
  - Badge/tag support in sidebar
  - Related links via frontmatter
- **Local Dev Server:** 
  - Fast Vite-based dev server

#### Pros

- ✅ **Modern, component-agnostic** (use React, Vue, Svelte, etc.)
- ✅ **Built-in search** with Pagefind (no external service)
- ✅ **Excellent documentation focus** (Starlight theme)
- ✅ **Best-in-class performance** (partial hydration)
- ✅ **Rich plugin ecosystem** via Astro integrations
- ✅ **Native i18n support**
- ✅ **GitHub Pages deployment** well-documented

#### Cons

- ❌ **Relatively new** (less battle-tested than others)
- ❌ **Smaller documentation community** compared to Docusaurus
- ❌ **Learning curve** for Astro concepts

#### Learning Curve

- **Getting Started:** Easy (scaffold with CLI)
- **Basic Usage:** Easy (Markdown + frontmatter)
- **Advanced Customization:** Moderate to High (requires Astro knowledge)

#### GitHub Actions Workflow

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      - name: Install, build, and upload
        uses: withastro/action@v5
        # with:
        #   path: . # project root
        #   node-version: 22
        #   package-manager: pnpm@latest

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

---

### 4. Hugo

**Website:** https://gohugo.io/  
**Stack:** Go (single binary)  
**Maintained by:** Community (originally by Steve Francia)

#### Features

- **Search:** 
  - **No built-in search**
  - Requires third-party integration (Lunr.js, Fuse.js, or Algolia)
  - Community plugins available
- **i18n:** 
  - **Excellent built-in multilingual support**
  - Powerful translation framework
  - Can have different content per language
- **Syntax Highlighting:** 
  - Built-in Chroma support
  - Extensive language support
- **Copy-to-Clipboard:** 
  - Requires custom JavaScript or theme support
- **Diagrams:** 
  - Mermaid via shortcodes or themes
  - Requires configuration
- **Navigation:** 
  - Powerful menu system
  - Taxonomy support for categorization
- **Local Dev Server:** 
  - **Blazing fast** (Go-based, sub-second builds)

#### Pros

- ✅ **Fastest build times** (especially for large sites)
- ✅ **Single binary** (no Node.js/npm dependencies)
- ✅ **Excellent i18n** built-in
- ✅ **Mature and stable** (8+ years)
- ✅ **Large theme ecosystem**
- ✅ **GitHub Pages deployment** well-documented

#### Cons

- ❌ **No built-in search** (requires integration work)
- ❌ **Steeper learning curve** (Go templates)
- ❌ **More template configuration** needed vs others
- ❌ **Manual setup** for modern features (copy buttons, etc.)

#### Learning Curve

- **Getting Started:** Moderate (Go templates can be unfamiliar)
- **Basic Usage:** Moderate (requires learning Hugo's structure)
- **Advanced Customization:** Moderate to High (Go template language)

#### GitHub Actions Workflow

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

defaults:
  run:
    shell: bash

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      HUGO_VERSION: 0.153.2
    steps:
      - name: Checkout
        uses: actions/checkout@v5
        with:
          submodules: recursive
          fetch-depth: 0
      
      - name: Setup Pages
        id: pages
        uses: actions/configure-pages@v5
      
      - name: Install Hugo CLI
        run: |
          wget -O hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz"
          tar -xvf hugo.tar.gz
          sudo mv hugo /usr/local/bin/
      
      - name: Build with Hugo
        run: |
          hugo \
            --gc \
            --minify \
            --baseURL "${{ steps.pages.outputs.base_url }}/"
      
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./public

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

---

### 5. Eleventy (11ty)

**Website:** https://www.11ty.dev/  
**Stack:** JavaScript (Node.js)  
**Maintained by:** Zach Leatherman (Font Awesome/Independent)

#### Features

- **Search:** 
  - **No built-in search**
  - Requires third-party integration (Lunr.js, Pagefind, or Algolia)
  - Community plugins available
- **i18n:** 
  - Manual implementation required
  - Community plugins available (`eleventy-plugin-i18n`)
  - More flexible but requires more setup
- **Syntax Highlighting:** 
  - Plugin available (`@11ty/eleventy-plugin-syntaxhighlight`)
  - Prism.js-based
- **Copy-to-Clipboard:** 
  - Requires custom JavaScript
- **Diagrams:** 
  - Requires custom integration or plugins
- **Navigation:** 
  - Manual setup via collections and templates
  - Very flexible but requires configuration
- **Local Dev Server:** 
  - Built-in dev server
  - Fast incremental builds

#### Pros

- ✅ **Extremely flexible** (use any template language)
- ✅ **Zero JavaScript by default** (fastest possible sites)
- ✅ **Simple, transparent build process**
- ✅ **Works with existing projects** (incremental adoption)
- ✅ **Large community** (15M+ downloads)
- ✅ **Multiple template languages** (Liquid, Nunjucks, etc.)

#### Cons

- ❌ **No built-in search**
- ❌ **Manual i18n setup** required
- ❌ **More configuration** needed for documentation features
- ❌ **Less opinionated** (need to build more yourself)
- ❌ **Steeper learning curve** for docs-specific features

#### Learning Curve

- **Getting Started:** Easy (minimal setup)
- **Basic Usage:** Moderate (need to understand collections, templates)
- **Advanced Customization:** Moderate to High (requires JavaScript knowledge)

#### GitHub Actions Workflow

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run build
      
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v4
        with:
          path: ./_site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

---

## Feature Comparison Matrix

| Feature | Docusaurus | VitePress | Astro/Starlight | Hugo | Eleventy |
|---------|------------|-----------|-----------------|------|----------|
| **Search** | ⭐⭐⭐⭐⭐ Algolia/Local | ⭐⭐⭐⭐⭐ Built-in Local | ⭐⭐⭐⭐⭐ Pagefind | ⭐⭐⭐ Plugin Required | ⭐⭐ Plugin Required |
| **i18n Support** | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐⭐⭐ Native | ⭐⭐ Manual Setup |
| **Syntax Highlighting** | ⭐⭐⭐⭐ Prism | ⭐⭐⭐⭐⭐ Shiki | ⭐⭐⭐⭐⭐ Shiki | ⭐⭐⭐⭐ Chroma | ⭐⭐⭐⭐ Prism Plugin |
| **Copy-to-Clipboard** | ⭐⭐⭐⭐⭐ Built-in | ⭐⭐⭐⭐⭐ Built-in | ⭐⭐⭐⭐⭐ Built-in | ⭐⭐ Manual/Theme | ⭐⭐ Manual |
| **Diagram Support** | ⭐⭐⭐⭐ Mermaid Plugin | ⭐⭐⭐⭐ Mermaid Plugin | ⭐⭐⭐⭐⭐ Built-in | ⭐⭐⭐ Shortcodes | ⭐⭐ Custom |
| **Navigation/Sidebar** | ⭐⭐⭐⭐⭐ Rich | ⭐⭐⭐⭐ Flexible | ⭐⭐⭐⭐⭐ Auto-generated | ⭐⭐⭐⭐ Powerful | ⭐⭐⭐ Manual |
| **Local Dev Speed** | ⭐⭐⭐⭐ Fast | ⭐⭐⭐⭐⭐ Fastest | ⭐⭐⭐⭐⭐ Very Fast | ⭐⭐⭐⭐⭐ Instant | ⭐⭐⭐⭐ Fast |
| **GitHub Pages** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Official Action | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐ Standard |
| **Plugin Ecosystem** | ⭐⭐⭐⭐⭐ Rich | ⭐⭐⭐ Growing | ⭐⭐⭐⭐ Rich (Astro) | ⭐⭐⭐⭐ Mature | ⭐⭐⭐ Moderate |
| **Learning Curve** | ⭐⭐⭐⭐ Easy | ⭐⭐⭐⭐⭐ Very Easy | ⭐⭐⭐⭐ Easy | ⭐⭐⭐ Moderate | ⭐⭐⭐ Moderate |
| **Container Build** | ⭐⭐⭐⭐⭐ Node.js | ⭐⭐⭐⭐⭐ Node.js | ⭐⭐⭐⭐⭐ Node.js | ⭐⭐⭐⭐⭐ Go Binary | ⭐⭐⭐⭐⭐ Node.js |

---

## Pros & Cons Summary Table

| Tool | Strong Points | Weak Points | Best For |
|------|---------------|-------------|----------|
| **Docusaurus** | Complete docs solution, Algolia search, rich features, large community | React dependency, heavier bundle | Teams wanting comprehensive out-of-box solution |
| **VitePress** | Lightning fast, built-in search, lightweight, simple | Smaller community, fewer plugins | Teams prioritizing speed and simplicity |
| **Astro/Starlight** | Modern stack, excellent performance, flexible | Newer, less battle-tested | Teams comfortable with modern JS frameworks |
| **Hugo** | Fastest builds, single binary, mature | No built-in search, steeper learning curve | Teams with Go familiarity or huge sites |
| **Eleventy** | Maximum flexibility, framework-agnostic | Manual setup for docs features | Teams needing full control and customization |

---

## Recommendations by Use Case

### 1. **Best Overall for Documentation (Recommended)**
**Winner:** **Docusaurus**

**Reasoning:**
- Comprehensive documentation-focused feature set out of the box
- Free Algolia search for open source projects
- Excellent i18n support with minimal configuration
- Rich plugin ecosystem for extensibility
- Large community and battle-tested (used by Meta, Microsoft, etc.)
- All requirements met with minimal custom development

**Migration Effort:** Moderate (structure is similar to MkDocs)

---

### 2. **Best for Performance & Simplicity**
**Winner:** **VitePress**

**Reasoning:**
- Lightning-fast local development (<100ms hot reload)
- Built-in local search (no external service dependencies)
- Clean, minimal approach to documentation
- Excellent syntax highlighting with Shiki
- Similar simplicity to MkDocs but more modern

**Migration Effort:** Low to Moderate (closest to MkDocs philosophy)

---

### 3. **Best for Modern JavaScript Teams**
**Winner:** **Astro with Starlight**

**Reasoning:**
- Best-in-class performance with partial hydration
- Framework-agnostic (use React, Vue, Svelte together)
- Built-in static search (Pagefind)
- Excellent documentation theme out of the box
- Future-proof architecture

**Migration Effort:** Moderate (new concepts to learn)

---

### 4. **Best for Maximum Flexibility**
**Winner:** **Eleventy**

**Reasoning:**
- Full control over every aspect
- Framework-agnostic approach
- Can incrementally adopt
- Zero JavaScript by default (fastest possible sites)

**Migration Effort:** High (most manual work required)

**Not Recommended For:** This project (lacks built-in docs features)

---

### 5. **Best for Go/Performance Enthusiasts**
**Winner:** **Hugo**

**Reasoning:**
- Fastest build times at scale
- Single binary (no npm/Node.js)
- Excellent i18n support
- Mature and stable

**Migration Effort:** Moderate to High (different templating paradigm)

**Not Recommended For:** This project (search requires manual integration)

---

## Final Recommendation

### Top Choice: **Docusaurus**

**Rationale:**
1. **Meets all requirements** with minimal configuration
2. **Free Algolia search** for open source (or local search plugins)
3. **Best-in-class documentation UX** proven by major projects
4. **Strong multilingual support** with simple setup
5. **Rich plugin ecosystem** for future extensibility
6. **GitHub Pages deployment** is straightforward and well-documented
7. **Large community** ensures long-term support and resources

### Alternative Choice: **VitePress**

**Rationale:**
1. **Simpler than Docusaurus** (closer to MkDocs philosophy)
2. **Built-in local search** (no external dependencies)
3. **Lightning-fast development** experience
4. **Excellent for technical documentation** (used by Vue.js, Vite, Vitest)
5. **Smaller bundle size** for faster page loads

### Migration Path Recommendation

**Phase 1: Evaluation** (1-2 days)
- Set up local test with Docusaurus and VitePress
- Migrate 2-3 sample documents to each
- Test Korean + English translation workflows
- Evaluate dev experience and build times

**Phase 2: Implementation** (1 week)
- Choose final tool based on hands-on evaluation
- Migrate all documentation content
- Configure plugins (Mermaid, search, etc.)
- Set up GitHub Actions workflow
- Test deployment to GitHub Pages

**Phase 3: Polish** (2-3 days)
- Configure navigation and sidebar
- Add custom branding/styling if needed
- Optimize search configuration
- Document workflow for contributors

---

## References

### Official Documentation
- **Docusaurus:** https://docusaurus.io/docs
  - Search: https://docusaurus.io/docs/search
  - i18n: https://docusaurus.io/docs/i18n/introduction
  - Deployment: https://docusaurus.io/docs/deployment
- **VitePress:** https://vitepress.dev/
  - Guide: https://vitepress.dev/guide/what-is-vitepress
  - i18n: https://vitepress.dev/guide/i18n
  - Deployment: https://vitepress.dev/guide/deploy
- **Astro/Starlight:** https://starlight.astro.build/
  - Getting Started: https://starlight.astro.build/getting-started/
  - GitHub Pages: https://docs.astro.build/en/guides/deploy/github/
- **Hugo:** https://gohugo.io/
  - Documentation: https://gohugo.io/documentation/
  - Multilingual: https://gohugo.io/content-management/multilingual/
  - GitHub Pages: https://gohugo.io/hosting-and-deployment/hosting-on-github/
- **Eleventy:** https://www.11ty.dev/
  - Getting Started: https://www.11ty.dev/docs/
  - Plugins: https://www.11ty.dev/docs/plugins/

### Additional Resources
- **Awesome Static Generators:** https://github.com/myles/awesome-static-generators
- **Jamstack.org Generators List:** https://jamstack.org/generators/
- **GitHub Actions for Pages:** https://github.com/actions/deploy-pages
- **Algolia DocSearch:** https://docsearch.algolia.com/
- **Mermaid.js:** https://mermaid.js.org/
- **Pagefind (Static Search):** https://pagefind.app/

### Comparison Articles & Blog Posts
- Docusaurus vs VitePress: Framework-specific but both excellent for docs
- Static Site Generators 2025: Trends toward faster builds and better DX
- Documentation as Code: Best practices for technical documentation

### Community Resources
- Docusaurus Discord: https://discord.gg/docusaurus
- VitePress Discord: https://discord.com/invite/vue
- Astro Discord: https://astro.build/chat
- Hugo Forum: https://discourse.gohugo.io/
- Eleventy Discord: https://www.11ty.dev/blog/discord/

---

## Appendix: Quick Start Commands

### Docusaurus
```bash
npx create-docusaurus@latest my-docs classic
cd my-docs
npm start
```

### VitePress
```bash
npm init vitepress@latest
cd my-docs
npm install
npm run docs:dev
```

### Astro/Starlight
```bash
npm create astro@latest -- --template starlight
cd my-docs
npm install
npm run dev
```

### Hugo
```bash
brew install hugo  # or download binary
hugo new site my-docs
cd my-docs
hugo server
```

### Eleventy
```bash
npm init -y
npm install @11ty/eleventy
npx @11ty/eleventy --serve
```

---

**Report Prepared By:** GitHub Copilot  
**Review Status:** Draft for evaluation  
**Next Steps:** Hands-on prototype with top 2 candidates (Docusaurus & VitePress)
