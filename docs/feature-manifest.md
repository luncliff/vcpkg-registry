# Manifest 기능 설명

* [What is manifest mode?](https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode)
* [vcpkg-configuration.json Reference](https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json)

환경변수를 사용해 기능을 활성화 하는 방법

=== "PowerShell"
    ```ps1
    $env:VCPKG_FEATURE_FLAGS="manifests"
    ```
=== "Bash"
    ```bash
    export VCPKG_FEATURE_FLAGS="manifests"
    ```
