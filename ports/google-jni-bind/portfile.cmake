vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/jni-bind
    REF Release-${VERSION}
    SHA512 ef96ea568857ff562d2d55c6d62f5fbe7b2d914beaeea0246af3da881a6b6a39925d4ac48754cc87683b48bf8673e8fe1bca57ad71a5e789e8fb76c192eb0801
    HEAD_REF main
)
# Install headers and a shim library with JackWeakAPI.c
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

if(DEFINED ENV{JAVA_HOME})
    message(STATUS "Using JAVA_HOME: $ENV{JAVA_HOME}")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        test    BUILD_TESTING
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
