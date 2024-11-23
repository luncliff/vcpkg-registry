vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/kineto
    REF 596126cba98181ce4a88e06aa1d602b6afd966dd
    SHA512 5f7916a914e78afba56d47c6589eccf7303a7bdf9a55fcbbeef8733f49e554bce00a4829fb50813736913433a35cdedcccd942c79b1ebb9cae6c76693aae6648
    HEAD_REF main
    PATCHES
        fix-cmake.patch
        fix-sources.patch
)

vcpkg_from_github(
    OUT_SOURCE_PATH DYNOLOG_SOURCE_PATH
    REPO facebookincubator/dynolog
    REF 7570766213484a926908c884888cfb701577a9cb # 2024-11-12
    SHA512 548b51276dfc924ab513406810b90a19de7e0557bfc185cc6e1e285dbaefa685fb8664524c0a04b5802f87911e68e30db675cb1d6bbecc269b441c5972b9dea2
    HEAD_REF main
)
file(REMOVE_RECURSE "${SOURCE_PATH}/libkineto/third_party/dynolog")
file(RENAME "${DYNOLOG_SOURCE_PATH}" "${SOURCE_PATH}/libkineto/third_party/dynolog")

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/libkineto"
    OPTIONS
        -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}
        -DKINETO_BUILD_TESTS=OFF
        -DLIBKINETO_NOCUPTI=ON # todo: support CUDA feature
        -DLIBKINETO_NOROCTRACER=ON
        -DLIBKINETO_NOXPUPTI=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME kinetoLibrary CONFIG_PATH "share/cmake/kineto")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
