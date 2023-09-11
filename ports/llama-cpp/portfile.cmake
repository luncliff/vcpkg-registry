if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/llama.cpp
    REF b1213
    SHA512 b39736ece0ee701ac355f5115b0d7cefd5a9723bb2cec6b895181a7764bd0f23b3d14cd5b1c175dccd1ad5e9219d2f7500b2c5c840a504abbd2e50ed62965c3e
)

vcpkg_find_acquire_program(PKGCONFIG)
message(STATUS "Using pkgconfig: ${PKGCONFIG}")

if(VCPKG_TARGET_IS_WINDOWS)
    list(APPEND BLAS_OPTIONS -DLLAMA_BLAS_VENDOR=OpenBLAS)
endif()

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    list(APPEND ARCH_OPTIONS
        -DLLAMA_AVX512=ON -DLLAMA_AVX512_VBMI=ON -DLLAMA_AVX512_VNNI=ON
        # -DLLAMA_AVX2=ON
        # -DLLAMA_AVX=ON
    )
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        cublas  LLAMA_CUBLAS
        cublas  LLAMA_CUDA_F16
        clblast LLAMA_CLBLAST
        mpi     LLAMA_MPI
        test    LLAMA_BUILD_TESTS
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${ARCH_OPTIONS}
        ${FEATURE_OPTIONS}
        -DLLAMA_ACCELERATE=${VCPKG_TARGET_IS_OSX}
        -DLLAMA_METAL=${VCPKG_TARGET_IS_OSX} # todo: support VCPKG_TARGET_IS_IOS
        -DLLAMA_STATIC=${USE_STATIC}
        -DLLAMA_BLAS=ON
        ${BLAS_OPTIONS}
        -DPKG_CONFIG_EXECUTABLE:FILEPATH=${PKGCONFIG}
    OPTIONS_RELEASE
        -DLLAMA_METAL_NDEBUG=ON
)
vcpkg_cmake_build(TARGET "llama" LOGFILE_BASE build-llama)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

vcpkg_copy_tools(TOOL_NAMES
    baby-llama beam-search benchmark convert-llama2c-to-ggml embd-input-test embedding llama-bench
    main perplexity quantize-stats quantize save-load-state server simple speculative train-text-from-scratch    
    AUTO_CLEAN
)
if("test" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES
        test-grad0 test-grammar-parser test-llama-grammar test-quantize-fns test-quantize-perf
        test-sampling test-tokenizer-0-falcon test-tokenizer-0-llama test-tokenizer-1
        AUTO_CLEAN
    )
endif()

file(INSTALL "${SOURCE_PATH}/llama.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL    "${CURRENT_PACKAGES_DIR}/bin/convert.py"
                "${CURRENT_PACKAGES_DIR}/bin/convert-lora-to-ggml.py"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools"
)

file(REMOVE
    "${CURRENT_PACKAGES_DIR}/bin/convert.py"
    "${CURRENT_PACKAGES_DIR}/debug/bin/convert.py"
    "${CURRENT_PACKAGES_DIR}/bin/convert-lora-to-ggml.py"
    "${CURRENT_PACKAGES_DIR}/debug/bin/convert-lora-to-ggml.py"
)

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME "copyright")
