
# GitHub Copilot Instructions for vcpkg package manager

Use [References](../docs/references.md) to fetch documents for working with vcpkg commands and build toolchains.

## How To

The followings are minimal guidelines.

### Setup the environment

Follow the official [Getting Started Guide](https://learn.microsoft.com/en-us/vcpkg/get_started/get-started) to setup your environment

- Required environment variables
  - `VCPKG_ROOT` to integrate with toolchains. For example, `C:\vcpkg` or `/usr/local/shared/vcpkg`
  - `PATH` to run `vcpkg` CLI program
- Version check
  - vcpkg program behavior may change as time flows. Report the `vcpkg` executable version with the command

```console
> vcpkg --version
vcpkg package management program version 2025-03-13-7699e411ea11543de6abc0c7d5fd11cfe0039ae5
...
```

#### For GitHub Actions

Use the following project to integrate vcpkg into CI workflows

- https://github.com/lukka/run-vcpkg
- https://github.com/actions/runner-images

### Using the `vcpkg` command

- https://github.com/microsoft/vcpkg-tool

Use `vcpkg help` command to get descriptions.

```console
> vcpkg help
usage: vcpkg <command> [--switches] [--options=values] [arguments] @response_file
...
For More Help:
  help topics            Displays full list of help topics
  help <topic>           Displays specific help topic
  help commands          Displays full list of commands, including rare ones not listed here
  help <command>         Displays help detail for <command>
```

Read the messages of the the following commands if you just started to use `vcpkg`.

```
vcpkg help install
vcpkg help remove
```

#### `search` for ports/features

```
# Example: Search for "ssl"
vcpkg search "ssl"
```

#### Dependency Information: `depend-info`

```
# Example: Check dependencies for "assimp"
vcpkg depend-info "assimp"
```

#### Working with Overlay ports/triplets

The "overlay ports" and "overlay triplets" may need more detailed options or switches to work properly.

- Overlay ports
  - https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports
  - https://learn.microsoft.com/en-us/vcpkg/consume/install-locally-modified-package#7---install-your-overlay-port
- Overlay triplets
  - https://learn.microsoft.com/en-us/vcpkg/users/examples/overlay-triplets-linux-dynamic

If you want to use the [openssl3](../ports/openssl3) port in the reigstry,
You have to provide the `--overlay-ports` option, or `VCPKG_OVERLAY_PORTS` environment variable.

```ps1
# suppose you cloned the vcpkg-registry repository to "C:/vcpkg-registry"
vcpkg install --overlay-ports "C:/vcpkg-registry/ports" openssl3
```

You may not want to modify folders under `VCPKG_ROOT`(or `$env:VCPKG_ROOT` in PowerShell) to compare build logs under "buildtrees" folder, or port install outputs in "packages" folder
In the case, you can to provide `--x-*-root` options to the `vcpkg install` command.

```ps1
vcpkg install --overlay-ports "C:/vcpkg-registry/ports" `
  --x-buildtrees-root "buildtrees" `
  --x-packages-root "packages" `
  --x-install-root "installed" `
  openssl3
```

### Editing baseline files in vcpkg Registry

- See [README.md](../README.md) to read more detailed references

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

Update baseline adn version JSON files for a specific port

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

When patch files become too complex or frequently fail to apply due to upstream changes, you can use the **embedded CMakeLists.txt approach** as demonstrated in ports like `farmhash`.

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

This repository is for experiment with vcpkg.  
Mostly for port creation/sharing without following the guidelines.

- [microsoft/vcpkg Contributing Guideline](https://github.com/microsoft/vcpkg/blob/master/CONTRIBUTING.md)
- [Maintainer Guideline](https://github.com/microsoft/vcpkg-docs/blob/main/vcpkg/contributing/maintainer-guide.md)

Currently, the following scripts are used to maintain [ports/](../ports/) and [versions/](../versions/) folder.

- [scripts/registry-format.ps1](../scripts/registry-format.ps1)
- [scripts/registry-add-version.ps1](../scripts/registry-add-version.ps1)

### Updating a ports

Here are the steps to update a port in the vcpkg registry with **explicit Git checkpoints**.

#### Step 1: Modify [Port Files](../ports/)
- Change the vcpkg.json file of the port (update version)
- Change the portfile.cmake (update `REF` and `SHA512` values)
- Run the port install test (`vcpkg install <port-name>`)
- If the install failed, check the configure/build/install logs and create patches

>
> [!NOTE]
>
> The Microsoft/vcpkg upstream tries to reduce the patch by suggesting the Pull Requests to the ports' projects.(See guideline references above.)  
> However, in this repository, we prefer adopting later versions of build toolchains, rather than providing a correct changes.  
> If there is no existing(and helpful) issues & pull requests in the upstream, we will create a patches.  
> When the patched port can be used without big issues, then we will consider reporting to the project and making a Pull Request with the patches.
>

#### Step 2: Format The Changed [Port Files](../ports/) (Required)

- Run formatting script to ensure consistent JSON formatting

```ps1
./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
```

#### **GIT CHECKPOINT 1**: Commit Port Changes

```ps1
git add ./ports/<port-name>/
git commit -m "[<port-name>] use X.Y.Z" -m "- <link to release or commit URL>"
```

#### Step 3: Update Baseline and Version Files

- Update registry baseline and version tracking files

```ps1
./scripts/registry-add-version.ps1 -PortName "<port-name>" -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
```

#### **GIT CHECKPOINT 2**: Commit [versions/](../versions/) changes
```ps1
git add ./versions/
git commit -m "[<port-name>] update baseline and version files for X.Y.Z"
```

>
> [!NOTE]
>
> Fresh git repo state is required by vcpkg tool, so always commit port changes before running registry-add-version.ps1
>

#### Note: Calculating SHA512 for New Versions

When updating to a new version, you need to calculate the `SHA512` hash:

```ps1
# Download the source archive
$Version = "X.Y.Z"
$Url = "https://github.com/OWNER/REPO/archive/v${Version}.tar.gz"
curl -L -o "temp-${Version}.tar.gz" $Url

# Calculate SHA512 (use lowercase for vcpkg)
$Hash = (Get-FileHash -Algorithm SHA512 "temp-${Version}.tar.gz").Hash.ToLower()
Write-Host "SHA512: $Hash"

# Clean up
Remove-Item "temp-${Version}.tar.gz"
```

If the hash calculation can't be done in the current Shell environment,
use `0` for the `SHA512` value in the portfile.cmake.
By running the `vcpkg install` command with the change, vcpkg tool will report the calculated `SHA512` value with its output message.

#### Example

Suppose we are updating the [`openssl3` port](../ports/openssl3/).

```ps1
Push-Location "C:/vcpkg-registry"
  $RegistryRoot = Get-Location
  $PortName = "openssl3"  # Replace with your port name
  
  # ... Suppose we edited files under ports/openssl3/ ...
  
  # Step 1: Test the port installation
  vcpkg install --overlay-ports="ports" --triplet=x64-windows $PortName
    
  # Step 2: Format all vcpkg.json files (optional but recommended)
  ./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$RegistryRoot"

  # GIT CHECKPOINT 1: Commit port changes
  git add ./ports/$PortName/
  git commit -m "[$PortName] update to version X.Y.Z"

  # Step 3: Update the baseline and version files
  # This should be done after commit. Fresh git repo state is required by vcpkg tool
  ./scripts/registry-add-version.ps1 -PortName $PortName -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$RegistryRoot"
  
  # GIT CHECKPOINT 3: Commit version files
  git add ./versions/
  git commit -m "[$PortName] update baseline and version files"
Pop-Location
```

### Testing a port

Mostly, the port's default installation works, it is enough.
However, if the port has some features, and they are important. We have to test install with the features repetitively.

1. Run `vcpkg install` command with the port name. Here, the installation needs to be "overlay install"(`--x-overlay-ports`) to prevent mix/conflict with vcpkg upstream.
2. Use `vcpkg search` command to list the port's features.
3. If there is no feature, the port is tested.
4. If there are some features, run `vcpkg install` command with each of the features.
