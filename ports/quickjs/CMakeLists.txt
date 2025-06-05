cmake_minimum_required(VERSION 3.21)
project(quickjs LANGUAGES C)

include(GNUInstallDirs)

add_library(quickjs STATIC
    cutils.c
    dtoa.c
    # libregexp.c
    libunicode.c
    # qjs.c
    # qjsc.c
    quickjs-libc.c
    quickjs.c
)
target_compile_features(quickjs PUBLIC c_std_11)

if(MSVC)
    target_compile_definitions(quickjs PRIVATE
        _CRT_SECURE_NO_WARNINGS
    )
endif()

install(TARGETS quickjs DESTINATION ${CMAKE_INSTALL_LIBDIR})
