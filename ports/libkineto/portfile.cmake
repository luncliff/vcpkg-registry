vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/kineto
    REF 7a2a167b7233e3a0294c2ebb94c458cccfed7f42
    SHA512 297b19d518ae6eaaf4d2a869e47ed912fd8e0fac024fdde166d6e1b7b75728d8f3573faab6144252bb0a21de238b73b9119735ba26dc7d87c5b8adb9f2bc0e71
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
        -DLIBKINETO_NOCUPTI=OFF # use CUDA::cupti
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME kinetoLibrary CONFIG_PATH "share/cmake/kineto")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
