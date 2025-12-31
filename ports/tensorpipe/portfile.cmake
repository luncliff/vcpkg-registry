vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/tensorpipe
    REF b4b77d1006e764fb5cc42597d17d2b110211c2d1
    SHA512 bd0deccfb7289d324615d5bacb0ae7c9da1e2ec1a9a8ba84aacc61373e74f54668f7a60b7751a0b91579fcb5c45aca47852cec66fc39ec14b2023c57d653d723
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
