vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/jni-bind
    REF Release-1.1.0-beta
    SHA512 ffc011eb1d812360b844ff413ead8eb2c98080264655f7e1e30d9cf8f869875da02882559f147156279f6aa86ceba8a4660ca9fda637ac59d417ceaf4d76330d
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
