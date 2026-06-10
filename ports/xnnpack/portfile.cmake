if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/XNNPACK
    REF 639decd22a47153a630e8f9970b8c03b55ec68a6
    SHA512 074d3efd6d198e08f026583f88deab3cf23d45fc8c2081438041d0ec0f23af637c514f182678170a135db92f83c562b41b0316e92a11d31d68a9ee64671fadfe
    HEAD_REF master
    PATCHES
        fix-cmake.patch
        skip-microkernels-generation.patch
)

if(VCPKG_TARGET_IS_WINDOWS)
    # see https://docs.microsoft.com/en-us/cpp/intrinsics/arm64-intrinsics?view=msvc-170
    # see https://github.com/google/XNNPACK/blob/master/scripts/build-windows-arm64.cmd
    # see ${SOURCE_PATH}/scripts/build-windows-arm64.cmd
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm")
        list(APPEND PLATFORM_OPTIONS
            -DXNNPACK_ENABLE_ASSEMBLY=OFF
            -DXNNPACK_ENABLE_ARM_FP16_SCALAR=OFF
            -DXNNPACK_ENABLE_ARM_BF16=OFF # `bfloat16_t` type is missing
            # -DXNNPACK_ENABLE_ARM_FP16_VECTOR=ON # `__fp16` type is missing
        )
    endif()
elseif(VCPKG_TARGET_IS_ANDROID)
    # see ${SOURCE_PATH}/scripts/build-android-armv7.sh
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        list(APPEND PLATFORM_OPTIONS -DXNNPACK_ENABLE_ARM_BF16=OFF)
    endif()
endif()

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using python3: ${PYTHON3}")

file(READ "${SOURCE_PATH}/tools/update-microkernels.py" UPDATE_MICROKERNELS_CONTENT)
string(REPLACE "with codecs.open(filepath, 'r', encoding='utf-8') as output_file:" "with open(filepath, 'r', encoding='utf-8') as output_file:" UPDATE_MICROKERNELS_CONTENT "${UPDATE_MICROKERNELS_CONTENT}")
string(REPLACE "with codecs.open(filepath, 'w', encoding='utf-8') as output_file:" "with open(filepath, 'w', encoding='utf-8') as output_file:" UPDATE_MICROKERNELS_CONTENT "${UPDATE_MICROKERNELS_CONTENT}")
file(WRITE "${SOURCE_PATH}/tools/update-microkernels.py" "${UPDATE_MICROKERNELS_CONTENT}")

file(WRITE "${SOURCE_PATH}/src/build_identifier.c" [=[
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

static const uint8_t xnn_build_identifier[] = { 0 };

size_t xnn_experimental_get_build_identifier_size(void) {
    return sizeof(xnn_build_identifier);
}

const void* xnn_experimental_get_build_identifier_data(void) {
    return xnn_build_identifier;
}

bool xnn_experimental_check_build_identifier(const void* data, const size_t size) {
    if (size != xnn_experimental_get_build_identifier_size()) {
        return false;
    }
    return !memcmp(data, xnn_build_identifier, size);
}
]=])

