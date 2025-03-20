if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
    # vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/XNNPACK
    REF 16cdb6b40f83d770e22493cbe3a05a6c1181d01c
    SHA512 a20ef5c54067893aa86bc59bec013cd6305832e7182334019884d5200dcbe11cf32eea92ba9bcd36c900baa48cdf71117afb6c89142ccdb573604835750306cd
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
        kleidi  XNNPACK_ENABLE_KLEIDIAI
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    WINDOWS_USE_MSBUILD
    OPTIONS
        ${FEATURE_OPTIONS}
        ${PLATFORM_OPTIONS}
        -DXNNPACK_USE_SYSTEM_LIBS=ON
        "-DCPUINFO_SOURCE_DIR:PATH=${CURRENT_INSTALLED_DIR}"
        "-DPTHREADPOOL_SOURCE_DIR:PATH=${CURRENT_INSTALLED_DIR}"
        "-DFXDIV_SOURCE_DIR:PATH=${CURRENT_INSTALLED_DIR}"
        -DXNNPACK_ENABLE_MEMOPT=ON
        -DXNNPACK_ENABLE_SPARSE=ON
        -DXNNPACK_BUILD_ALL_MICROKERNELS=ON
        "-DPython_EXECUTABLE:FILEPATH=${PYTHON3}"
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
