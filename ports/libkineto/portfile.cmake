vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/kineto
    REF 660b5838acdf9d26c4259621b69fa2920903dfdc
    SHA512 652bf0380613e836da68f6edc8df361de68f04b0c80c1a6eed0403e55dafa55d458d10d288f98a87357eda39e293760a2d22a10a5c79c2bd53c47f42d0fb08f6
    HEAD_REF main
    PATCHES
        fix-cmake.patch
        fix-sources.patch
)

vcpkg_from_github(
    OUT_SOURCE_PATH DYNOLOG_SOURCE_PATH
    REPO facebookincubator/dynolog
    REF b428ad3aaa86c7d8bdbb71e3e9dd2b8a4d4eab3f
    SHA512 d8a16e04655dcde9a654b8125e458000455ecf04f6eb4fb93b7773b166351a409a26358f0fa6c3845aab8bda922e8e9098d91cbb4b4c3b3879f5654b79e1414f
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
