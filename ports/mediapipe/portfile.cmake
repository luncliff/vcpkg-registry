
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/mediapipe
    REF v0.8.9
    SHA512 e8ff4e4ed6ec97924f46e5fc673f85f8e8a83d77515798d0a187af09b649ba9cd96b894d8a1ebc83103bcc3809f7e132a67c489abb5d198ef17cb50664d3f712
    HEAD_REF master
    PATCHES
        fix-sources.patch
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
        -DUSE_EGL=${VCPKG_TARGET_IS_WINDOWS}
        -DUSE_TFLITE=${VCPKG_TARGET_IS_WINDOWS}
        -DUSE_METAL=${VCPKG_TARGET_IS_OSX}
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(INSTALL "${SOURCE_PATH}/LICENSE"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/share/${PORT}/models/BUILD"
)
