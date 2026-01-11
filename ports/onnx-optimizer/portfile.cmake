vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO onnx/optimizer
    REF "v${VERSION}"
    SHA512 07a19a4d752bbc9ad12111b65f0ce47681fb8da57888c99ce3939b26590a27db702ef8ef295dee4c34d188cf283bafb5b84a35f180ae34e9281808fccfdd887d
    HEAD_REF master
    PATCHES
        fix-cmakelists.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DONNX_OPT_USE_SYSTEM_PROTOBUF=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME ONNXOptimizer CONFIG_PATH lib/cmake/ONNXOptimizer)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/include/onnxoptimizer/test"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
