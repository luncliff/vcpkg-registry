---
title: "Syntax Coloring Examples"
---

This page is a placeholder to test code highlighting.

## C++

```cpp
#include <string>
#include <vector>

int main() {
    std::vector<std::string> items = {"vcpkg", "triplet", "overlay"};
    return static_cast<int>(items.size());
}
```

## CMake

```cmake
cmake_minimum_required(VERSION 3.20)
project(example LANGUAGES CXX)

find_package(zlib CONFIG REQUIRED)
add_executable(main main.cpp)
target_link_libraries(main PRIVATE ZLIB::ZLIB)
```

## JSON (vcpkg.json)

```json
{
  "name": "example",
  "version": "1.0.0",
  "dependencies": [
    "zlib"
  ]
}
```

## PowerShell

```powershell
$env:VCPKG_ROOT = "C:\\vcpkg"
vcpkg install zlib --overlay-ports .\\ports
```

## Bash

```bash
export VCPKG_ROOT="$HOME/vcpkg"
vcpkg install zlib --overlay-ports ./ports
```
