vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jax-ml/ml_dtypes
    REF v0.5.0
    SHA512 20b2677c1e69b9ea298ac7d8ccfee3f0d19b847a805efa183ba04845e1a1697e9030abe00d6e8a4d46981df14c8d5986bcbc3b4e0f36eef2aee1cd04e3996bfe
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}/ml_dtypes")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}/ml_dtypes")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/ml_dtypes" PACKAGE_NAME "ml_dtypes")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
