if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

# for onnxruntime, using just before https://github.com/google/XNNPACK/commit/142aceb06d509b57d02ddc2a9558ab35eacbb6fb

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/XNNPACK
    REF db68602a37353f3050c1835d5609a1ce1a3f3d2a # 2023-04-13
    SHA512 66d8546678fb268e75b318cff997d24748db49447df2ec0c2fec7a4c6a0bdb3d985d25df18c6eb85aec8a66627b62e41c02c584c3b7ee7d631fb95b42aee074b
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/xnnpack-config.cmake.in" DESTINATION "${SOURCE_PATH}/cmake")

if(VCPKG_TARGET_IS_WINDOWS)
    # Visual Studio generator may required for CMake to detect ASM compiler
    # Use `vcpkg_cmake_configure(WINDOWS_USE_MSBUILD)` if the Ninja can't detect it correctly
    list(APPEND GENERATOR_OPTIONS
        -DCMAKE_ASM_COMPILER=cl
        -DCMAKE_MSVC_RUNTIME_LIBRARY:STRING= # see https://cmake.org/cmake/help/latest/policy/CMP0091.html
    )
    # CMAKE_SYSTEM_PROCESSOR for the generator
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR=x86_64)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR=i386)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR=arm64) # -DCMAKE_ASM_COMPILER=armasm64?
    else() # ex) armv8
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR=${VCPKG_TARGET_ARCHITECTURE})
    endif()
    # see also: https://docs.microsoft.com/en-us/cpp/intrinsics/arm64-intrinsics?view=msvc-170
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm")
        list(APPEND PLATFORM_OPTIONS
            -DXNNPACK_ENABLE_ARM_FP16=OFF # `__fp16` type is missing
            -DXNNPACK_ENABLE_ARM_BF16=OFF # `bfloat16_t` type is missing
            -DXNNPACK_ENABLE_ARM_FP16_SCALAR=OFF
            -DXNNPACK_ENABLE_ARM_DOTPROD=OFF
        )
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
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(IOS_ARCH "x86_64")
    else()
        message(FATAL_ERROR "Unexpected VCPKG_TARGET_ARCHITECTURE")
    endif()
    list(APPEND PLATFORM_OPTIONS -DIOS_ARCH=${IOS_ARCH})
endif()

set(USE_ASSEMBLY true)
if(VCPKG_TARGET_IS_WINDOWS AND (VCPKG_TARGET_ARCHITECTURE MATCHES "arm"))
    set(USE_ASSEMBLY false)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        ${FEATURE_OPTIONS}
        ${GENERATOR_OPTIONS}
        ${PLATFORM_OPTIONS}
        -DXNNPACK_USE_SYSTEM_LIBS=ON
        -DXNNPACK_ENABLE_ASSEMBLY:BOOL=${USE_ASSEMBLY}
        -DXNNPACK_ENABLE_MEMOPT=ON
        -DXNNPACK_ENABLE_SPARSE=ON
        -DXNNPACK_BUILD_TESTS=OFF
        -DXNNPACK_BUILD_BENCHMARKS=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share)

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
