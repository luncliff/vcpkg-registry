vcpkg_check_linkage(ONLY_STATIC_LIBRARY) # the project doesn't support SHARED

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO EsotericSoftware/spine-runtimes
    REF 07b8d96e19504e9a957b7b994fd143739fc6ea6a
    SHA512 4d031c5681ed61c5e97ea3bd516e3477caf73b01f066021a7dcbc45cfb02f4a1918e033363c5679269963d142c7f98f50b424951cf7cd99ce1481958e83e29f0
    HEAD_REF 4.2
    PATCHES
        fix-cmake.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")
file(REMOVE_RECURSE
    "${SOURCE_PATH}/spine-glfw/src/stb_image.h"
    "${SOURCE_PATH}/spine-sdl/src/stb_image.h"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        glfw    BUILD_GLFW
        sdl2    BUILD_SDL
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/bin"
)

# https://github.com/EsotericSoftware/spine-runtimes?tab=License-1-ov-file
# Copyright (c) 2013-2023, Esoteric Software LLC
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
