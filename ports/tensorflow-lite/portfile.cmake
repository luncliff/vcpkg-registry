
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

if("mediapipe" IN_LIST FEATURES)
    # Patches from google/mediapipe v0.8.9
    list(APPEND FEATURE_PATCHES
        org_tensorflow_custom_ops.diff
        # org_tensorflow_compatibility_fixes.diff
        support-mediapipe.patch
    )
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.7.0
    SHA512 f1e892583c7b3a73d4d39ec65dc135a5b02c789b357d57414ad2b6d05ad9fbfc8ef81918ba6410e314abd6928b76f764e6ef64c0b0c84b58b50796634be03f39
    PATCHES
        fix-cmakelists.patch
        fix-debug-build.patch
        fix-eigen3-import.patch
        fix-gpu-build.patch
        fix-gpu-sources.patch
        ${FEATURE_PATCHES}
)

# Changing Eigen3's include path requires a big diff...
# Workaround it by copying existing Eigen3 sources
# file(REMOVE_RECURSE "${SOURCE_PATH}/third_party/eigen3")
# file(COPY "${CURRENT_INSTALLED_DIR}/include/eigen3" DESTINATION "${SOURCE_PATH}/third_party")

if(VCPKG_TARGET_IS_OSX AND ("gpu" IN_LIST FEATURES))
    # .proto files for coreml_mlmodel_codegen
    vcpkg_from_github(
        OUT_SOURCE_PATH COREML_SOURCE_PATH
        REPO apple/coremltools
        REF 5.1
        SHA512 4cabfcdee33e2f45626a80e2a9a2aa94ffe33bfc6daff941fca32b1b8428eeec6f65f552b9370c38fa6fca7aa075ff303e1c9b9cdf6cb680b41b6185e94ce36f
        HEAD_REF main
    )
    find_program(FLATC_EXECUTABLE NAMES flatc PATHS ${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
    message(STATUS "Using flatc: ${FLATC_EXECUTABLE}")
    find_program(PROTOC_EXECUTABLE NAMES protoc PATHS ${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
    message(STATUS "Using protoc: ${PROTOC_EXECUTABLE}")
    list(APPEND PLATFORM_OPTIONS
        -DFLATC_EXECUTABLE:FILE_PATH=${FLATC_EXECUTABLE}
        -DPROTOC_EXECUTABLE:FILE_PATH=${PROTOC_EXECUTABLE}
    )
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu      TFLITE_ENABLE_GPU
        private  TFLITE_PRIVATE_HEADERS
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/tensorflow/lite"
    OPTIONS
        ${FEATURE_OPTIONS} ${PLATFORM_OPTIONS}
        -DTFLITE_ENABLE_RUY=ON
        -DTFLITE_ENABLE_XNNPACK=ON
        -DTFLITE_ENABLE_NNAPI=${VCPKG_TARGET_IS_ANDROID}
        -DCOREML_SOURCE_DIR=${COREML_SOURCE_PATH}
    MAYBE_UNUSED_VARIABLES
        COREML_SOURCE_DIR
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

if("private" IN_LIST FEATURES)
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/gpu/common/default"
                        "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/gpu/common/selectors/default"
                        "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/gpu/common/selectors/mediapipe"
                        "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/gpu/java"
                        "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/gpu/metal"
                        "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/gpu/cl/testing"
    )
endif()
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
