vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jax-ml/ml_dtypes
    REF v${VERSION}
    SHA512 6f54b43534c2fcf11c869f0c9d780c64cf56368cd6684d1b38b0a5d899d8aea5cb4427445187d4ddf09f5e3583b27b0c1b29091c344762e27324a80f824fc897
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
