#[===[.md:
# vcpkg_pip_install

#]===]
function(vcpkg_pip_install)
    cmake_parse_arguments(PARSE_ARGV 0 "arg" "PACKAGE")
    if(DEFINED arg_PACKAGE)
        message(STATUS "requested: ${arg_PACKAGE}")
    endif()
endfunction()
