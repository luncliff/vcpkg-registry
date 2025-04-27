# vcpkg-registry

[![Build Status](https://dev.azure.com/luncliff/personal/_apis/build/status/luncliff.vcpkg-registry?branchName=main)](https://dev.azure.com/luncliff/personal/_build/latest?definitionId=52&branchName=main)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/luncliff/vcpkg-registry/tree/main.svg?style=shield)](https://dl.circleci.com/status-badge/redirect/gh/luncliff/vcpkg-registry/tree/main)
[![Check](https://github.com/luncliff/vcpkg-registry/actions/workflows/build.yml/badge.svg)](https://github.com/luncliff/vcpkg-registry/actions/workflows/build.yml)

Targets...

* [vcpkg](https://github.com/microsoft/vcpkg): recommend [2024.06.15](https://github.com/microsoft/vcpkg/releases/tag/2024.06.15) or later
* [vcpkg-tool](https://github.com/microsoft/vcpkg-tool) follows the vcpkg

### [References](docs/references.md)

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

### Setup

```console
user@host:~$ git clone https://github.com/microsoft/vcpkg
...
user@host:~$ pushd ./vcpkg/
~/vcpkg ~
user@host:~/vcpkg$ git clone https://github.com/luncliff/vcpkg-registry registry
...
```

Don't forget to check [the vcpkg environment variables](https://github.com/microsoft/vcpkg/blob/master/docs/users/config-environment.md) are correct.

The overall file organization is like the following.

```console
user@host:~/vcpkg$ tree -L 2 ./registry/
./registry/
├── LICENSE
├── README.md
├── azure-pipelines.yml
├── versions
│   ├── ...
│   └── baseline.json
├── ports
│   ├── ...
│   ├── directml
│   ├── libdispatch
│   ├── openssl3
│   └── tensorflow-lite
└── triplets
    ├── arm64-android.cmake
    ├── x64-android.cmake
    ├── x64-linux.cmake
    ├── arm64-ios-simulator.cmake
    └── x64-ios-simulator.cmake
```

#### For Registry

For registry customization, configure your [vcpkg-configuration.json](https://github.com/microsoft/vcpkg/blob/master/docs/specifications/registries.md).

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
    "default-registry": {
        "kind": "git",
        "repository": "https://github.com/Microsoft/vcpkg",
        "baseline": "0000..."
    },
    "registries": [
        {
            "kind": "git",
            "repository": "https://github.com/luncliff/vcpkg-registry",
            "packages": [
                "openssl3",
                "tensorflow-lite"
            ],
            "baseline": "0000..."
        }
    ]
}
```

### Install

#### with Ports (Overlay)

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

#### with Triplets (Overlay)

```console
user@host:~/vcpkg$ ./vcpkg install --overlay-triplets="registry/triplets" --triplet x64-ios-simulator zlib-ng
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

##### 1. Android

* `arm64-android`
* `arm-android`
* `x64-android`

Check [Vcpkg and Android](https://learn.microsoft.com/en-us/vcpkg/users/platforms/android) for more detailed usage.

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

#### with Registry

Provide the feature flags to install with registry informations in `vcpkg-configuration.json`.

```console
user@host:~/vcpkg$ ./vcpkg install --feature-flags=registries openssl3
Computing installation plan...
...
```

After the installation, you can `list` the packages.

```console
user@host:~/vcpkg$ ./vcpkg list openssl3
...
```

## License

The work is for the community.  
[CC0 1.0 Public Domain](https://creativecommons.org/publicdomain/zero/1.0/deed.ko) for all files.

However, the repository is holding [The Unlicense](https://unlicense.org) for possible future, software related works.
Especially for nested source files, not the distributed source files of the other projects.
