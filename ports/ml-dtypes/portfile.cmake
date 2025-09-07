vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jax-ml/ml_dtypes
    REF v${VERSION}
    SHA512 7f1e036201e12349710ae9a9825cd575383b72052a7ebabe26a96952ea0f0be9d4e47a928e454644681a5ec5df88d3142e31602f3146ce5eebbe4bdbe9670ae7
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
