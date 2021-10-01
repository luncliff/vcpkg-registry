#[===[.md:
# vcpkg-host-python3

The port installs some CMake scripts which helps to install Python3 packages from PIP.
It works with CMake module [FindPython3](https://cmake.org/cmake/help/latest/module/FindPython3.html).

Requires CMake 3.19+

### See Also

* https://cmake.org/cmake/help/latest/module/FindPython3.html
* vcpkg_pip_install.cmake

#]===]
set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

include(${CURRENT_PORT_DIR}/vcpkg-port-config.cmake)
vcpkg_pip_install(PACKAGE "typing-extensions")

file(INSTALL     ${CURRENT_PORT_DIR}/LICENSE
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)
file(INSTALL     ${CURRENT_PORT_DIR}/vcpkg-port-config.cmake
                 ${CURRENT_PORT_DIR}/vcpkg_pip_install.cmake
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT}
)
