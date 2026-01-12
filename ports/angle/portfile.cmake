vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/angle
    REF 2d91f554ab55bd1bef6998ab4094f60ae3e7feb5
    SHA512 bf97418db1c5217fabe1a56def6f02c382bd4eeb7b24c639f83366dd0d6418c9dd29037dd4869ba368292f04fef39602b643bb9c5199a03993c7c7da89a98a6e
    HEAD_REF main
)

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON3_DIR "${PYTHON3}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${PYTHON3_DIR}")

# Configure GN args for ANGLE
set(ANGLE_GN_ARGS "")
string(APPEND ANGLE_GN_ARGS " is_component_build=false")
string(APPEND ANGLE_GN_ARGS " angle_enable_vulkan=true")
string(APPEND ANGLE_GN_ARGS " angle_enable_gl=true")
string(APPEND ANGLE_GN_ARGS " angle_enable_d3d9=false")
string(APPEND ANGLE_GN_ARGS " angle_enable_d3d11=true")
string(APPEND ANGLE_GN_ARGS " angle_enable_metal=false")
string(APPEND ANGLE_GN_ARGS " angle_enable_null=false")
string(APPEND ANGLE_GN_ARGS " angle_enable_swiftshader=false")
string(APPEND ANGLE_GN_ARGS " angle_has_build=false")
string(APPEND ANGLE_GN_ARGS " angle_build_tests=false")
string(APPEND ANGLE_GN_ARGS " angle_build_samples=false")
string(APPEND ANGLE_GN_ARGS " angle_use_x11=false")

if(VCPKG_TARGET_IS_WINDOWS)
    string(APPEND ANGLE_GN_ARGS " target_os=\"win\"")
    string(APPEND ANGLE_GN_ARGS " angle_enable_d3d11=true")
elseif(VCPKG_TARGET_IS_LINUX)
    string(APPEND ANGLE_GN_ARGS " target_os=\"linux\"")
    string(APPEND ANGLE_GN_ARGS " angle_use_x11=true")
elseif(VCPKG_TARGET_IS_OSX)
    string(APPEND ANGLE_GN_ARGS " target_os=\"mac\"")
    string(APPEND ANGLE_GN_ARGS " angle_enable_metal=true")
elseif(VCPKG_TARGET_IS_ANDROID)
    string(APPEND ANGLE_GN_ARGS " target_os=\"android\"")
elseif(VCPKG_TARGET_IS_IOS)
    string(APPEND ANGLE_GN_ARGS " target_os=\"ios\"")
    string(APPEND ANGLE_GN_ARGS " angle_enable_metal=true")
endif()

set(ANGLE_GN_ARGS_DEBUG "is_debug=true")
set(ANGLE_GN_ARGS_RELEASE "is_debug=false is_official_build=true")

vcpkg_gn_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS "${ANGLE_GN_ARGS}"
    OPTIONS_DEBUG "${ANGLE_GN_ARGS_DEBUG}"
    OPTIONS_RELEASE "${ANGLE_GN_ARGS_RELEASE}"
)

# Build ANGLE libraries
vcpkg_gn_install(
    SOURCE_PATH "${SOURCE_PATH}"
    TARGETS angle
)

# Install headers
file(GLOB_RECURSE ANGLE_HEADERS 
    "${SOURCE_PATH}/include/*.h"
)
foreach(HEADER ${ANGLE_HEADERS})
    file(RELATIVE_PATH HEADER_REL "${SOURCE_PATH}/include" "${HEADER}")
    get_filename_component(HEADER_DIR "${HEADER_REL}" DIRECTORY)
    file(INSTALL "${HEADER}" DESTINATION "${CURRENT_PACKAGES_DIR}/include/${HEADER_DIR}")
endforeach()

# Remove duplicate headers from debug
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

# Install copyright
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
