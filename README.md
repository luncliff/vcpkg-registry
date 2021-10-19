# vcpkg-registry

[![Build Status](https://dev.azure.com/luncliff/personal/_apis/build/status/luncliff.vcpkg-registry?branchName=main)](https://dev.azure.com/luncliff/personal/_build/latest?definitionId=52&branchName=main)

Targets...

* [vcpkg](https://github.com/microsoft/vcpkg): `master` branch, 2021/10 or later
* [vcpkg-tool](https://github.com/microsoft/vcpkg-tool): [`2021-09-10`](https://github.com/microsoft/vcpkg-tool/tree/2021-09-10) or later

### References

* https://devblogs.microsoft.com/cppblog/registries-bring-your-own-libraries-to-vcpkg/
* https://github.com/microsoft/vcpkg/blob/master/docs/specifications/ports-overlay.md
* https://github.com/microsoft/vcpkg/blob/master/docs/specifications/registries.md
* https://github.com/northwindtraders/vcpkg-registry
* https://github.com/microsoft/vcpkg-tool

## How To

Run the help command for the description

```console
user@host:~/vcpkg$ ./vcpkg help install
Example:
  vcpkg install zlib zlib:x64-windows curl boost

Options:
...
  --overlay-ports=<path>          Specify directories to be used when searching for ports
                                  (also: $VCPKG_OVERLAY_PORTS)
...
```

### Setup

Currently stopped supporting registry feature support.
It is planned, but not today. It will be supported when this repo gets another Git tag.

```console
user@host:~$ git clone https://github.com/microsoft/vcpkg
...
user@host:~$ pushd ./vcpkg/
~/vcpkg ~
user@host:~/vcpkg$ git clone https://github.com/luncliff/vcpkg-registry registry
...
user@host:~/vcpkg$ tree -L 2 ./registry/
./registry/
.
├── README.md
├── azure-pipelines.yml
├── ports
│   ├── ...
│   └── ...
├── scripts
│   └── FindQtANGLE.cmake
├── tests
│   └── CMakeLists.txt
└── triplets
    ├── ...
    └── ...
```

### Search

#### with Overlay

Just provide the path of `port/` folder. 

```console
user@host:~/vcpkg$ ./vcpkg search --overlay-ports=registry/ports cpuinfo
```

#### ~~with Registry~~

For registry customization, configure your [vcpkg-configuration.json](https://github.com/microsoft/vcpkg/blob/master/docs/specifications/registries.md).

```console
user@host:~/vcpkg$ cat ./vcpkg-configuration.json | jq
{
  "registries": [
...
```

Sould be like the following. Notice that this repo contains `nsync` and `lua`, but the configuration is specifying only `lua`.

```json
{
    "registries": [
        {
            "kind": "git",
            "repository": "https://github.com/luncliff/vcpkg-registry",
            "packages": [
                "tensorflow-lite"
            ],
            "baseline": "0000..."
        }
    ]
}
```

##### Cache location for Linux/Mac

There are cache files under `/Users/$(whoami)/.cache/vcpkg/registries`.

### Install

#### ~~with Triplets~~

> Redesign of Android triplets are in progress...

Currently there are 4 triplets for each of Android architectures. Check https://github.com/microsoft/vcpkg/blob/master/docs/users/android.md for their roles.

```console
user@host:~/vcpkg$ ./vcpkg install vulkan:arm64-android --overlay-triplets=registry/triplets
...
Starting package 1/1: vulkan:arm64-android
Building package vulkan[core]:arm64-android...
-- [OVERLAY] Loading triplet configuration from: /Users/user/dev/vcpkg/registry/triplets/arm64-android.cmake
-- Using NDK_HOST_TAG: darwin-x86_64
-- Using NDK_DIR_NAME: 23.0.7196353
-- Using ENV{VULKAN_SDK}: /Users/user/Library/Android/sdk/ndk/23.0.7196353/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr
-- 
-- Querying VULKAN_SDK Enviroment variable
```

#### with Overlay

Remove the port from the default registry.  
For example, remove the `nsync` related things under `versions/` folder, then try the install without any options.

```console
user@host:~/vcpkg$ ./vcpkg install nsync
Computing installation plan...
Error: while loading port `nsync`: Port definition not found
```

However, by providing port search folder ...

```console
user@host:~/vcpkg$ ./vcpkg install nsync --overlay-ports=registry/ports
Computing installation plan...
The following packages will be built and installed:
    nsync[core]:x64-osx -> 1.24.0 -- /Users/user/vcpkg/registry/ports/nsync
...
```

#### ~~with Registry~~

> This part will be updated later. Currently not supported.

Provide the feature flags to install with registry informations in `vcpkg-configuration.json`.

```console
user@host:~/vcpkg$ ./vcpkg install lua --feature-flags=registries
Computing installation plan...
The following packages will be built and installed:
    lua[core]:x64-osx -> 5.3.5#6 -- /Users/user/.cache/vcpkg/registries/git-trees/80fa373569847b12eeae2f949d922a6d7330767f
Detecting compiler hash for triplet x64-osx...
Could not locate cached archive: /Users/user/.cache/vcpkg/archives/1a/1a78479217231fdfb06605d33607532000273de1.zip
Starting package 1/1: lua:x64-osx
```

After the installation, you can `list` the packages.

```console
user@host:~/vcpkg$ ./vcpkg list lua
lua:x64-osx       5.3.5#6          ...
```
