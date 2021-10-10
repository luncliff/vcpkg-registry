
# Currently links with an internal library 'fft2d'
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.6.0
    SHA512 d052da4b324f1b5ac9c904ac3cca270cefbf916be6e5968a6835ef3f8ea8c703a0b90be577ac5205edf248e8e6c7ee8817b6a1b383018bb77c381717c6205e05
    PATCHES
        fix-cmakelists.patch
        fix-header-usage.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu      TFLITE_ENABLE_GPU
)
if("gpu" IN_LIST FEATURES)
    # run codegen for "tensorflow/lite/delegates/gpu/cl/serialization_generated.h"
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/tensorflow/lite"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DTFLITE_ENABLE_XNNPACK=ON
        -DTFLITE_ENABLE_NNAPI=${VCPKG_TARGET_IS_ANDROID}
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/testdata"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/python" # todo: Python feature
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/java"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/tools"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/micro"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates" # todo: NNAPI, GPU feature
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/lib_package"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/testing"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/examples"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/toco"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/experimental"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/g3doc"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/tutorials"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/ios"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/objc"
                    "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/swift"
)
