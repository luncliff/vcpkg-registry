if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/llama.cpp
    REF b1695 # commit 925e5584a058afb612f9c20bc472c130f5d0f891
    SHA512 3f50216030fe022dbfdcdb7c96765bdf2f1995a4672e7ffbca672fc5f502149d47146428e3f5cdd4799724011b29941826cf66b9178337cce05b8aa0b5292f1c
    HEAD_REF master
)

vcpkg_find_acquire_program(PKGCONFIG)
message(STATUS "Using pkgconfig: ${PKGCONFIG}")

# check https://cmake.org/cmake/help/latest/module/FindBLAS.html#blas-lapack-vendors
if(VCPKG_TARGET_IS_WINDOWS)
    list(APPEND BLAS_OPTIONS -DLLAMA_BLAS_VENDOR=OpenBLAS)
elseif(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    list(APPEND BLAS_OPTIONS -DLLAMA_BLAS_VENDOR=Apple)
else()
    # todo: Intel MKL, ARM, ACML, etc...
    list(APPEND BLAS_OPTIONS -DLLAMA_BLAS_VENDOR=Generic)
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
        -DBUILD_NUMBER:STRING="1695"
    OPTIONS_RELEASE
        -DLLAMA_METAL_NDEBUG=ON
)
vcpkg_cmake_build(TARGET "llama" LOGFILE_BASE build-llama)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/Llama" PACKAGE_NAME "Llama")
vcpkg_copy_pdbs()

vcpkg_copy_tools(TOOL_NAMES
    baby-llama beam-search benchmark convert-llama2c-to-ggml embedding llama-bench
    main perplexity quantize-stats quantize save-load-state server simple speculative train-text-from-scratch    
    batched-bench batched export-lora finetune infill llava-cli lookahead lookup parallel tokenize
    AUTO_CLEAN
)
if("test" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES
        test-grad0 test-grammar-parser test-llama-grammar test-quantize-fns test-quantize-perf
        test-sampling test-tokenizer-0-falcon test-tokenizer-0-llama test-tokenizer-1-llama
        test-backend-ops test-rope test-tokenizer-1-bpe
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
