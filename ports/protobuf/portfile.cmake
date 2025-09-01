vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO protocolbuffers/protobuf
    REF "v32.0"
    SHA512 89806b219fa2132e46bf01b7a5831c2977ad7ebe06750956d0e17bcdc028498e883704445fca56bb813f4b78e935709f67f8fa1b46b597840c58a843483cdafb
    HEAD_REF master
    PATCHES
        fix-utf8-range.patch
)

string(COMPARE EQUAL "${TARGET_TRIPLET}" "${HOST_TRIPLET}" protobuf_BUILD_PROTOC_BINARIES)
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" protobuf_BUILD_SHARED_LIBS)
string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" protobuf_MSVC_STATIC_RUNTIME)

# protoc is a build tool, so we cannot build it when cross compiling
if(VCPKG_CROSSCOMPILING)
    set(protobuf_BUILD_LIBPROTOC OFF)
else()
    set(protobuf_BUILD_LIBPROTOC ON)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -Dprotobuf_BUILD_SHARED_LIBS=${protobuf_BUILD_SHARED_LIBS}
        -Dprotobuf_MSVC_STATIC_RUNTIME=${protobuf_MSVC_STATIC_RUNTIME}
        -Dprotobuf_BUILD_TESTS=OFF
        -DCMAKE_INSTALL_CMAKEDIR:STRING=share/protobuf
        -Dprotobuf_BUILD_PROTOC_BINARIES=${protobuf_BUILD_PROTOC_BINARIES}
        -Dprotobuf_BUILD_LIBPROTOC=${protobuf_BUILD_LIBPROTOC}
        -Dprotobuf_BUILD_LIBUPB=ON
        -Dprotobuf_WITH_ZLIB=OFF
)
vcpkg_cmake_install()

if(protobuf_BUILD_PROTOC_BINARIES)
    vcpkg_copy_tools(TOOL_NAMES protoc AUTO_CLEAN)
    # string(REPLACE "." ";" VERSION_LIST ${VERSION})
    # list(GET VERSION_LIST 1 VERSION_MINOR)
    # list(GET VERSION_LIST 2 VERSION_PATCH)
    # todo: check protoc-${VERSION_MINOR}.${VERSION_PATCH}.0 exists and vcpkg_copy_tools it.
    if(VCPKG_TARGET_IS_WINDOWS)
        vcpkg_copy_tools(TOOL_NAMES protoc-gen-upb protoc-gen-upbdefs protoc-gen-upb_minitable AUTO_CLEAN)
    endif()
endif()

vcpkg_cmake_config_fixup()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

if(NOT protobuf_BUILD_PROTOC_BINARIES)
    configure_file("${CMAKE_CURRENT_LIST_DIR}/protobuf-targets-vcpkg-protoc.cmake" "${CURRENT_PACKAGES_DIR}/share/${PORT}/protobuf-targets-vcpkg-protoc.cmake" COPYONLY)
endif()
configure_file("${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" "${CURRENT_PACKAGES_DIR}/share/${PORT}/vcpkg-cmake-wrapper.cmake" @ONLY)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
