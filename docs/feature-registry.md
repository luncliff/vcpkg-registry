# Registry 기능 설명

* [Using registries](https://learn.microsoft.com/en-us/vcpkg/consume/git-registries)
* [Creating registries](https://learn.microsoft.com/en-us/vcpkg/maintainers/registries)

환경변수를 사용해 기능을 활성화 하는 방법

=== "PowerShell"
    ```ps1
    $env:VCPKG_FEATURE_FLAGS="registries"
    ```
=== "Bash"
    ```bash
    export VCPKG_FEATURE_FLAGS="registries"
    ```
