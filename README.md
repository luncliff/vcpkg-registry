# vcpkg-registry

[![Build Status](https://dev.azure.com/luncliff/personal/_apis/build/status/luncliff.vcpkg-registry?branchName=main)](https://dev.azure.com/luncliff/personal/_build/latest?definitionId=52&branchName=main)

Targets...

* [vcpkg](https://github.com/microsoft/vcpkg): `master` branch, [2021/11/06](https://github.com/microsoft/vcpkg/tree/1ab6c8c7fa1b6971d1e0dc14e2510801d515fde0) or later
* [vcpkg-tool](https://github.com/microsoft/vcpkg-tool): [`2021-11-02`](https://github.com/microsoft/vcpkg-tool/releases/tag/2021-11-02) or later

### References

* https://devblogs.microsoft.com/cppblog/registries-bring-your-own-libraries-to-vcpkg/
* https://github.com/microsoft/vcpkg/blob/master/docs/specifications/ports-overlay.md
* https://github.com/microsoft/vcpkg/blob/master/docs/specifications/registries.md
* https://github.com/northwindtraders/vcpkg-registry
* https://github.com/microsoft/vcpkg-tool

## How To

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
├── LICENSE
├── README.md
├── azure
│   ├── ...
│   └── jobs-windows.yml
├── azure-pipelines.yml
├── ports
│   ├── ...
│   ├── libdispatch
│   ├── libtorch
│   ├── openssl3
│   ├── tensorflow-lite
│   ├── vcpkg-host-python3
│   └── zlib-ng
├── scripts
│   ├── ...
│   └── FindQtANGLE.cmake
├── tests
│   └── CMakeLists.txt
└── triplets
    ├── arm-android.cmake
    ├── arm64-android.cmake
    ├── arm64-ios-simulator.cmake
    ├── x64-android.cmake
    └── x64-ios-simulator.cmake
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

Sould be like the following. Notice that this repo contains `openssl3` and `tensorflow-lite`, but the configuration is specifying only `tensorflow-lite`.

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

### Install

#### with Ports

```console
user@host:~/vcpkg$ ./vcpkg help install
...
Options:
...
  --overlay-ports=<path>          Specify directories to be used when searching for ports
                                  (also: $VCPKG_OVERLAY_PORTS)
...
```

#### with Triplets

```console
user@host:~/vcpkg$ ./vcpkg help install
...
Options:
...
  --overlay-triplets=<path>       Specify directories containing triplets files
                                  (also: $VCPKG_OVERLAY_TRIPLETS)
...
```

##### 1. Android

* `arm64-android`
* `arm-android`
* `x64-android`

Check [Vcpkg and Android](https://github.com/microsoft/vcpkg/blob/master/docs/users/android.md) for more detailed usage.

The triplets help 
```console
user@host:~/vcpkg$ export ANDROID_NDK_HOME="/.../Library/Android/sdk/ndk/23.0.7599858/"
user@host:~/vcpkg$ ./vcpkg install --overlay-triplets=./registry/triplets vulkan:arm64-android
Starting package 1/1: vulkan:arm64-android
Building package vulkan[core]:arm64-android...
-- [OVERLAY] Loading triplet configuration from: /.../Desktop/vcpkg/vcpkg-registry/triplets/arm64-android.cmake
-- Using NDK_HOST_TAG: darwin-x86_64
-- Using NDK_API_LEVEL: 24
-- Found NDK: 23.0.7599858 (23.0)
-- Using ENV{VULKAN_SDK}: /.../Library/Android/sdk/ndk/23.0.7599858/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr
-- Found libvulkan.so: /.../Library/Android/sdk/ndk/23.0.7599858/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/x86_64-linux-android/24/libvulkan.so
-- 
-- Querying VULKAN_SDK Enviroment variable
-- Searching /.../Library/Android/sdk/ndk/23.0.7599858/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include/vulkan/ for vulkan.h
-- Found vulkan.h
-- Performing post-build validation
-- Performing post-build validation done
```

##### 2. iOS Simulator

* `arm64-ios-simulator`
* `x64-ios-simulator`

These triplets acquire `VCPKG_OSX_SYSROOT` for iOS Simulator SDK. Also, specifies C/C++ flags minimum SDK version to iOS 11.0 if `VCPKG_CMAKE_SYSTEM_VERSION` is not provided.

These triplets won't do much work. I recommend you to use https://github.com/leetal/ios-cmake with [`VCPKG_CHAINLOAD_TOOLCHAIN_FILE`](https://github.com/microsoft/vcpkg/blob/master/docs/users/triplets.md#vcpkg_chainload_toolchain_file).

#### ~~with Registry~~

> This part will be updated later. Currently not supported.

Provide the feature flags to install with registry informations in `vcpkg-configuration.json`.

```console
user@host:~/vcpkg$ ./vcpkg install lua --feature-flags=registries
Computing installation plan...
The following packages will be built and installed:
    lua[core]:x64-osx -> 5.3.5#6 -- /.../.cache/vcpkg/registries/git-trees/80fa373569847b12eeae2f949d922a6d7330767f
Detecting compiler hash for triplet x64-osx...
Could not locate cached archive: /.../.cache/vcpkg/archives/1a/1a78479217231fdfb06605d33607532000273de1.zip
Starting package 1/1: lua:x64-osx
```

After the installation, you can `list` the packages.

```console
user@host:~/vcpkg$ ./vcpkg list lua
lua:x64-osx       5.3.5#6          ...
```

## License

The work is for the community.  
[CC0 1.0 Public Domain](https://creativecommons.org/publicdomain/zero/1.0/deed.ko) for all files.

However, the repository is holding [The Unlicense](https://unlicense.org) for possible future, software related works.
Especially for nested source files, not the distributed source files of the other projects.
