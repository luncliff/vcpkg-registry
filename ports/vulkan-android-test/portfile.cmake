set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

if(NOT DEFINED NDK_VULKAN_LIB_PATH)
    message(FATAL_ERROR "Please install this test port with the customized Android triplets")
endif()
get_filename_component(SOURCE_PATH ${CURRENT_BUILDTREES_DIR}/src ABSOLUTE)

list(APPEND files ${CURRENT_PORT_DIR}/CMakeLists.txt ${CURRENT_PORT_DIR}/libmain.cpp)
file(COPY ${files} DESTINATION ${SOURCE_PATH})

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DVulkan_LIBRARY:FILEPATH=${NDK_VULKAN_LIB_PATH}
)
vcpkg_cmake_build(TARGET test_target)
