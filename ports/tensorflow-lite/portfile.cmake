
# Currently links with an internal library 'fft2d'
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.6.1
    SHA512 34dcec08b73ef25cb6e5bcb0e083c2f43d8364bc9a465e59d63dc3f162a129d011e03faaecf7d563cbbe39f0c2bbf2d1795ccfb8b2ea3f108ed8db992cea9475
    PATCHES
        fix-cmakelists.patch
        fix-eigen3-import.patch
        fix-gpu-build.patch
        fix-gpu-sources.patch
)
if(VCPKG_TARGET_IS_OSX AND ("gpu" IN_LIST FEATURES))
    # .proto files for coreml_mlmodel_codegen
    vcpkg_from_github(
        OUT_SOURCE_PATH COREML_SOURCE_PATH
        REPO apple/coremltools
        REF 5.1
        SHA512 4cabfcdee33e2f45626a80e2a9a2aa94ffe33bfc6daff941fca32b1b8428eeec6f65f552b9370c38fa6fca7aa075ff303e1c9b9cdf6cb680b41b6185e94ce36f
        HEAD_REF main
    )
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu      TFLITE_ENABLE_GPU
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/tensorflow/lite"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DTFLITE_ENABLE_RUY=ON
        -DTFLITE_ENABLE_XNNPACK=ON
        -DTFLITE_ENABLE_NNAPI=${VCPKG_TARGET_IS_ANDROID}
        -DCOREML_SOURCE_DIR=${COREML_SOURCE_PATH}
)
if("gpu" IN_LIST FEATURES)
    # run codegen for ".fbs" files
    vcpkg_cmake_build(TARGET gl_delegate_codegen)
endif()
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/python" # todo: Python feature
)
if("gpu" IN_LIST FEATURES)
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/flex"
                        "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/java"
                        "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/hexagon"
    )
else()
    # remove unsupported delegated for each target platform
    if(NOT DEFINED VCPKG_TARGET_IS_OSX OR NOT VCPKG_TARGET_IS_OSX)
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/coreml")
    endif()
    if(NOT DEFINED VCPKG_TARGET_IS_ANDROID OR NOT VCPKG_TARGET_IS_ANDROID)
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/nnapi"
                            "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/nnapi"
        )
    endif()
endif()
