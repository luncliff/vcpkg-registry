@PACKAGE_INIT@
if(Z_XNNPACK_CONFIG_GUARD)
    return()
endif()
set(Z_XNNPACK_CONFIG_GUARD ON CACHE INTERNAL "Guard variable for 'xnnpack-config.cmake'")

include(CMakeFindDependencyMacro)

# from vcpkg, luncliff/vcpkg-registry
find_library(PTHREADPOOL_LIBRARY NAMES pthreadpool REQUIRED)
get_filename_component(PTHREADPOOL_LIBRARY_DIR "${PTHREADPOOL_LIBRARY}" PATH)

find_dependency(cpuinfo) # cpuinfo::cpuinfo

find_path(XNNPACK_INCLUDE_DIR NAMES xnnpack.h REQUIRED)
find_library(XNNPACK_LIBRARY NAMES XNNPACK REQUIRED)

set(XNNPACK_IMPORT_TYPE STATIC)
if(XNNPACK_LIBRARY MATCHES "${CMAKE_SHARED_LIBRARY_SUFFIX}")
  set(XNNPACK_IMPORT_TYPE SHARED)
endif()
add_library(xnnpack ${XNNPACK_IMPORT_TYPE} IMPORTED)

# because this is not officially supported...
add_library(unofficial::xnnpack ALIAS xnnpack)

set_target_properties(xnnpack
PROPERTIES
  C_STANDARD 99
  CXX_STANDARD 14
  INTERFACE_COMPILE_FEATURES "cxx_std_14"
  INTERFACE_INCLUDE_DIRECTORIES "${XNNPACK_INCLUDE_DIR}"
  INTERFACE_LINK_LIBRARIES "${PTHREADPOOL_LIBRARY};cpuinfo::cpuinfo"
  INTERFACE_LINK_DIRECTORIES "${PTHREADPOOL_LIBRARY_DIR}"
  IMPORTED_LOCATION "${XNNPACK_LIBRARY}"
)
