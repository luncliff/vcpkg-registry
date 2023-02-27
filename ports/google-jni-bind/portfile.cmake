vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/jni-bind
    REF fb9f3f669edc7e68ae16402dd2083c806d5a009d # visited 2023-02-24
    SHA512 3ba2b29cc2e2721bda9fc7073623e65506288c31e783c53b744d9eacd03a9ffc9ca534351f84071f10feb90daf58cbc4e5aa71f3ba8e5c73a52eb1571a5250ab
    HEAD_REF main
    # PATCHES
    #     fix-cmake.patch
)
# Install headers and a shim library with JackWeakAPI.c
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

if(DEFINED ENV{JAVA_HOME})
    message(STATUS "Using JAVA_HOME: $ENV{JAVA_HOME}")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_TESTING=OFF
)
vcpkg_cmake_install()
# vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/jni-bind)
# vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
)
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
