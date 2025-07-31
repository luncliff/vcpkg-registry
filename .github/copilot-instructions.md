
# GitHub Copilot Instructions for vcpkg package manager

Create a work-note.md file to record the references and progress logs in Agent mode.
[The work-note.md file won't be added in the commit.](../.gitignore)

## [References](../docs/references.md)

### Official Documentation

- [Vcpkg Documentation](https://learn.microsoft.com/en-us/vcpkg/)
  - [Getting Started Guide](https://learn.microsoft.com/en-us/vcpkg/get_started/get-started)
  - [Using Git-based Registries](https://learn.microsoft.com/en-us/vcpkg/consume/git-registries)
  - [Creating Registries](https://learn.microsoft.com/en-us/vcpkg/maintainers/registries)
  - [Concepts: Triplets](https://learn.microsoft.com/en-us/vcpkg/concepts/triplets)
  - [Concepts: Overlay Ports](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports)
  - [Example: Overlay Triplets](https://learn.microsoft.com/en-us/vcpkg/users/examples/overlay-triplets-linux-dynamic)

### GitHub Resources

- [microsoft/vcpkg-tool](https://github.com/microsoft/vcpkg-tool/releases)
  - [Documentation](https://github.com/microsoft/vcpkg-tool/tree/main/docs)
  - JSON Schema Files
    - [vcpkg-configuration.schema.json](https://github.com/microsoft/vcpkg-tool/raw/refs/heads/main/docs/vcpkg-configuration.schema.json)
    - [vcpkg-tools.schema.json](https://github.com/microsoft/vcpkg-tool/raw/refs/heads/main/docs/vcpkg-tools.schema.json)
    - [vcpkg.schema.json](https://github.com/microsoft/vcpkg-tool/raw/refs/heads/main/docs/vcpkg.schema.json)
- [microsoft/vcpkg](https://github.com/microsoft/vcpkg/releases)
  - [Discussions](https://github.com/microsoft/vcpkg/discussions)
  - [CMake Scripts](https://github.com/microsoft/vcpkg/tree/master/scripts/cmake)
- [Topic: vcpkg-registry](https://github.com/topics/vcpkg-registry)

### Community and Blogs

- [Microsoft C++ Team Blog](https://devblogs.microsoft.com/cppblog/)
  - [How to Start Using Registries with Vcpkg](https://devblogs.microsoft.com/cppblog/how-to-start-using-registries-with-vcpkg/)
  - [Registries: Bring Your Own Libraries to Vcpkg](https://devblogs.microsoft.com/cppblog/registries-bring-your-own-libraries-to-vcpkg/)

### Tools and Configuration

- [Vcpkg Configuration JSON](https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json)
- [CMake Dependency Management](https://cmake.org/cmake/help/latest/guide/using-dependencies/index.html)
  - [Dependency Providers](https://cmake.org/cmake/help/latest/command/cmake_language.html#dependency-providers)
- [CMake Toolchains](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html)

### Troubleshooting and Advanced Topics

- [MSVC Compiler Options](https://learn.microsoft.com/en-us/cpp/build/reference/compiler-options)
- [LINK.exe Options](https://learn.microsoft.com/en-us/cpp/build/reference/linker-options)
- [Clang Compiler User Manual](https://clang.llvm.org/docs/UsersManual.html)
- [Clang Command Line Argument Reference](https://clang.llvm.org/docs/ClangCommandLineReference.html)
- [Android Support](https://learn.microsoft.com/en-us/vcpkg/users/platforms/android)

## How To

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

### Troubleshooting Port Installation Errors

When encountering compiler or linker errors, refer the following links

- https://learn.microsoft.com/en-us/cpp/build/reference/compiler-options
- https://learn.microsoft.com/en-us/cpp/build/reference/linker-options

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
