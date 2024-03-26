vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jax-ml/ml_dtypes
    REF v0.3.2
    SHA512 d42f6734edc5c159f15b9c020deb2595f32bbcdf53ecfaea840afb38314a855d09315693129393f755fdc3295b5965073b404822aacf1a149c7f9bab89c48fd5
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}/ml_dtypes")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}/ml_dtypes")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/ml_dtypes" PACKAGE_NAME "ml_dtypes")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
