if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO BinomialLLC/basis_universal
    REF 1.16.4
    SHA512 7f7dd62741b4a3e13050233a2ed751e6108cde9eab7b05ea5882ded6ab49fe181cc30e795cf73f8fa625a71e77ae891fda5ea84e20b632b1397844d6539715b3
    HEAD_REF master
    PATCHES
        fix-zstd-import.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")
file(REMOVE_RECURSE
    "${SOURCE_PATH}/OpenCL"
    "${SOURCE_PATH}/zstd"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        opencl  OPENCL
        zstd    ZSTD
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    GENERATOR Ninja
    OPTIONS
        ${FEATURE_OPTIONS}
        -DSAN=OFF
        # -DSSE=...
)
vcpkg_cmake_install()
if(NOT VCPKG_CROSSCOMPILING)
    vcpkg_copy_tools(TOOL_NAMES basisu AUTO_CLEAN)
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/include/basisu/transcoder/basisu_containers_impl.h"
)

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
