vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.9.1
    SHA512 95ffbee1e50e396065c6f1802fd9668344c45c000e22da859bcd08ec217bcc0a8ff0e84661fdf511f210e8b09d7ae6d26c3fc1ddcf28b8aedf87c0fb1b8b60e4
    PATCHES
        fix-cmake.patch
        fix-cmake-gpu.patch
        fix-cmake-ios.patch
        fix-cmake-android.patch
        fix-source.patch
        fix-source-gpu.patch
)
file(REMOVE_RECURSE "${SOURCE_PATH}/third_party/eigen3")
file(CREATE_LINK "${CURRENT_INSTALLED_DIR}/include/eigen3" "${SOURCE_PATH}/third_party/eigen3" SYMBOLIC)

find_program(FLATC_EXECUTABLE NAMES flatc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using flatc: ${FLATC_EXECUTABLE}")

find_program(PROTOC_EXECUTABLE NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using protoc: ${PROTOC_EXECUTABLE}")

if("gpu" IN_LIST FEATURES)
    if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS) # .proto files for coreml_mlmodel_codegen
        vcpkg_from_github(
            OUT_SOURCE_PATH COREML_SOURCE_PATH
            REPO apple/coremltools
            REF 5.1
            SHA512 4cabfcdee33e2f45626a80e2a9a2aa94ffe33bfc6daff941fca32b1b8428eeec6f65f552b9370c38fa6fca7aa075ff303e1c9b9cdf6cb680b41b6185e94ce36f
            HEAD_REF main
        )
        list(APPEND PLATFORM_OPTIONS -DCOREML_SOURCE_DIR=${COREML_SOURCE_PATH})
    endif()
endif()

# Run codegen with existing .fbs, .proto files
set(TENSORFLOW_SOURCE_DIR "${SOURCE_PATH}")
set(TFLITE_SOURCE_DIR "${SOURCE_PATH}/tensorflow/lite")

set(EXPERIMANTAL_ACC_CONFIG_PATH "${TFLITE_SOURCE_DIR}/experimental/acceleration/configuration")
vcpkg_execute_required_process(
    COMMAND ${FLATC_EXECUTABLE} --proto configuration.proto
    LOGNAME codegen-flatc-configuration
    WORKING_DIRECTORY "${EXPERIMANTAL_ACC_CONFIG_PATH}"
)
vcpkg_execute_required_process(
    COMMAND ${PROTOC_EXECUTABLE} --cpp_out=. configuration.proto
    LOGNAME codegen-protoc-configuration
    WORKING_DIRECTORY "${EXPERIMANTAL_ACC_CONFIG_PATH}"
)
vcpkg_execute_required_process(
    COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums configuration.fbs
    LOGNAME codegen-flatc-cpp-configuration
    WORKING_DIRECTORY "${EXPERIMANTAL_ACC_CONFIG_PATH}"
)

set(SCHEMA_PATH "${TFLITE_SOURCE_DIR}/schema")
vcpkg_execute_required_process(
    COMMAND ${FLATC_EXECUTABLE} -c --gen-object-api --gen-mutable schema.fbs
    LOGNAME codegen-flatc-c-schema
    WORKING_DIRECTORY "${SCHEMA_PATH}"
)

set(DELEGATES_GPU_COMMON_TASK_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/common/task")
vcpkg_execute_required_process(
    COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums serialization_base.fbs
    LOGNAME codegen-flatc-cpp-gl-task-serialization_base
    WORKING_DIRECTORY "${DELEGATES_GPU_COMMON_TASK_PATH}"
)

set(DELEGATES_GPU_COMMON_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/common")
vcpkg_execute_required_process(
    COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums -I ${TENSORFLOW_SOURCE_DIR} gpu_model.fbs
    LOGNAME codegen-flatc-cpp-gl-task-gpu_model
    WORKING_DIRECTORY "${DELEGATES_GPU_COMMON_PATH}"
)

if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    set(DELEGATES_GPU_METAL_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/metal")
    vcpkg_execute_required_process(
        COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums -I ${TENSORFLOW_SOURCE_DIR} inference_context.fbs
        LOGNAME codegen-flatc-cpp-metal-common
        WORKING_DIRECTORY "${DELEGATES_GPU_METAL_PATH}"
    )
else()
    set(DELEGATES_GPU_GL_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/gl")
    vcpkg_execute_required_process(
        COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums common.fbs
        LOGNAME codegen-flatc-cpp-gl-common
        WORKING_DIRECTORY "${DELEGATES_GPU_GL_PATH}"
    )
    vcpkg_execute_required_process(
        COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums metadata.fbs
        LOGNAME codegen-flatc-cpp-gl-metadata
        WORKING_DIRECTORY "${DELEGATES_GPU_GL_PATH}"
    )
    vcpkg_execute_required_process(
        COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums workgroups.fbs
        LOGNAME codegen-flatc-cpp-gl-workgroups
        WORKING_DIRECTORY "${DELEGATES_GPU_GL_PATH}"
    )
    vcpkg_execute_required_process(
        COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums compiled_model.fbs
        LOGNAME codegen-flatc-cpp-gl-compiled_model
        WORKING_DIRECTORY "${DELEGATES_GPU_GL_PATH}"
    )
endif()

set(DELEGATES_GPU_CL_PATH "${TFLITE_SOURCE_DIR}/delegates/gpu/cl")
vcpkg_execute_required_process(
    COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums compiled_program_cache.fbs
    LOGNAME codegen-flatc-cpp-cl-compiled_program_cache
    WORKING_DIRECTORY "${DELEGATES_GPU_CL_PATH}"
)
vcpkg_execute_required_process(
    COMMAND ${FLATC_EXECUTABLE} --cpp --scoped-enums -I ${TENSORFLOW_SOURCE_DIR} serialization.fbs
    LOGNAME codegen-flatc-cpp-cl-serialization
    WORKING_DIRECTORY "${DELEGATES_GPU_CL_PATH}"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu      TFLITE_ENABLE_GPU
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/tensorflow/lite"
    OPTIONS
        ${FEATURE_OPTIONS} ${PLATFORM_OPTIONS}
        -DTFLITE_ENABLE_RESOURCE=ON
        -DTFLITE_ENABLE_RUY=ON
        -DTFLITE_ENABLE_XNNPACK=ON
        -DTFLITE_ENABLE_NNAPI=${VCPKG_TARGET_IS_ANDROID}
        -DFLATC_EXECUTABLE:FILE_PATH=${FLATC_EXECUTABLE}
        -DPROTOC_EXECUTABLE:FILE_PATH=${PROTOC_EXECUTABLE}
    OPTIONS_DEBUG
        -DTFLITE_ENABLE_NNAPI_VERBOSE_VALIDATION=${VCPKG_TARGET_IS_ANDROID}
    MAYBE_UNUSED_VARIABLES
        COREML_SOURCE_DIR
        FLATC_EXECUTABLE
        PROTOC_EXECUTABLE
)
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
    if((NOT VCPKG_TARGET_IS_IOS) AND (NOT VCPKG_TARGET_IS_OSX))
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/coreml")
    endif()
    if(NOT VCPKG_TARGET_IS_ANDROID)
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/nnapi"
                            "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/nnapi"
        )
    endif()
endif()
