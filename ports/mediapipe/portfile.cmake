
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/mediapipe
    REF v0.8.8
    SHA512 76c6e1ccb56a1fa403376ad32805f8cffb09dba9f99e9f0797e3af43937ade6955833ed660c723264618c7e7bd2c3dbe8b9d0ca475cf079920627b47ee4e6752
    HEAD_REF master
)

vcpkg_find_acquire_program(BAZEL)
get_filename_component(BAZEL_DIR "${BAZEL}" DIRECTORY)
vcpkg_add_to_path(PREPEND ${BAZEL_DIR})
# set(ENV{BAZEL_BIN_PATH} "${BAZEL}")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
