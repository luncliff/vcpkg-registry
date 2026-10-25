vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jax-ml/ml_dtypes
    REF v${VERSION}
    SHA512 6597d4bc9e28deab87d4ce26307d0227f037546710d1794f48186daab633b316134ccbc433fe1175601ea800b19aad178b63a01c529419ca41299b93185290d8
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}/ml_dtypes")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}/ml_dtypes")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/ml_dtypes" PACKAGE_NAME "ml_dtypes")

# use the relative path: "include/float8.h" -> "float8.h"
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/ml_dtypes/mxfloat.h"
                     "include/" "")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
