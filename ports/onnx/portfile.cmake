vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO onnx/onnx
    REF "v${VERSION}"
    SHA512 4bbc4c09e4bb3eb6049d653ce49200564e8c5dcf1154a30f894f24e15f1986d1f2fe2f4ca32fe383c559e2a0b20681f33d649376bf63e4345df6972a2c78eac8
    PATCHES
        fix-cmakelists.patch
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using protoc: ${PROTOC}")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python  BUILD_ONNX_PYTHON
        protobuf-lite   ONNX_USE_LITE_PROTO
        disable-exception   ONNX_DISABLE_EXCEPTIONS
        disable-static-registration ONNX_DISABLE_STATIC_REGISTRATION
)

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        "-DPython_EXECUTABLE:FILEPATH=${PYTHON3}"
        "-DPython3_EXECUTABLE:FILEPATH=${PYTHON3}"
        "-DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}"
        -DONNX_ML=ON
        -DONNX_USE_PROTOBUF_SHARED_LIBS=${USE_PROTOBUF_SHARED}
        -DONNX_USE_LITE_PROTO=OFF
        -DONNX_USE_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DONNX_BUILD_TESTS=OFF
        -DONNX_BUILD_CUSTOM_PROTOBUF=OFF
    MAYBE_UNUSED_VARIABLES
        ONNX_USE_MSVC_STATIC_RUNTIME
        Python_EXECUTABLE
        Python3_EXECUTABLE
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/ONNX PACKAGE_NAME ONNX)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

# Traverse the folder and remove "some" empty folders
function(cleanup_once folder)
    if(NOT IS_DIRECTORY "${folder}")
        return()
    endif()
    file(GLOB paths LIST_DIRECTORIES true "${folder}/*")
    list(LENGTH paths count)
    # 1. remove if the given folder is empty
    if(count EQUAL 0)
        file(REMOVE_RECURSE "${folder}")
        message(VERBOSE "Removed ${folder}")
        return()
    endif()
    # 2. repeat the operation for hop 1 sub-directories 
    foreach(path ${paths})
        cleanup_once(${path})
    endforeach()
endfunction()

# Some folders may contain empty folders. They will become empty after `cleanup_once`.
# Repeat given times to delete new empty folders.
function(cleanup_repeat folder repeat)
    if(NOT IS_DIRECTORY "${folder}")
        return()
    endif()
    while(repeat GREATER_EQUAL 1)
        math(EXPR repeat "${repeat} - 1" OUTPUT_FORMAT DECIMAL)
        cleanup_once("${folder}")
    endwhile()
endfunction()

# https://github.com/microsoft/vcpkg PR 30230
cleanup_repeat("${CURRENT_PACKAGES_DIR}/include" 4)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
