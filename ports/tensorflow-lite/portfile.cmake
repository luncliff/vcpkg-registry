if(NOT VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

# vcpkg_download_distfile(MP_PATCH_1
#     URLS "https://raw.githubusercontent.com/google/mediapipe/v0.9.2.1/third_party/org_tensorflow_compatibility_fixes.diff"
#     FILENAME org_tensorflow_compatibility_fixes.diff
#     SHA512 4f30038f78e2cc8991a7ec173f6b081ba8bd151163569e840fa34d091ece0ec61eeebde18210a2f11b9bc21a5d8a0bde29a9c0a3638a4d7936b99de8781b7df1
# )
# vcpkg_download_distfile(MP_PATCH_2
#     URLS "https://raw.githubusercontent.com/google/mediapipe/v0.9.2.1/third_party/org_tensorflow_custom_ops.diff"
#     FILENAME org_tensorflow_custom_ops.diff
#     SHA512 11fb8f48e39ef30328af0a216c3ea6bcbbbf68980dbbb5b6a9e4a1f11586f5f7836caf8ab6357785c624c3c6d10f516b185a504ea1bbcdaa69ce84522c8df60a
# )

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.11.1
    SHA512 2ca39d005efa129b5bebd3729f2550d8de659acd57b797f501307c28eb3d0d482703abe4d7364d5572fa600287505f4ed3b4f78eaae6867dc85b4a7d53d4b60b
    PATCHES
        fix-cmake.patch
        fix-source.patch
        fix-absl.patch
        fix-opencl-extension.patch
        org_tensorflow_compatibility_fixes.diff # ${MP_PATCH_1}
        org_tensorflow_custom_ops.diff # ${MP_PATCH_2}
)

file(REMOVE_RECURSE "${SOURCE_PATH}/third_party/eigen3")
file(COPY "${CURRENT_INSTALLED_DIR}/include/eigen3" DESTINATION "${SOURCE_PATH}/third_party")

find_program(FLATC NAMES flatc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using flatc: ${FLATC}")

find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using protoc: ${PROTOC}")

# Run codegen with existing .fbs, .proto files
set(TENSORFLOW_SOURCE_DIR "${SOURCE_PATH}")
set(TFLITE_SOURCE_DIR "${SOURCE_PATH}/tensorflow/lite")

set(EXPERIMANTAL_ACC_CONFIG_PATH "${TFLITE_SOURCE_DIR}/experimental/acceleration/configuration")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --proto configuration.proto
    LOGNAME codegen-flatc-configuration
    WORKING_DIRECTORY "${EXPERIMANTAL_ACC_CONFIG_PATH}"
)
vcpkg_execute_required_process(
    COMMAND ${PROTOC} --cpp_out=. configuration.proto
    LOGNAME codegen-protoc-configuration
    WORKING_DIRECTORY "${EXPERIMANTAL_ACC_CONFIG_PATH}"
)
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --scoped-enums configuration.fbs
    LOGNAME codegen-flatc-cpp-configuration
    WORKING_DIRECTORY "${EXPERIMANTAL_ACC_CONFIG_PATH}"
)

set(SCHEMA_PATH "${TFLITE_SOURCE_DIR}/schema")
vcpkg_execute_required_process(
    COMMAND ${FLATC} -c --gen-object-api --gen-mutable schema.fbs
    LOGNAME codegen-flatc-c-schema
    WORKING_DIRECTORY "${SCHEMA_PATH}"
)

set(DELEGATES_GPU_COMMON_TASK_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/common/task")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --scoped-enums serialization_base.fbs
    LOGNAME codegen-flatc-cpp-gl-task-serialization_base
    WORKING_DIRECTORY "${DELEGATES_GPU_COMMON_TASK_PATH}"
)

set(DELEGATES_GPU_COMMON_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/common")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --scoped-enums -I ${TENSORFLOW_SOURCE_DIR} gpu_model.fbs
    LOGNAME codegen-flatc-cpp-gl-task-gpu_model
    WORKING_DIRECTORY "${DELEGATES_GPU_COMMON_PATH}"
)

if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    set(DELEGATES_GPU_METAL_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/metal")
    vcpkg_execute_required_process(
        COMMAND ${FLATC} --cpp --scoped-enums -I ${TENSORFLOW_SOURCE_DIR} inference_context.fbs
        LOGNAME codegen-flatc-cpp-metal-common
        WORKING_DIRECTORY "${DELEGATES_GPU_METAL_PATH}"
    )
else()
    set(DELEGATES_GPU_GL_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/gl")
    vcpkg_execute_required_process(
        COMMAND ${FLATC} --cpp --scoped-enums common.fbs
        LOGNAME codegen-flatc-cpp-gl-common
        WORKING_DIRECTORY "${DELEGATES_GPU_GL_PATH}"
    )
    vcpkg_execute_required_process(
        COMMAND ${FLATC} --cpp --scoped-enums metadata.fbs
        LOGNAME codegen-flatc-cpp-gl-metadata
        WORKING_DIRECTORY "${DELEGATES_GPU_GL_PATH}"
    )
    vcpkg_execute_required_process(
        COMMAND ${FLATC} --cpp --scoped-enums workgroups.fbs
        LOGNAME codegen-flatc-cpp-gl-workgroups
        WORKING_DIRECTORY "${DELEGATES_GPU_GL_PATH}"
    )
    vcpkg_execute_required_process(
        COMMAND ${FLATC} --cpp --scoped-enums compiled_model.fbs
        LOGNAME codegen-flatc-cpp-gl-compiled_model
        WORKING_DIRECTORY "${DELEGATES_GPU_GL_PATH}"
    )
endif()

set(DELEGATES_GPU_CL_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/cl")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --scoped-enums compiled_program_cache.fbs
    LOGNAME codegen-flatc-cpp-cl-compiled_program_cache
    WORKING_DIRECTORY "${DELEGATES_GPU_CL_PATH}"
)
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --scoped-enums -I ${TENSORFLOW_SOURCE_DIR} serialization.fbs
    LOGNAME codegen-flatc-cpp-cl-serialization
    WORKING_DIRECTORY "${DELEGATES_GPU_CL_PATH}"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu     TFLITE_ENABLE_GPU
        gpu     TFLITE_ENABLE_METAL
        mmap    TFLITE_ENABLE_MMAP
        mediapipe WITH_MEDIAPIPE
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/tensorflow/lite"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DTFLITE_ENABLE_RESOURCE=ON
        -DTFLITE_ENABLE_RUY=ON
        -DTFLITE_ENABLE_XNNPACK=ON
        -DTFLITE_ENABLE_NNAPI=${VCPKG_TARGET_IS_ANDROID}
        -DTFLITE_ENABLE_EXTERNAL_DELEGATE=ON
        -DTFLITE_ENABLE_INSTALL=ON
        -DTENSORFLOW_SOURCE_DIR:PATH="${SOURCE_PATH}"
    OPTIONS_DEBUG
        -DTFLITE_ENABLE_NNAPI_VERBOSE_VALIDATION=${VCPKG_TARGET_IS_ANDROID}
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/${PORT}")

file(INSTALL "${SOURCE_PATH}/tensorflow/core/public/version.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include/tensorflow/core/public")
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
    if((NOT VCPKG_TARGET_IS_IOS) AND (NOT VCPKG_TARGET_IS_OSX))
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/coreml")
    endif()
    if(NOT VCPKG_TARGET_IS_ANDROID)
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/nnapi"
                            "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/nnapi"
        )
    endif()
endif()
