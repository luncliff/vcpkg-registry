vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jax-ml/ml_dtypes
    REF v${VERSION}
    SHA512 585641b2d4d9ff7b134310ac38484989d85efd3f303cc99fa71b2b693c710f435d4245bb64239b79f823da647e71f477be89d3141fa6aeb775262ea13a4f1bf7
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
