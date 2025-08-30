if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO BinomialLLC/basis_universal
    REF v1_60
    SHA512 9464a944b2eaad5574e5f54b5d528be29d498f53463db1e00791ed61f0c497d4f1b9f8f78dba0e99c979ce70a894f8786b5ebef4b7741bfd244c7b56b7fb04fe
    HEAD_REF master
    PATCHES
        fix-zstd-import.patch
)
# check https://gcc.gnu.org/onlinedocs/
# check https://www.gnu.org/software/libc/manual/html_node/Feature-Test-Macros.html
# todo: support basisu_tool.cpp build
# todo: support EMSCRIPTEN for ${SOURCE_PATH}/webgl sources
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

file(REMOVE_RECURSE
    "${SOURCE_PATH}/OpenCL"
    "${SOURCE_PATH}/zstd"
    # todo: use minizip
    # "${SOURCE_PATH}/encoder/basisu_miniz.h"
    # todo: use tinyexr
    # "${SOURCE_PATH}/encoder/3rdparty/tinyexr.h"
    # "${SOURCE_PATH}/encoder/3rdparty/tinyexr.cpp"
    # todo: replace jpgd?
    # "${SOURCE_PATH}/encoder/jpgd.h"
    # "${SOURCE_PATH}/encoder/jpgd.cpp"
    # todo: replace pvpngreader?
    # "${SOURCE_PATH}/encoder/pvpngreader.h"
    # "${SOURCE_PATH}/encoder/pvpngreader.cpp"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        opencl  USE_OPENCL
        zstd    USE_ZSTD
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
    "${CURRENT_PACKAGES_DIR}/include/encoder/3rdparty"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
