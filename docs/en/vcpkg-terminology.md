---
title: "vcpkg Terminology (Search Test)"
---

Short keyword-heavy definitions to test site search.

- **Triplet**: A build target like `x64-windows`, controlling ABI/build settings.
- **Overlay ports**: Extra port directories passed via `--overlay-ports`.
- **Overlay triplets**: Extra triplet directories passed via `--overlay-triplets`.
- **Registry**: A versioned collection of ports referenced from `vcpkg-configuration.json`.
- **Baseline**: A commit SHA (or registry baseline) that pins versions.
- **Versioning**: The `versions/` folder entries for reproducible installs.
- **Manifest mode**: Using `vcpkg.json` in a project to declare dependencies.
- **Classic mode**: Direct `vcpkg install <port>` usage without a manifest.
- **Features**: Optional parts of a port requested like `port[feature]`.
- **Binary caching**: Reusing built artifacts instead of rebuilding.
