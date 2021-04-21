
set(LUA_VERSION 5.3.6)

vcpkg_download_distfile(ARCHIVE
    URLS "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
    FILENAME "lua-${LUA_VERSION}.tar.gz"
    SHA512 ccc380d5e114d54504de0bfb0321ca25ec325d6ff1bfee44b11870b660762d1a9bf120490c027a0088128b58bb6b5271bbc648400cab84d2dc22b512c4841681
)
vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE ${ARCHIVE}
    PATCHES
        fix-ios-system.patch
)
file(COPY ${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt DESTINATION ${SOURCE_PATH})

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        cpp     BUILD_FOR_CXX
        tools   BUILD_TOOLS
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DLUA_VERSION=${LUA_VERSION}
        ${FEATURE_OPTIONS}
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup()

if("tools" IN_LIST FEATURES)
    vcpkg_copy_tool_dependencies(${CURRENT_PACKAGES_DIR}/tools/lua)
endif()

# see http://www.lua.org/copyright.html
file(INSTALL ${CMAKE_CURRENT_LIST_DIR}/COPYRIGHT DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include
                    ${CURRENT_PACKAGES_DIR}/debug/share
)

