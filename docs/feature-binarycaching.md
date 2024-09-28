# Binary Caching 기능 설명

* [What is binary caching?](https://learn.microsoft.com/en-us/vcpkg/consume/binary-caching-overview)

환경변수를 사용해 기능을 활성화 하는 방법

=== "PowerShell"
    ```ps1
    $env:VCPKG_FEATURE_FLAGS="binarycaching"
    ```
=== "Bash"
    ```bash
    export VCPKG_FEATURE_FLAGS="binarycaching"
    ```

## vcpkg-tool 소스코드

* https://github.com/microsoft/vcpkg-tool/blob/main/src/vcpkg/binarycaching.cpp

...

## ABI Hash 계산

* https://learn.microsoft.com/en-us/vcpkg/reference/binarycaching#abi-hash

## `VCPKG_BINARY_SOURCES` 예시

* [Configuration Syntax](https://learn.microsoft.com/en-us/vcpkg/reference/binarycaching#configuration-syntax)

문서 상으로는 `[,rw]` 라고 표기하고 있는데 실제로는 `readwrite`로 작성해야 동작...

여러 Source를 같이 사용하는 경우, `;`를 사용해 구분

```ps1
$env:VCPKG_AWS_SOURCE="..."
$env:VCPKG_AZURE_SOURCE="..."
$env:VCPKG_BINARY_SOURCES="defaukt;$env:VCPKG_AWS_SOURCE;$env:VCPKG_AZURE_SOURCE"
```

### File

```ps1
$DiskPath="D:/vcpkg-caches"
$env:VCPKG_BINARY_SOURCES="files,$DiskPath,readwrite"
```

### NuGet

* [`nuget.config` reference](https://learn.microsoft.com/en-us/nuget/reference/nuget-config-file)
* [NuGet CLI reference](https://learn.microsoft.com/en-us/nuget/reference/nuget-exe-cli-reference)
* [Common NuGet configurations](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior)

NuGet config 파일이 필요할 수 있음

```ps1
# If the repository is private ...
$NugetConfigPath="D:/nuget-config.xml"
$env:VCPKG_BINARY_SOURCES="nuget,https://nexus.instance.com/repositories/nuget,readwrite;nugetconfig,$NugetConfigPath"
```

```xml
<configuration>
    <!-- apikeys -->
    <!-- packageSources -->
    <!-- packageSourceCredentials -->
</configuration>
```

### AWS S3

* [AWS CLI Command Reference: S3](https://docs.aws.amazon.com/cli/latest/reference/s3/)

```ps1
$BucketName="..."

$env:VCPKG_BINARY_SOURCES="x-aws,s3://$BucketName/,readwrite"
```

```ps1
$BucketName="..."
$FolderName="vcpkg-caches"

$env:VCPKG_BINARY_SOURCES="x-aws,s3://$BucketName/$FolderName/,readwrite"
```

### Azure Blob Storage

* [Create SAS tokens for your storage containers](https://learn.microsoft.com/en-us/azure/ai-services/translator/document-translation/how-to-guides/create-sas-tokens)

```ps1
$BlobStorageName="..."
$BlobStorageFolder="vcpkg-caches"
$BlobStorageSAS="sv=...&se=...&st=...&sig=..."

$env:VCPKG_BINARY_SOURCES="x-azblob,https://$BlobStorageName.blob.core.windows.net/$BlobStorageFolder,$BlobStorageSAS,readwrite"
```