file(READ "${SOURCE_PATH}/CMakeLists.txt" XNNPACK_CMAKELISTS)
string(REPLACE "\r\n" "\n" XNNPACK_CMAKELISTS "${XNNPACK_CMAKELISTS}")
string(REPLACE [[ADD_CUSTOM_COMMAND(
  OUTPUT "${PROJECT_BINARY_DIR}/build_identifier.c"
  COMMAND "${Python_EXECUTABLE}" "scripts/generate-build-identifier.py" --output "${PROJECT_BINARY_DIR}/build_identifier.c" --input_file_list "${PROJECT_BINARY_DIR}/prod_microkernel_srcs.txt"
  DEPENDS "${PROJECT_BINARY_DIR}/prod_microkernel_srcs.txt"
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)]] [[ADD_CUSTOM_COMMAND(
  OUTPUT "${PROJECT_BINARY_DIR}/build_identifier.c"
  COMMAND "${CMAKE_COMMAND}" -E copy "${PROJECT_SOURCE_DIR}/src/build_identifier.c" "${PROJECT_BINARY_DIR}/build_identifier.c"
  DEPENDS "${PROJECT_SOURCE_DIR}/src/build_identifier.c"
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)]] XNNPACK_CMAKELISTS "${XNNPACK_CMAKELISTS}")
string(REPLACE "TARGET_COMPILE_DEFINITIONS(xnnpack-logging PUBLIC \"XNN_LOG_LEVEL=$<$<CONFIG:Debug>:5>$<$<NOT:$<CONFIG:Debug>>:0>\")" "TARGET_COMPILE_DEFINITIONS(xnnpack-logging PUBLIC \"XNN_LOG_LEVEL=$<$<CONFIG:Debug>:1>$<$<NOT:$<CONFIG:Debug>>:0>\")" XNNPACK_CMAKELISTS "${XNNPACK_CMAKELISTS}")
string(REPLACE [[# Generate and load the micorkernels.cmake files.
MESSAGE(STATUS "Generating microkernels.cmake")
EXECUTE_PROCESS(
    COMMAND "${Python_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/update-microkernels.py" --output "${PROJECT_BINARY_DIR}"
    RESULT_VARIABLE UPDATE_MICROKERNELS_RESULT
)
IF(NOT UPDATE_MICROKERNELS_RESULT EQUAL 0)
    MESSAGE(FATAL_ERROR "Failed to generate \"microkernels.cmake\".")
ENDIF()
INCLUDE("${PROJECT_SOURCE_DIR}/cmake/gen/microkernels.cmake")
]] [[# Generate and load the micorkernels.cmake files.
MESSAGE(STATUS "Using pre-generated microkernels.cmake")
INCLUDE("${PROJECT_SOURCE_DIR}/cmake/gen/microkernels.cmake")
]] XNNPACK_CMAKELISTS "${XNNPACK_CMAKELISTS}")
file(WRITE "${SOURCE_PATH}/CMakeLists.txt" "${XNNPACK_CMAKELISTS}")

# Add _POSIX_C_SOURCE for struct timespec on Linux
if(NOT VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_OSX AND NOT VCPKG_TARGET_IS_EMSCRIPTEN)
    list(APPEND PLATFORM_OPTIONS -DCMAKE_C_FLAGS="-D_POSIX_C_SOURCE=199309L")
    list(APPEND PLATFORM_OPTIONS -DCMAKE_CXX_FLAGS="-D_POSIX_C_SOURCE=199309L")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        test    XNNPACK_BUILD_TESTS
        test    XNNPACK_BUILD_BENCHMARKS
        kleidiai XNNPACK_ENABLE_KLEIDIAI
)

if(NOT VCPKG_TARGET_IS_WINDOWS)
    # CMAKE_POSITION_INDEPENDENT_CODE=ON adds -fPIC on GCC/Clang for shared library builds.
    # On MSVC/Windows this flag is a no-op for static libs (already enforced above via
    # vcpkg_check_linkage(ONLY_STATIC_LIBRARY)) but it triggers MSVC C2143 syntax errors
    # in subgraph.c when CMake propagates the property to OBJECT libraries, so skip it.
    list(APPEND PLATFORM_OPTIONS -DCMAKE_POSITION_INDEPENDENT_CODE=ON)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        ${FEATURE_OPTIONS}
        ${PLATFORM_OPTIONS}
        -DXNNPACK_USE_SYSTEM_LIBS=ON
        "-DCPUINFO_SOURCE_DIR:PATH=${CURRENT_INSTALLED_DIR}"
        "-DPTHREADPOOL_SOURCE_DIR:PATH=${CURRENT_INSTALLED_DIR}"
        -DXNNPACK_ENABLE_MEMOPT=ON
        -DXNNPACK_ENABLE_SPARSE=ON
        # -DXNNPACK_BUILD_ALL_MICROKERNELS=ON # let the project select default
        "-DPython_EXECUTABLE:FILEPATH=${PYTHON3}"
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

# Install all public headers from include/.
# xnnpack's CMake only marks include/xnnpack.h as PUBLIC_HEADER; experimental.h
# and its transitive dependency src/operators/fingerprint_id.h are not installed
# by default. tensorflow-lite >= 2.21.0 directly includes experimental.h, so
# we install those headers here.
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
# experimental.h references "src/operators/fingerprint_id.h" with a path relative
# to the include root, so install those internal headers under include/src/operators/.
file(INSTALL
    "${SOURCE_PATH}/src/operators/fingerprint_id.h"
    "${SOURCE_PATH}/src/operators/fingerprint_id.h.inc"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/src/operators"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
