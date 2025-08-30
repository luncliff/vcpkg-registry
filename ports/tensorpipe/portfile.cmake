vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/tensorpipe
    REF af0118d13e52f5a08841464a768e01a0bf3e3075
    SHA512 f2b4464d69afdffd5e98930b84f41344aa01aa912549e2d842c5950aa188abd9c45ac741cb3c2a74e135d44803497c33bc9260e219e3b4c105cb0f99ee7e1d0c
    PATCHES
        fix-cmakelists.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/TensorpipeConfig.cmake.in" DESTINATION "${SOURCE_PATH}/cmake")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        cuda        TP_USE_CUDA
        cuda        TP_ENABLE_CUDA_IPC
        pybind11    TP_BUILD_PYTHON
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DTP_ENABLE_SHM=${VCPKG_TARGET_IS_LINUX}
        -DTP_ENABLE_IBV=OFF
        -DTP_ENABLE_CMA=OFF
        -DTP_BUILD_LIBUV=OFF # will use libuv package
        -DTP_ENABLE_CUDA_GDR=OFF
        -DTP_BUILD_TESTING=OFF
    MAYBE_UNUSED_VARIABLES
        TP_ENABLE_CUDA_GDR
        TP_ENABLE_CUDA_IPC
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/cmake/Tensorpipe" PACKAGE_NAME Tensorpipe)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
