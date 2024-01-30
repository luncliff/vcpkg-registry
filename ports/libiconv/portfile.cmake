# copied from microsoft/vcpkg 2024-01-30
set(VCPKG_POLICY_ALLOW_RESTRICTED_HEADERS enabled)
# if(NOT VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_ANDROID AND NOT VCPKG_TARGET_IS_IOS)
#     set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
#     file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/iconv")
#     file(COPY "${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/iconv")
#     return()
# endif()

vcpkg_download_distfile(ARCHIVE
    URLS "https://ftp.gnu.org/gnu/libiconv/libiconv-${VERSION}.tar.gz"
         "https://www.mirrorservice.org/sites/ftp.gnu.org/gnu/libiconv/libiconv-${VERSION}.tar.gz"
    FILENAME "libiconv-${VERSION}.tar.gz"
    SHA512 18a09de2d026da4f2d8b858517b0f26d853b21179cf4fa9a41070b2d140030ad9525637dc4f34fc7f27abca8acdc84c6751dfb1d426e78bf92af4040603ced86
)

vcpkg_extract_source_archive(SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    SOURCE_BASE "v${VERSION}"
    PATCHES
        0002-Config-for-MSVC.patch
        0003-Add-export.patch
        0004-ModuleFileName.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

vcpkg_copy_pdbs()
vcpkg_copy_tool_dependencies("${CURRENT_PACKAGES_DIR}/tools/${PORT}/bin")
vcpkg_copy_tool_dependencies("${CURRENT_PACKAGES_DIR}/tools/${PORT}/debug/bin")

# file(COPY "${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/iconv")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING.LIB")
