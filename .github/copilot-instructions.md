# Instruction: vcpkg-registry maintenance

The followings are minimal guidelines to get general ideas about this repository.

- Use [References](../docs/references.md) to fetch documents for working with vcpkg commands and build toolchains.
- Use [README.md](../README.md) and files in [the docs/ folder](../docs/). 

## How To

### Setup the environment

Follow the official [Getting Started Guide](https://learn.microsoft.com/en-us/vcpkg/get_started/get-started) to setup your environment

- Required environment variables
  - `VCPKG_ROOT` to integrate with toolchains. For example, `C:\vcpkg` or `/usr/local/shared/vcpkg`
  - `PATH` to run `vcpkg` CLI program

### Using the `vcpkg` command

- Version check
  - vcpkg program behavior may change as time flows. Report the [`vcpkg` executable version](https://github.com/microsoft/vcpkg-tool/releases) when the version is unknown.
- Use `vcpkg help` command to get descriptions and test the CLI executable works.

```
vcpkg --version
```

Commonly used commands can be checked with:

```
vcpkg help
vcpkg help install
vcpkg help remove
vcpkg help search
vcpkg help depend-info
```

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

Refer [the concepts](https://learn.microsoft.com/en-us/vcpkg/concepts/triplets) and [pre-defined variables](https://learn.microsoft.com/en-us/vcpkg/users/triplets).

This repository contains some examples in [triplets/](../triplets/) folder.

- [x64-windows.cmake](../triplets/x64-windows.cmake)
- [arm64-android.cmake](../triplets/arm64-android.cmake)
- [arm64-ios-simulator.cmake](../triplets/arm64-ios-simulator.cmake)

## Troubleshooting Port Installation Errors

When encountering compiler or linker errors, refer the following links

- https://learn.microsoft.com/en-us/cpp/build/reference/compiler-options
- https://learn.microsoft.com/en-us/cpp/build/reference/linker-options

### Alternative Approach: Embedded CMakeLists.txt

When patch files become too complex or frequently fail to apply due to upstream changes, you can use the **embedded CMakeLists.txt approach** as demonstrated in [ports like `farmhash`](../ports/farmhash/).

#### How It Works

1. **Download Original**: Download the original CMakeLists.txt from the target version
   ```bash
   curl -o "ports/port-name/CMakeLists.txt" "https://raw.githubusercontent.com/OWNER/REPO/vX.Y.Z/CMakeLists.txt"
   ```

2. **Embed and Modify**: Place the file directly in your port directory and modify it in-place to work with vcpkg dependencies

3. **Copy in Portfile**: Use `file(COPY)` to overwrite the original during build:
   ```cmake
   # Copy our modified CMakeLists.txt
   file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")
   ```

#### Benefits
- **Easier Maintenance**: Direct file editing instead of complex patch management
- **Clearer Review**: Developers can see exact changes in the embedded file
- **No Patch Failures**: Eliminates patch application context mismatches
- **Rapid Prototyping**: Faster iteration during port development

#### ⚠️ **Important Warning for Upstream Contributions**

> **This approach is primarily for experimental/private registries.** 
> 
> If you plan to contribute the port to **microsoft/vcpkg upstream**, you **MUST** convert the embedded CMakeLists.txt changes back to proper patch files before submitting. The vcpkg upstream strongly prefers patch files over embedded source files for the following reasons:
> 
> - **Maintainability**: Patches show exactly what changed
> - **Upstream Compatibility**: Easier to review and maintain
> - **Standards Compliance**: Follows vcpkg contribution guidelines
> - **Conflict Reduction**: Minimizes merge conflicts with upstream changes
> 
> **Conversion Process**: Use `git diff` or `diff` tools to generate proper patch files from your embedded changes before submitting to upstream.

#### When to Use This Approach
- ✅ Complex build systems with frequent CMakeLists.txt changes
- ✅ Experimental ports in private registries  
- ✅ Rapid prototyping and testing
- ✅ When traditional patches repeatedly fail to apply

## Maintaining this repository

Mostly we work in [ports/](../ports/) and [versions/](../versions/) folder.

The ports in this vcpkg-registry checks the vcpkg upstream guides, but must of the ports may not follow them for experimental purpose.

- [microsoft/vcpkg Contributing Guideline](https://github.com/microsoft/vcpkg/blob/master/CONTRIBUTING.md)
- [Maintainer Guideline](https://github.com/microsoft/vcpkg-docs/blob/main/vcpkg/contributing/maintainer-guide.md)

### Updating a ports

- Use [guide-update-port.md](../docs/guide-update-port.md) to generate steps and todo list.
- Update todo list as each step is done.

### Testing a port

Mostly, the port's default installation works, it is enough.
However, if the port has some features, and they are important. We have to test install with the features repetitively.

1. Run `vcpkg install` command with the port name. Here, the installation needs to be "overlay install"(`--x-overlay-ports`) to prevent mix/conflict with vcpkg upstream.
2. Use `vcpkg search` command to list the port's features.
3. If there is no feature, the port is tested.
4. If there are some features, run `vcpkg install` command with each of the features.
