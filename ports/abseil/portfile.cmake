vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO abseil/abseil-cpp
    REF "${VERSION}"
    SHA512 d3ba654ed7dd7b432494918b2de5d8e2b0ad1c42752c5d726f20d6fe2841828fb4e8beb853e3570a11efecef725029ce5ffa3ebc434efff007e7f60735eb9856
    HEAD_REF master
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        -DCMAKE_CXX_STANDARD=17
        -DABSL_PROPAGATE_CXX_STD=ON
        -DABSL_ENABLE_INSTALL=ON
        -DABSL_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DABSL_BUILD_TESTING=OFF
        -DABSL_USE_EXTERNAL_GOOGLETEST=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/absl PACKAGE_NAME absl)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/include"
)

if(VCPKG_TARGET_IS_WINDOWS AND (VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic"))
    message(WARNING "macro 'ABSL_CONSUME_DLL' may needed in the abseil-cpp importing sources")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/absl/base/config.h"
                         "defined(ABSL_CONSUME_DLL)" "1")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/absl/base/internal/thread_identity.h"
                         "defined(ABSL_CONSUME_DLL)" "1")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
