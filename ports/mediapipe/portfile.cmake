# if(VCPKG_TARGET_IS_WINDOWS)
#     vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
# endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/mediapipe
    REF v0.8.8
    SHA512 76c6e1ccb56a1fa403376ad32805f8cffb09dba9f99e9f0797e3af43937ade6955833ed660c723264618c7e7bd2c3dbe8b9d0ca475cf079920627b47ee4e6752
    HEAD_REF master
    # PATCHES
    #     fix-sources.patch
)
file(COPY ${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt DESTINATION ${SOURCE_PATH})

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
  FEATURES
    opencv4    USE_OPENCV4
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
)
