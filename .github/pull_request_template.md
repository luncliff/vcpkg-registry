
### Info

* Project: [Boost 1.77.0(sample)](https://www.boost.org/users/history/version_1_77_0.html)
* 2021/08/11 ~ 2021/12/08 (Next Version: "1.78.0")

### Triplets

* `x64-windows`
* ...

```bash
# In Bash
vcpkg install --overlay-triplets ./vcpkg-registry/triplets/ --overlay-ports ./vcpkg-registry/ports/ \
    ${port}:${triplet} 
```

```ps1
# In PowerShell 7+
vcpkg install --overlay-triplets ./vcpkg-registry/triplets/ --overlay-ports ./vcpkg-registry/ports/ `
    $port:$triplet 
```
### Configuration

"vcpkg-configuration.json" changes for the release.

```json
{
    "registries": [
        {
            "kind": "git",
            "repository": "https://github.com/luncliff/vcpkg-registry",
            "packages": [
                "boost",
                "boost-asio"
            ],
            "baseline": "..."
        }
    ]
}
```
