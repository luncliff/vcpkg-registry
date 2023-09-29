vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO zenny-chen/simple-stdatomic-for-VS-Clang
    REF cce17a78911a43e9f963c31d172b2deee56f826e
    SHA512 db540b661ac42be33829f790f0d4a7084ece20ddec829b37fa2d4d2a6a15bead7a0b0475bb31b4cba9168224b3d0c2292f9dbf1fbf3a2d2a49e9466acb4c9387
)
file(COPY "${CURRENT_PORT_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
