cmake_minimum_required(VERSION 3.13)
project(farmhash LANGUAGES CXX)
include(GNUInstallDirs)
include(CheckCXXCompilerFlag)

set(CMAKE_CXX_STANDARD 14)

add_library(farmhash
    src/farmhash.h
    src/farmhash.cc
)
set_target_properties(farmhash
PROPERTIES
    PUBLIC_HEADER src/farmhash.h
)

if(CMAKE_SYSTEM_NAME MATCHES iOS)
elseif(NOT MSVC)
    check_cxx_compiler_flag(-msse4.2 HAVE_SSE42)
    check_cxx_compiler_flag(-mavx    HAVE_AVX)
    check_cxx_compiler_flag(-maes    HAVE_AES)
    if(HAVE_SSE42)
        target_compile_options(farmhash PRIVATE -msse4.2)
    endif()
    if(HAVE_AVX)
        target_compile_options(farmhash PRIVATE -mavx)
    endif()
    if(HAVE_AES)
        target_compile_options(farmhash PRIVATE -maes)
    endif()
endif()

install(TARGETS farmhash
        EXPORT  farmhash-config
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
install(EXPORT  farmhash-config
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/farmhash
)
