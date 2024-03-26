if(NOT VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

# check https://github.com/tensorflow/tensorflow/pull/61381
# vcpkg_download_distfile(TENSORFLOW_PR_61381_PATCH
#     URLS "https://patch-diff.githubusercontent.com/raw/tensorflow/tensorflow/pull/61381.diff"
#     FILENAME tensorflow-pr-61381.patch  SHA512 4308c6f1b2f100689be5829ce770294a85489137b85cfd670df04f503b7a14683d42d798eb24e7679b56d99825257192065fedce9f6d0746a2e776c27e6e89d1
# )

# check https://github.com/tensorflow/tensorflow/pull/62037
# vcpkg_download_distfile(TENSORFLOW_PR_62037_PATCH
#     URLS "https://patch-diff.githubusercontent.com/raw/tensorflow/tensorflow/pull/62037.diff"
#     FILENAME tensorflow-pr-62037.patch  SHA512 e33edae25e1ff9a95e0465a8cf26b7e592a1beb0466e180014ee7b1d7ab2792b04f58c5fb875ed40eae26d3986ac1e2cfa1dbdff14b5c8eaf99655cb697ed6b5
# )

# check https://github.com/tensorflow/tensorflow/pull/62705
# vcpkg_download_distfile(TENSORFLOW_PR_62705_PATCH
#     URLS "https://patch-diff.githubusercontent.com/raw/tensorflow/tensorflow/pull/62705.diff"
#     FILENAME tensorflow-pr-62705.patch  SHA512 0
# )

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.15.1
    SHA512 21f63e7b3a5d8d7d0356a13aac259ca3fd40bd9c118a747378741fc304fa24de2674c0722de92dfa0524c3b5c40bc0dfde1988301b050ac69f2a3f2fbfbf9875
    PATCHES
        tensorflow-pr-61381.patch
        tensorflow-pr-62037.patch
        tensorflow-pr-62705.patch
        fix-cmake-c-api.patch
        fix-cmake-vcpkg.patch
        fix-sources.patch
        fix-source-abseil.patch
        fix-source-apple-opencl.patch
)

file(REMOVE_RECURSE
    "${SOURCE_PATH}/third_party/eigen3"
    # "${SOURCE_PATH}/third_party/xla" # create openxla-xla in future?
)
file(COPY "${CURRENT_INSTALLED_DIR}/include/eigen3" DESTINATION "${SOURCE_PATH}/third_party")

find_program(FLATC NAMES flatc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
# see https://flatbuffers.dev/flatbuffers_guide_using_schema_compiler.html
message(STATUS "Using flatc: ${FLATC}")

find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
# see https://protobuf.dev/overview/#syntax
message(STATUS "Using protoc: ${PROTOC}")

# Run codegen with existing .fbs, .proto files
set(TENSORFLOW_SOURCE_DIR "${SOURCE_PATH}")
set(TFLITE_SOURCE_DIR "${SOURCE_PATH}/tensorflow/lite")

set(ACCELERATION_CONFIGURATION_PATH "${TFLITE_SOURCE_DIR}/acceleration/configuration")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --proto configuration.proto
    LOGNAME codegen-flatc-configuration
    WORKING_DIRECTORY "${ACCELERATION_CONFIGURATION_PATH}"
)
# see ${ACCELERATION_CONFIGURATION_PATH}/BUILD
vcpkg_replace_string("${ACCELERATION_CONFIGURATION_PATH}/configuration.fbs" "tflite.proto" "tflite")

vcpkg_execute_required_process(
    COMMAND ${PROTOC} --cpp_out . configuration.proto
    LOGNAME codegen-protoc-configuration
    WORKING_DIRECTORY "${ACCELERATION_CONFIGURATION_PATH}"
)
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --gen-compare configuration.fbs
    LOGNAME codegen-flatc-cpp-configuration
    WORKING_DIRECTORY "${ACCELERATION_CONFIGURATION_PATH}"
)

set(SCHEMA_PATH "${TFLITE_SOURCE_DIR}/schema")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --gen-mutable --gen-object-api schema.fbs
    LOGNAME codegen-flatc-schema
    WORKING_DIRECTORY "${SCHEMA_PATH}"
)
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp conversion_metadata.fbs
    LOGNAME codegen-flatc-conversion_metadata
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
        COMMAND ${FLATC} --cpp --scoped-enums common.fbs metadata.fbs workgroups.fbs compiled_model.fbs
        LOGNAME codegen-flatc-cpp-gl-common
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
        # gpu     TFLITE_ENABLE_GLES3
)

if(VCPKG_TARGET_IS_LINUX OR VCPKG_TARGET_IS_ANDROID)
    list(APPEND FEATURE_OPTIONS -DTFLITE_ENABLE_MMAP=ON)
else()
    list(APPEND FEATURE_OPTIONS -DTFLITE_ENABLE_MMAP=OFF)
endif()
if(VCPKG_TARGET_IS_ANDROID OR VCPKG_TARGET_IS_WINDOWS)
    if("gpu" IN_LIST FEATURES)
        list(APPEND FEATURE_OPTIONS -DTFLITE_ENABLE_GLES3=ON)
    endif()
else()
    list(APPEND FEATURE_OPTIONS -DTFLITE_ENABLE_GLES3=OFF)
endif()

if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    list(APPEND GENERATOR_OPTIONS GENERATOR Xcode)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/tensorflow/lite"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        -DSYSTEM_PTHREADPOOL=ON
        -DTFLITE_ENABLE_RESOURCE=ON
        -DTFLITE_ENABLE_RUY=ON
        -DTFLITE_ENABLE_XNNPACK=ON
        -DTFLITE_ENABLE_NNAPI=${VCPKG_TARGET_IS_ANDROID}
        -DTFLITE_ENABLE_EXTERNAL_DELEGATE=ON
        -DTFLITE_ENABLE_INSTALL=ON
        -DTENSORFLOW_SOURCE_DIR:PATH="${SOURCE_PATH}"
        -DFLATBUFFERS_FLATC_EXECUTABLE:FILEPATH="${FLATC}"
    OPTIONS_DEBUG
        -DTFLITE_ENABLE_NNAPI_VERBOSE_VALIDATION=${VCPKG_TARGET_IS_ANDROID}
    MAYBE_UNUSED_VARIABLES
        FLATBUFFERS_FLATC_EXECUTABLE
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/${PORT}")

file(INSTALL "${SOURCE_PATH}/tensorflow/core/public/version.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include/tensorflow/core/public")

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

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
