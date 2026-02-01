vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO abseil/abseil-cpp
    REF "${VERSION}"
    SHA512 55bae4cbdf987ad94b4006d9928ef2aafc6e9ac635f02a49aa9b70124c62978a89a3db9f249d1371329df7ab2e25732bee848df4e8530e1ce113833bcbdcbb9a
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

# Remove test-related pkgconfig files that reference non-installed test components
file(REMOVE
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/absl_heterogeneous_lookup_testing.pc"
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/absl_constexpr_testing_internal.pc"
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/absl_random_internal_distribution_test_util.pc"
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/absl_iterator_traits_test_helper_internal.pc"
    "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/absl_heterogeneous_lookup_testing.pc"
    "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/absl_constexpr_testing_internal.pc"
    "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/absl_random_internal_distribution_test_util.pc"
    "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/absl_iterator_traits_test_helper_internal.pc"
)

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
