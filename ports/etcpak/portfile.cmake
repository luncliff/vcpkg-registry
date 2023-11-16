vcpkg_check_linkage(ONLY_STATIC_LIBRARY) 

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO wolfpld/etcpak
    REF 153f0e04a18b93c277684b577365210adcf8e11c
    SHA512 ad65ce7b94ebe8f357310244f2a707c79da915991ee0105a3a6e2e7f8f88624318a93ee045e73b72e83fabc47b13e5802d20cc26004b9ad6b49f5d505e0abb80
    HEAD_REF master
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
file(INSTALL "${SOURCE_PATH}/AUTHORS.txt"
             "${SOURCE_PATH}/README.md"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
