# vcpkg-registry

### References

* https://vcpkg.readthedocs.io/en/latest/specifications/registries/
* https://devblogs.microsoft.com/cppblog/registries-bring-your-own-libraries-to-vcpkg/

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

Then bootstrap the [vcpkg-tool](https://github.com/microsoft/vcpkg-tool).

```console
user@host:~/vcpkg$ ./bootstrap-vcpkg.sh
...
```

### Use

```console
user@host:~/vcpkg$ ./vcpkg search nsync --overlay-ports=registry/ports
nsync                1.24.0           ...
```
