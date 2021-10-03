#[===[.md:
# vcpkg_pip_install_requirement

### Description

```cmake
vcpkg_pip_install_requirement(
    FOLDER    ${SOURCE_PATH}
    FILENAME  requirements.txt
)
```

The function is for CMake script mode. 

#### Required

##### FOLDER

A folder to where "requirements.txt" is located.

#### Optional

##### FILENAME

The CLI argument for `pip install --requirement ${filename}`.

### See Also

* https://pip.pypa.io/en/stable/cli/pip_install/
* https://cmake.org/cmake/help/latest/command/execute_process.html
* https://cmake.org/cmake/help/latest/command/find_file.html

#]===]
if(Z_VCPKG_PIP_INSTALL_REQUIREMENT_GUARD)
    return()
endif()
set(Z_VCPKG_PIP_INSTALL_REQUIREMENT_GUARD ON CACHE INTERNAL "guard variable for 'vcpkg_pip_install_requirement'")

function(vcpkg_pip_install_requirement)
    cmake_parse_arguments(PARSE_ARGV 0 "arg" "" "FOLDER" "FILENAME")
    if(NOT DEFINED Python3_EXECUTABLE)
        message(FATAL_ERROR "Undefined: Python3_EXECUTABLE")
    endif()
    if(DEFINED arg_FOLDER)
        message(VERBOSE "folder: ${arg_FOLDER}")
    endif()
    if(NOT DEFINED arg_FILENAME)
        set(arg_FILENAME "requirements.txt")
    else()
        message(VERBOSE "requirements.txt: ${arg_FILENAME}")
    endif()
    get_filename_component(REQUIREMENTS_PATH ${arg_FOLDER}/${arg_FILENAME} ABSOLUTE)

    # run `pip install --requirement requirements.txt`
    execute_process(
        COMMAND ${Python3_EXECUTABLE} -m pip install --requirement ${REQUIREMENTS_PATH}
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}
        OUTPUT_FILE install-requirements-out.log
        ERROR_FILE  install-requirements-err.log
        RESULT_VARIABLE INSTALL_RETURN_CODE
        COMMAND_ECHO NONE
        ENCODING UTF-8
    )
    if(INSTALL_RETURN_CODE) # non-zero means failure
        message(FATAL_ERROR "PIP install failed. Check ${CURRENT_BUILDTREES_DIR}/install-requrements-err.log")
    endif()
endfunction()
