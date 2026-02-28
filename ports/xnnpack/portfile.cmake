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

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        test    XNNPACK_BUILD_TESTS
        test    XNNPACK_BUILD_BENCHMARKS
        kleidiai XNNPACK_ENABLE_KLEIDIAI
)

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
# file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
