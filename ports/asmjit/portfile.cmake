vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO asmjit/asmjit
    REF 0464e1c8f1f43c861a0c73d4e59437fff255cdd9
    SHA512 e0617c0e427e48448cdb265d47653ba18dc9cdfc2f1fb7800ed3d0e55bda0b47068a623b856d0703edfeb5f0c4f44764aa9b5646e299beb5c09a47b04fe14025
    HEAD_REF master
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" ASMJIT_STATIC)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DASMJIT_STATIC=${ASMJIT_STATIC}
        -DASMJIT_EMBED=OFF
        -DASMJIT_NO_INSTALL=OFF
 )

vcpkg_cmake_install()
vcpkg_copy_pdbs()

vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/asmjit)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.md")
