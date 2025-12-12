# vcpkg-registry

[![Check](https://github.com/luncliff/vcpkg-registry/actions/workflows/build.yml/badge.svg)](https://github.com/luncliff/vcpkg-registry/actions/workflows/build.yml)

* [vcpkg](https://github.com/microsoft/vcpkg): recommend [2024.06.15](https://github.com/microsoft/vcpkg/releases/tag/2024.06.15) or later
* [vcpkg-tool](https://github.com/microsoft/vcpkg-tool) follows the vcpkg

## Documentation

### Guides

- [Port Creation Guide](docs/guide-new-port.md)
- [Port Update Guide](docs/guide-update-port.md)

### Quick [References](docs/references.md)

* Microsoft C++ Team Blog: https://devblogs.microsoft.com/cppblog/
    * https://devblogs.microsoft.com/cppblog/registries-bring-your-own-libraries-to-vcpkg/
    * https://github.com/northwindtraders/vcpkg-registry
* GitHub Topics `vcpkg-registry`: https://github.com/topics/vcpkg-registry
    * Discussions https://github.com/microsoft/vcpkg/discussions
* Vcpkg documentation: https://learn.microsoft.com/en-us/vcpkg/
    * https://learn.microsoft.com/en-us/vcpkg/consume/git-registries
    * https://learn.microsoft.com/en-us/vcpkg/maintainers/registries
* Vcpkg mainstream: https://github.com/microsoft/vcpkg
    * https://github.com/microsoft/vcpkg-tool/releases
* Vcpkg configuration
    * https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json

## How To

### Setup vcpkg

Follow the official [Getting Started Guide](https://learn.microsoft.com/en-us/vcpkg/get_started/get-started) to setup your environment.
Don't forget to check [the vcpkg environment variables](https://github.com/microsoft/vcpkg/blob/master/docs/users/config-environment.md) are correct.

- Required environment variables?
  - `VCPKG_ROOT` to integrate with toolchains. For example, `C:\vcpkg` or `/usr/local/shared/vcpkg`
  - `PATH` to run `vcpkg` CLI program.

Use `vcpkg help` command to get descriptions and test the CLI executable works.  
Commonly used commands can be checked with:

```
vcpkg help install
vcpkg help remove
vcpkg help search
```

### Setup vcpkg-registry

Simply clone the repository and use path for the vcpkg commands.

For example, you can put the registry files just under `VCPKG_ROOT` for easy navigation.

```powershell
$env:VCPKG_ROOT="C:/vcpkg"
Set-Location $env:VCPKG_ROOT
    git clone "https://github.com/luncliff/vcpkg-registry"
Pop-Location
```

```bash
export VCPKG_ROOT="/usr/local/share/vcpkg"
pushd $VCPKG_ROOT
    git clone https://github.com/luncliff/vcpkg-registry
popd
```

#### File Organization

Confirm the files are like our expectation.

```console
user@host:~/vcpkg$ tree -L 2 ./vcpkg-registry/
./vcpkg-registry/
├── docs
│   ├── guide-*.md
│   └── references.md
├── README.md
├── .github
│   ├── workflows/
│   └── prompts/
├── versions
│   ├── ... # files for vcpkg manifest mode
│   └── baseline.json
├── ports
│   ├── ... # files for --overlay-ports
│   ├── openssl3
│   └── tensorflow-lite
└── triplets
    ├── ... # files for --overlay-triplets
    ├── arm64-android.cmake
    └── x64-ios-simulator.cmake
```

### Use vcpkg-registry

Both vcpkg's classic mode and manifest mode are available.

- [classic mode](https://learn.microsoft.com/en-us/vcpkg/concepts/classic-mode): `vcpkg install` with overlay(`--overlay-ports` and `--overlay-triplets`).
- [manifest mode](https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode): use the git repository in vcpkg-configuration.json file.

The vcpkg command may need more detailed options or switches to work properly.

#### with [Overlay Ports](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports) (Classic)

Just provide the path of `port/` folder. 

```console
user@host:~/vcpkg$ ./vcpkg install --overlay-ports="registry/ports" cpuinfo
```

If it doesn't work, check the command options.

```console
user@host:~/vcpkg$ ./vcpkg help install
...
Options:
...
  --overlay-ports=<path>          Specify directories to be used when searching for ports
                                  (also: $VCPKG_OVERLAY_PORTS)
...
```

#### with [Overlay Triplets](https://learn.microsoft.com/en-us/vcpkg/concepts/triplets) (Classic)

The [triplets/](./triplets/) folder contains CMake scripts for Android NDK and iOS Simulator SDK.

You can use envionment variable `VCPKG_OVERLAY_TRIPLETS`, but I recomment you to use `--overlay-triplets` to avoid confusion.

```bash
vcpkg install --overlay-triplets="vcpkg-registry/triplets" --triplet x64-ios-simulator zlib-ng
```

If it doesn't work, check the command options.

```console
user@host:~/vcpkg$ ./vcpkg help install
...
Options:
...
  --overlay-triplets=<path>       Specify directories containing triplets files
                                  (also: $VCPKG_OVERLAY_TRIPLETS)
...
```

For more detailed usage, check the vcpkg documents.
- [Using Overlay Triplets](https://learn.microsoft.com/en-us/vcpkg/users/examples/overlay-triplets-linux-dynamic)
- [Vcpkg and Android](https://learn.microsoft.com/en-us/vcpkg/users/platforms/android)

> [!NOTE]
>
> Triplets won't affect your project's configuration and build.  
> These files are not for [`VCPKG_CHAINLOAD_TOOLCHAIN_FILE`](https://github.com/microsoft/vcpkg/blob/master/docs/users/triplets.md#vcpkg_chainload_toolchain_file).
> 

#### with vcpkg.json (Manifest)

- https://learn.microsoft.com/en-us/vcpkg/consume/git-registries

With the baseline and version JSON files in [versions/](./versions/) folder, you can use 

For registry customization, create your [vcpkg-configuration.json](https://github.com/microsoft/vcpkg/blob/master/docs/specifications/registries.md).

```console
user@host:~/vcpkg$ cat ./vcpkg-configuration.json | jq
{
  "registries": [
...
```

The sample configuration can be like this.
The `ports/` folder contains `openssl3` and `tensorflow-lite`. Put them in the "packages".

```json
{
    "$schema": "https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg-configuration.schema.json",
    "default-registry": {
        "kind": "git",
        "repository": "https://github.com/Microsoft/vcpkg",
        "baseline": "0000..."
    },
    "registries": [
        {
            "kind": "git",
            "repository": "https://github.com/luncliff/vcpkg-registry",
            "baseline": "0000...",
            "packages": [
                "openssl3",
                "tensorflow-lite"
            ]
        }
    ]
}
```

## License

The work is for the community.  
[CC0 1.0 Public Domain](https://creativecommons.org/publicdomain/zero/1.0/deed.ko) for all files.

However, the repository is holding [The Unlicense](https://unlicense.org) for possible future, software related works.
Especially for nested source files, not the distributed source files of the other projects.
