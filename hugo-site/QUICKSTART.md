# Quick Start: Hugo Experiment

Want to try the Hugo implementation? Here's a 5-minute quick start guide.

## Prerequisites

You need Hugo installed. Choose one method:

### Option 1: Download Binary (Recommended)
```bash
# Linux/macOS
wget https://github.com/gohugoio/hugo/releases/download/v0.153.2/hugo_extended_0.153.2_linux-amd64.tar.gz
tar -xzf hugo_extended_0.153.2_linux-amd64.tar.gz
sudo mv hugo /usr/local/bin/

# Verify
hugo version
```

### Option 2: Package Manager
```bash
# Ubuntu/Debian
sudo apt install hugo

# macOS
brew install hugo

# Windows
choco install hugo-extended
```

### Option 3: Go Install
```bash
go install github.com/gohugoio/hugo@latest
```

## Quick Start

```bash
# 1. Clone and switch to experiment branch
git clone https://github.com/luncliff/vcpkg-registry.git
cd vcpkg-registry
git checkout copilot/experiment-hugo-implementation

# 2. Navigate to Hugo site
cd hugo-site

# 3. Start development server
hugo server --bind 0.0.0.0 --port 8080

# 4. Visit in browser
# Open: http://localhost:8080/vcpkg-registry/
```

## Build for Production

```bash
cd hugo-site
hugo --gc --minify --cleanDestinationDir

# Output will be in public/ directory
# Takes ~240ms to build 28 pages
```

## What You'll See

- **Homepage** - Overview with navigation to guides
- **Guides** - Create Port, Update Port, Troubleshooting
- **References** - Quick reference documentation
- **Search** - Built-in search functionality
- **Multi-language** - Toggle between English and Korean

## Compare with MkDocs

Want to compare? The MkDocs version is still available:

```bash
# Install MkDocs
pip install mkdocs mkdocs-material

# Build MkDocs site
mkdocs build

# Serve MkDocs site
mkdocs serve
```

Then compare:
- **Build speed**: Hugo ~240ms vs MkDocs ~2s
- **Output size**: Hugo ~5.2MB vs MkDocs ~5MB
- **Features**: Both have search, navigation, themes
- **Dependencies**: Hugo (single binary) vs MkDocs (Python + packages)

## Next Steps

1. ✅ Browse the generated site
2. ✅ Check navigation and search
3. ✅ Compare with MkDocs output
4. 📖 Read `HUGO_EXPERIMENT.md` for full details
5. 📖 Read `hugo-site/COMPARISON.md` for detailed analysis
6. 🤔 Decide which system fits your needs

## Troubleshooting

**Hugo not found?**
```bash
# Check if it's in PATH
which hugo
echo $PATH

# Add Go bin to PATH if using Go install
export PATH="$HOME/go/bin:$PATH"
```

**Build fails?**
```bash
# Clean and rebuild
cd hugo-site
rm -rf public resources
hugo --cleanDestinationDir
```

**Port already in use?**
```bash
# Use different port
hugo server --port 8081
```

## Key Differences from MkDocs

| Aspect | Hugo | MkDocs |
|--------|------|--------|
| **Config** | `hugo.toml` | `mkdocs.yml` |
| **Content** | `hugo-site/content/` | `docs/` |
| **Output** | `hugo-site/public/` | `site/` |
| **Command** | `hugo` | `mkdocs build` |
| **Server** | `hugo server` | `mkdocs serve` |

## Resources

- 📖 Full documentation: `hugo-site/README.md`
- 📊 Comparison analysis: `hugo-site/COMPARISON.md`
- 🎯 Experiment summary: `HUGO_EXPERIMENT.md`
- 🌐 Hugo docs: https://gohugo.io/
- 🎨 Hugo Book theme: https://github.com/alex-shpak/hugo-book

## Questions?

See the full documentation in:
- `HUGO_EXPERIMENT.md` - Overview and decision guide
- `hugo-site/README.md` - Detailed setup instructions
- `hugo-site/COMPARISON.md` - MkDocs vs Hugo analysis

---

**Happy exploring!** 🚀
