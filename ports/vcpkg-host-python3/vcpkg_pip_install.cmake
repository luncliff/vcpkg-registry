#[===[.md:
# vcpkg_pip_install

### Description

Allows several arguments like the following.

```cmake
vcpkg_pip_install(PACKAGE "pyyaml")
vcpkg_pip_install(PACKAGE "numpy"
                  INSTALL_OPTIONS --user --quiet)
```

The function is for CMake script mode.

#### Required

##### PACKAGE

The name of the package for `pip install ...`

#### Optional

##### INSTALL_OPTIONS

The CLI argument for `pip install ${package} ...`.
Check `pip install --help` for available options.

### Supports

Some packages are known and will define reserved variables.
The variables are forwarded using `PARNET_SCOPE`, without cache usage.

```cmake
# ...
if(arg_PACKAGE STREQUAL "...")
    set(RESERVED_NAME ${RESERVED_VALUE} PARENT_SCOPE)
endif()
```

#### numpy

* `Python3_NumPy_INCLUDE_DIRS`: from `find_package(Python3 NumPy)`

#### pybind11

* `pybind11_DIR`: Possible path for `find_package(pybind11 CONFIG)`

### See Also

* https://pip.pypa.io/en/stable/cli/pip_install/
* https://cmake.org/cmake/help/latest/module/FindPython3.html
* https://cmake.org/cmake/help/latest/command/execute_process.html
* https://cmake.org/cmake/help/latest/command/find_package.html

#]===]
if(Z_VCPKG_PIP_INSTALL_GUARD)
    return()
endif()
set(Z_VCPKG_PIP_INSTALL_GUARD ON CACHE INTERNAL "guard variable for 'vcpkg_pip_install'")

# todo:
#   - parse version from successful output
#   - install option `--root`, `--prefix`
#   - message for `--system` or `--build` pacakges
function(vcpkg_pip_install)
    cmake_parse_arguments(PARSE_ARGV 0 "arg" "" "PACKAGE" "INSTALL_OPTIONS")
    if(NOT DEFINED Python3_EXECUTABLE)
        message(FATAL_ERROR "Undefined: Python3_EXECUTABLE")
    endif()
    if(DEFINED arg_PACKAGE)
        message(VERBOSE "package: ${arg_PACKAGE}")
    endif()
    if(DEFINED arg_INSTALL_OPTIONS)
        message(VERBOSE "install_options:")
        foreach(OPTION IN LISTS arg_INSTALL_OPTIONS)
            message(VERBOSE "  ${OPTION}")
        endforeach()
    endif()

    # run `pip install ${package}`
    execute_process(
        COMMAND ${Python3_EXECUTABLE} -m pip install ${arg_PACKAGE} ${arg_INSTALL_OPTIONS}
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}
        OUTPUT_FILE install-${arg_PACKAGE}-out.log
        ERROR_FILE  install-${arg_PACKAGE}-err.log
        RESULT_VARIABLE INSTALL_RETURN_CODE
        COMMAND_ECHO NONE
        ENCODING UTF-8
    )
    if(INSTALL_RETURN_CODE) # non-zero means failure
        message(FATAL_ERROR "PIP install failed. Check ${CURRENT_BUILDTREES_DIR}/install-${arg_PACKAGE}-err.log")
    endif()

    # if 'numpy', find NumPy component
    if(arg_PACKAGE MATCHES [Nn]um[Pp]y)
        get_filename_component(Python3_NumPy_INCLUDE_DIR "${PY3_LIBRARY_ROOT_DIR}/numpy/core/include"   ABSOLUTE)
        # run find_package and forward result variables with PARENT_SCOPE
        find_package(Python3 QUIET REQUIRED COMPONENTS NumPy)
        message(VERBOSE "numpy: ${Python3_NumPy_VERSION}")
        message(VERBOSE "  include: ${Python3_NumPy_INCLUDE_DIRS}")
        if(TARGET Python3::NumPy)
            message(VERBOSE "  target: true")
        endif()
        set(Python3_NumPy_INCLUDE_DIRS ${Python3_NumPy_INCLUDE_DIRS} PARENT_SCOPE)
    endif()
    # if 'pybind11', find pybind11
    if(arg_PACKAGE STREQUAL pybind11)
        get_filename_component(pybind11_DIR "${PY3_LIBRARY_ROOT_DIR}/pybind11/share/cmake"   ABSOLUTE)
        # note: pybind11 can't be found in script mode.
        # find_package(pybind11 CONFIG
        #     PATHS "${PY3_LIBRARY_ROOT_DIR}/pybind11/share/cmake"
        # )
        # message(VERBOSE "pybind11: ${pybind11_VERSION}")
        # message(VERBOSE "  includes: ${pybind11_INCLUDE_DIR}")
        # message(VERBOSE "  defines: ${pybind11_DEFINITIONS}")
        # message(VERBOSE "  libs: ${pybind11_LIBRARIES}")
        message(VERBOSE "pybind11:")
        message(VERBOSE "  dir: ${pybind11_DIR}")
        set(pybind11_DIR ${pybind11_DIR} PARENT_SCOPE)
    endif()
endfunction()
