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
user@host:~/vcpkg$ tree -L 1 ./registry
./registry
├── README.md
├── ports
└── versions

2 directories, 1 file
```

Then bootstrap the [vcpkg-tool](https://github.com/microsoft/vcpkg-tool).

```console
user@host:~/vcpkg$ ./bootstrap-vcpkg.sh
...
```

### Use

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

#### Search

```console
user@host:~/vcpkg$ ./vcpkg search nsync --overlay-ports=registry/ports
nsync                1.24.0           ...
```

#### Install

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
