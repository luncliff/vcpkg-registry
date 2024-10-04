set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

if(VCPKG_TARGET_IS_WINDOWS)
    message(STATUS "The port will install 'zlib-ng[zlib-compat]' instead")
else()
    message(STATUS "The port is empty. Expect the platform SDK provides ZLIB")
endif()
