if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY) 
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jpcy/xatlas
    REF f700c7790aaa030e794b52ba7791a05c085faf0c
    SHA512 1f7afcc9056ab636abef017033aaf63d219cdec95e871beade2c694f8e8b4a58563cf506c5afb6d0d5536233f791e11adbcf3f6f26548105b31d381289892dea
    HEAD_REF master
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}/source")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}/source")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/${PORT})
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
