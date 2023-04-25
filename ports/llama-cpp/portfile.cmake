if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/llama.cpp
    REF 54bb60e26858be251a0eb3cb70f80322aff804a0 # 2023-04-25
    SHA512 64f14c25a8dc6dabf7a222a452f986cb2d9477ae3d44e42a7fec630663fceb30f74a7ec80d1c73c6690f572075f39e20e916aaa41a8480f8a59b9c08d81d22f6
    PATCHES
        fix-openblas.patch
)

x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES numpy pybind11
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using python3: ${PYTHON3}")

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    # list(APPEND ARCH_OPTIONS)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    # list(APPEND ARCH_OPTIONS)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    # list(APPEND ARCH_OPTIONS)
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        f16c LLAMA_F16C
        cublas LLAMA_CUBLAS
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${ARCH_OPTIONS} ${FEATURE_OPTIONS}
        -DLLAMA_ACCELERATE=${VCPKG_TARGET_IS_OSX}
        -DLLAMA_STATIC=${USE_STATIC}
        -DLLAMA_OPENBLAS=${VCPKG_TARGET_IS_WINDOWS}
)
vcpkg_cmake_build(TARGET "llama")
vcpkg_cmake_install()
vcpkg_copy_pdbs()

# this internal header is required by pytorch
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME "copyright")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
