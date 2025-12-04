if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO dmlc/dlpack
    REF v1.2
    SHA512 73628feddeb07c7942a4f5e0a9cdfbc95c3035e39e4b41e33b9a5b83f5da400f42e79d15507d4b7487be725b1a9983abb9050f6ffd5c909c9185809a02976755
    HEAD_REF main
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_MOCK=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME "dlpack" CONFIG_PATH "lib/cmake/dlpack")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/lib"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
