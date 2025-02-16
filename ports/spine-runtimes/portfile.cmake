vcpkg_check_linkage(ONLY_STATIC_LIBRARY) # the project doesn't support SHARED

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO EsotericSoftware/spine-runtimes
    REF 1cdbf9be1a92e0a3015af8e0f0e1b05b872e33c9
    SHA512 444c8409c25e92b6c02a4d05f3ec84fced9622b62fbe68a4c4ce813b1451da5188b08be6df37dacde7da7a0bd01cb7d476afc531574793871b850025ec3c505a
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
