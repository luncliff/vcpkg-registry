vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO facebookincubator/dynolog
    REF 75e2715e2241b0e72891ea5d9f2ec84b781d49ce
    SHA512 c73cabe8eb094d7c22ea20ef94f9346b2bd1cd73233eda833bc68bdf8389e866a8d6b61d4d680d139acd3138479d2fad0f9324cc8761626a25549c4a7006ef2c
    HEAD_REF main
)

vcpkg_find_acquire_program(GIT)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/dynolog"
    OPTIONS
        -DGIT_EXECUTABLE:FILEPATH=${GIT}
        -DDYNOLOG_VERSION=1.0.0
        -DDYNOLOG_GIT_REV=75e2715e2241b0e72891ea5d9f2ec84b781d49ce
        -DWITH_GFLAGS=ON
        -DUSE_PROMETHEUS=ON # prometheus-cpp
        -DUSE_OTLP=ON # curl
        -DUSE_ODS_GRAPH_API=OFF # cpr
        -DBUILD_TESTS=OFF
)
vcpkg_cmake_install()
# vcpkg_cmake_config_fixup(PACKAGE_NAME dynolog CONFIG_PATH "share/cmake/dynolog")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
