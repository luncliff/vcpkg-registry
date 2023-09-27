if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/llama.cpp
    REF b1273 # commit 99115f3fa654b593099c6719ad30e3f54ce231e1
    SHA512 2b3e8fd9673647f59a4fa96621afe2f77ab10a2bee88a96b662b493beb2b66f17c854c1077f01f8ea8998d0296f92225d3033aae0adc756810f80caf45b9a456
    HEAD_REF master
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

if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    set(TARGET_IS_APPLE ON)
else()
    set(TARGET_IS_APPLE OFF)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${ARCH_OPTIONS}
        ${FEATURE_OPTIONS}
        -DLLAMA_ACCELERATE=${TARGET_IS_APPLE}
        -DLLAMA_METAL=${TARGET_IS_APPLE}
        -DLLAMA_STATIC=${USE_STATIC}
        -DLLAMA_BLAS=ON
        ${BLAS_OPTIONS}
        -DPKG_CONFIG_EXECUTABLE:FILEPATH="${PKGCONFIG}"
        -DBUILD_COMMIT:STRING="99115f3fa654b593099c6719ad30e3f54ce231e1"
        -DBUILD_NUMBER:STRING="1273"
    OPTIONS_RELEASE
        -DLLAMA_METAL_NDEBUG=ON
)
vcpkg_cmake_build(TARGET "llama" LOGFILE_BASE build-llama)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/Llama" PACKAGE_NAME "Llama")
vcpkg_copy_pdbs()

vcpkg_copy_tools(TOOL_NAMES
    baby-llama beam-search benchmark convert-llama2c-to-ggml embd-input-test embedding llama-bench
    main perplexity quantize-stats quantize save-load-state server simple speculative train-text-from-scratch    
    AUTO_CLEAN
)
if("test" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES
        test-grad0 test-grammar-parser test-llama-grammar test-quantize-fns test-quantize-perf
        test-sampling test-tokenizer-0-falcon test-tokenizer-0-llama test-tokenizer-1-llama
        AUTO_CLEAN
    )
endif()

file(INSTALL "${SOURCE_PATH}/llama.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL    "${CURRENT_PACKAGES_DIR}/bin/convert.py"
                "${CURRENT_PACKAGES_DIR}/bin/convert-lora-to-ggml.py"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
)
file(REMOVE
    "${CURRENT_PACKAGES_DIR}/bin/convert.py"
    "${CURRENT_PACKAGES_DIR}/debug/bin/convert.py"
    "${CURRENT_PACKAGES_DIR}/bin/convert-lora-to-ggml.py"
    "${CURRENT_PACKAGES_DIR}/debug/bin/convert-lora-to-ggml.py"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
