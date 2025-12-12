# Instruction: vcpkg-registry maintenance

The followings are minimal guidelines to get general ideas about this repository.

- Use [References](../docs/references.md) to fetch documents for working with vcpkg commands and build toolchains.
- Use [README.md](../README.md) and files in [the docs/ folder](../docs/).

## Tasks

The vcpkg-registry holds vcpkg ports(package build receipe) and related files to use and test them.
Here are the major tasks for the repository maintenance.

1. Port Creation(experimental work, fork from vcpkg upstream, etc.)
2. Port Update(support new version, fix toolchain issues, etc.)
3. Port Testing([test list](../test) inclusion/exclusion, new port feature, etc.)

### Prompts

The GitHub Copilot prompt files to help the tasks are located in [.github/prompts](./prompts/) folder.

## How To

#### Working with Overlay ports/triplets

The "overlay ports" and "overlay triplets" may need more detailed options or switches to work properly.

- Overlay ports
  - https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports
  - https://learn.microsoft.com/en-us/vcpkg/consume/install-locally-modified-package
- Overlay triplets
  - https://learn.microsoft.com/en-us/vcpkg/users/examples/overlay-triplets-linux-dynamic

Prevent using environment variable `VCPKG_OVERLAY_PORTS` and `VCPKG_OVERLAY_TRIPLETS` to avoid confusion.

```ps1
# Both relative path and absolute path are allowed for overlay options
$Workspace=$(Get-Location).Path
vcpkg install `
  --overlay-ports "$Workspace/ports" `
  --overlay-triplets "$Workspace/triplets" `
  cpuinfo
```

Instead of using default folders under `VCPKG_ROOT`, you can provide custom folders for port build/install steps.

```ps1
# RECOMMENDED: Create/use folders in the current workspace
vcpkg install --overlay-ports "ports" `
  --x-buildtrees-root "buildtrees" `
  --x-packages-root "packages" `
  --x-install-root "installed" `
  eigen3
```

### Editing baseline files in vcpkg Registry

The vcpkg registry consists of

- Port Scripts: located in [ports/](../ports/) folder
- Baseline JSON files: located in [versions/](../versions/) folder

Here, suppose we are in the root folder of the registry with the following commands

```ps1
git clone "https://github.com/luncliff/vcpkg-registry"
Set-Location "vcpkg-registry"
```

Format all `vcpkg.json` files under [ports/](../ports/) folder.

```ps1
# vcpkg help format-manifest
vcpkg format-manifest --all `
    --vcpkg-root "${env:VCPKG_ROOT}" `
    --x-builtin-ports-root "$(Get-Location)/ports" `
    --x-builtin-registry-versions-dir "$(Get-Location)/versions
```

Update baseline and version JSON files for a specific port

```ps1
# vcpkg help x-add-version
$PortName="some-port"
vcpkg x-add-version $PortName `
    --overwrite-version `
    --vcpkg-root "${env:VCPKG_ROOT}" `
    --x-builtin-ports-root "$(Get-Location)/ports" `
    --x-builtin-registry-versions-dir "$(Get-Location)/versions
```

### Writing triplet files

A triplet file is basically a set of CMake variables for `$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake`.

You have to check 2 official guide documents.
- [vcpkg concepts: Triplets](https://learn.microsoft.com/en-us/vcpkg/concepts/triplets)
- [Triplet variables](https://learn.microsoft.com/en-us/vcpkg/users/triplets)

This repository contains some examples in [triplets/](../triplets/) folder. Reference the files when new triplets are requested.

### Testing a port

Mostly, the port's default installation works, it is enough.
However, if the port has some features, and they are important. We have to test install with the features repetitively.

1. Run `vcpkg install` command with the port name. Here, the installation needs to be "overlay install"(`--x-overlay-ports`) to prevent mix/conflict with vcpkg upstream.
2. Use `vcpkg search` command to list the port's features.
3. If there is no feature, the port is tested.
4. If there are some features, run `vcpkg install` command with each of the features.

## Troubleshooting

Use the following guides.

- [Port Installation Errors](../docs/guide-troubleshooting.md)

