if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/XNNPACK
    REF dd04658ad7889be816b04995247e6f1101c9aab1 # 2022-09-09
    SHA512 8efe5b5217cb1f3ef60974dbf671298e51a064cdd52213a51b006b89f1a4a6042c571d39289722d32bf6469870172ff481dd8bc1c73e708274fbc0cde8d8216a
    HEAD_REF master
    PATCHES
        fix-cmake.patch
        windows-parallel-build.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/xnnpack-config.cmake.in" DESTINATION "${SOURCE_PATH}/cmake")

if(VCPKG_TARGET_IS_WINDOWS)
    # Visual Studio generator for CMake to detect ASM compiler
    list(APPEND GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)

    # note: `Assember` class member functions' name collides with MSVC intrinsics...
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm")
        list(APPEND PLATFORM_OPTIONS
            -DXNNPACK_ENABLE_ARM_FP16=OFF # `__fp16` type is missing
            -DXNNPACK_ENABLE_ARM_BF16=OFF # `bfloat16_t` type is missing
            -DXNNPACK_ENABLE_ARM_DOTPROD=OFF
        )
    endif()
    # CMAKE_SYSTEM_PROCESSOR for the generator
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        list(APPEND PLATFORM_OPTIONS -DCMAKE_SYSTEM_PROCESSOR=x86_64)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        list(APPEND PLATFORM_OPTIONS -DCMAKE_SYSTEM_PROCESSOR=i386)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        list(APPEND PLATFORM_OPTIONS -DCMAKE_SYSTEM_PROCESSOR=arm64)
    else() # ex) armv8
        list(APPEND PLATFORM_OPTIONS -DCMAKE_SYSTEM_PROCESSOR=${VCPKG_TARGET_ARCHITECTURE})
    endif()
elseif(VCPKG_TARGET_IS_ANDROID)
    # see https://github.com/google/XNNPACK/blob/master/scripts/build-android-armv7.sh
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        list(APPEND PLATFORM_OPTIONS -DXNNPACK_ENABLE_ARM_BF16=OFF)
    endif()
elseif(VCPKG_TARGET_IS_IOS)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        set(IOS_ARCH "armv7")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(IOS_ARCH "arm64")
    endif()
    list(APPEND PLATFORM_OPTIONS -DIOS_ARCH=${IOS_ARCH})
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        jit      XNNPACK_ENABLE_JIT
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        ${PLATFORM_OPTIONS}
        -DXNNPACK_USE_SYSTEM_LIBS=ON
        -DXNNPACK_ENABLE_ASSEMBLY=ON
        -DXNNPACK_ENABLE_MEMOPT=ON
        -DXNNPACK_ENABLE_SPARSE=ON
        -DXNNPACK_BUILD_TESTS=OFF
        -DXNNPACK_BUILD_BENCHMARKS=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share)

file(INSTALL ${SOURCE_PATH}/LICENSE
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include
                    ${CURRENT_PACKAGES_DIR}/debug/bin
                    ${CURRENT_PACKAGES_DIR}/debug/share
)
