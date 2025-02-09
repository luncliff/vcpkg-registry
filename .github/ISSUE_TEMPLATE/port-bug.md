---
name: Port Bug?
about: Report if `vcpkg install` reports build failures, wrong installation, etc
title: 'Port Bug - ...'
labels: bug
assignees: ''

---

Please check the followings to reproduce the failures.

If possible, please attach the logs under `buildtrees/`.

## Vcpkg

### Version of https://github.com/microsoft/vcpkg-tool

Run the CLI tool and check the output messages.

```console
$ ./vcpkg --version
vcpkg package management program version 2025-01-11-0f310537c75015100d200eb71b137f6376aad510                
```

### Commit of https://github.com/microsoft/vcpkg

Where did the error produce?

```console
PS C:\vcpkg> git log -1
commit 0000....
```

### Triplets

If several triplets are related, please list here.

* `arm64-windows`
* `x64-osx`
* ...

## Toolchain

The versions of Build system(IDE), compiler, CMake, etc ...

## References

If there are some related issues, pull requests, documentation?
They will be really helpful to get the detail!
