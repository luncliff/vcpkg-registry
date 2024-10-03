if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()
vcpkg_find_acquire_program(PKGCONFIG)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO protocolbuffers/protobuf
    REF v${VERSION} # == v29.0-rc1
    SHA512 bf679f639108fb6fbb3b80cbd252b93bc53169c2bdca335a815eca26135fa3a331d59745952d6e4fe6ffc7daeaae277a89ca3184762373248619a4fa9da88212
    HEAD_REF master
    PATCHES
        fix-utf8-range.patch
        fix-abseil-cpp.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        upb protobuf_BUILD_LIBUPB
        test protobuf_BUILD_TESTS
        test protobuf_BUILD_CONFORMANCE
        examples protobuf_BUILD_EXAMPLES
        disable-rtti protobuf_DISABLE_RTTI
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)
string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" BUILD_STATIC_RUNTIME)

# string(COMPARE EQUAL "${TARGET_TRIPLET}" "${HOST_TRIPLET}" BUILD_PROTOC)
if(VCPKG_CROSSCOMPILING)
    set(BUILD_PROTOC OFF)
else()
    set(BUILD_PROTOC ON)
endif()

if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    set(WITH_ZLIB ON) # Use system SDK supported ZLIB
else()
    set(WITH_ZLIB OFF)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -Dprotobuf_WITH_ZLIB=${WITH_ZLIB}
        -Dprotobuf_MSVC_STATIC_RUNTIME=${BUILD_STATIC_RUNTIME}
        -Dprotobuf_BUILD_SHARED_LIBS=${BUILD_SHARED}
        -Dprotobuf_BUILD_PROTOC_BINARIES=${BUILD_PROTOC}
        -Dprotobuf_BUILD_LIBPROTOC=${BUILD_PROTOC}
        -Dprotobuf_ABSL_PROVIDER=package # ${SOURCE_PATH}/cmake/abseil-cpp.cmake
        -Dprotobuf_JSONCPP_PROVIDER=package
        -Dprotobuf_DEBUG_POSTFIX=
    MAYBE_UNUSED_VARIABLES
        protobuf_JSONCPP_PROVIDER
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

# https://cmake.org/cmake/help/latest/module/FindProtobuf.html
vcpkg_cmake_config_fixup(PACKAGE_NAME Protobuf CONFIG_PATH lib/cmake/protobuf)
vcpkg_fixup_pkgconfig()

if(BUILD_PROTOC)
    # get all names of the executables and append to PROTOC_NAMES
    file(GLOB PROTOC_EXES "${CURRENT_PACKAGES_DIR}/bin/protoc*${CMAKE_EXECUTABLE_SUFFIX}" )
    foreach(PROTOC_EXE ${PROTOC_EXES})
        if(WIN32)
            get_filename_component(PROTOC_NAME "${PROTOC_EXE}" NAME_WE) # exclude extension
        else()
            get_filename_component(PROTOC_NAME "${PROTOC_EXE}" NAME)
        endif()
        list(APPEND PROTOC_NAMES ${PROTOC_NAME})
    endforeach()
    vcpkg_copy_tools(TOOL_NAMES ${PROTOC_NAMES} AUTO_CLEAN)    

    # protoc executable must be correct version. NO_DEFAULT_PATH
    configure_file(
        "${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake"
        "${CURRENT_PACKAGES_DIR}/share/${PORT}/vcpkg-cmake-wrapper.cmake"
        @ONLY
    )
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/include/upb"
    "${CURRENT_PACKAGES_DIR}/include/upb_generator"
    "${CURRENT_PACKAGES_DIR}/include/java"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
