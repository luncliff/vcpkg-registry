vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jax-ml/ml_dtypes
    REF v0.3.1
    SHA512 d8d46fa519d98c9d4f7cd18eb243b738de505efcc80d3d1a76969995c1d88f886e7c54b9b3a6bf0f24d83eee61c91f29d4e725e37e5e0848c87c275ff1212d0b
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}/ml_dtypes")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}/ml_dtypes")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/ml_dtypes" PACKAGE_NAME "ml_dtypes")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
