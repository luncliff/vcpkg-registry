vcpkg_check_linkage(ONLY_STATIC_LIBRARY) 

# https://sourceforge.net/projects/infozip/files/Zip%203.x%20%28latest%29/3.0/
vcpkg_download_sourceforge(ARCHIVE
    REPO infozip
    REF "Zip%203.x%20%28latest%29/3.0"
    FILENAME zip30.zip
    SHA512 642ea6768d79adc1499251a3fb7bfc7ddc8d708699cbf9e0cfe849deda94165cb93e21dc2606bea1166ae5d8531e1e2cb056a7246bf2ab86ea7587bd4712d8d8
)
vcpkg_extract_source_archive(SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}"
    WINDOWS_USE_MSBUILD
)
vcpkg_cmake_install()

vcpkg_copy_tools(TOOL_NAMES zip AUTO_CLEAN)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
