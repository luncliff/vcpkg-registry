#[===[.md:
# vcpkg_pip_install

### See Also

* https://cmake.org/cmake/help/latest/module/FindPython3.html
* https://cmake.org/cmake/help/latest/command/execute_process.html
* https://cmake.org/cmake/help/latest/command/find_package.html

#]===]
if(Z_VCPKG_PIP_INSTALL_GUARD)
    return()
endif()
set(Z_VCPKG_PIP_INSTALL_GUARD ON CACHE INTERNAL "guard variable for 'vcpkg_pip_install'")

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
        COMMAND_ECHO STDOUT
        ENCODING UTF-8
    )

    # if 'numpy', find NumPy component
    if(arg_PACKAGE MATCHES [Nn]um[Pp]y)
        get_filename_component(Python3_NumPy_INCLUDE_DIR "${PY3_LIBRARY_ROOT_DIR}/include"   ABSOLUTE)
        # run find_package and forward result variables with PARENT_SCOPE
        find_package(Python3 REQUIRED COMPONENTS NumPy)
        message(VERBOSE "numpy: ${Python3_NumPy_VERSION}")
        message(VERBOSE "  include: ${Python3_NumPy_INCLUDE_DIRS}")
        set(Python3_NumPy_INCLUDE_DIRS ${Python3_NumPy_INCLUDE_DIRS} PARENT_SCOPE)
    endif()
endfunction()
