if(NOT VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

# check https://github.com/tensorflow/tensorflow/pull/61381
# vcpkg_download_distfile(TENSORFLOW_PR_61381_PATCH
#     URLS "https://github.com/tensorflow/tensorflow/pull/61381.diff?full_index=1"
#     FILENAME tensorflow-pr-61381.patch  SHA512 0
# )

# check https://github.com/tensorflow/tensorflow/pull/62037
# vcpkg_download_distfile(TENSORFLOW_PR_62037_PATCH
#     URLS "https://github.com/tensorflow/tensorflow/pull/62037.diff?full_index=1"
#     FILENAME tensorflow-pr-62037.patch  SHA512 0
# )

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.16.1
    SHA512 6f02261b3e72b476a3adb8e47efe2bee76b8564315b853e3b16f443193204d363b5fb22ac5c388cebd6a1f326f0daf00586e0ccbf6a305d761a9266534fde13f
    PATCHES
        tensorflow-pr-61381.patch
        tensorflow-pr-62037.patch
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
)

if(VCPKG_TARGET_IS_LINUX OR VCPKG_TARGET_IS_ANDROID)
    list(APPEND FEATURE_OPTIONS -DTFLITE_ENABLE_MMAP=ON)
else()
    list(APPEND FEATURE_OPTIONS -DTFLITE_ENABLE_MMAP=OFF)
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    # Visual Studio with ClangCL?
    set(VCPKG_PLATFORM_TOOLSET ClangCL) # CMAKE_GENERATOR_TOOLSET
    # sadly, we can't build well with the toolset. use MSVC even if the upstream uses ClangCL
    unset(VCPKG_PLATFORM_TOOLSET)
    set(GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
elseif(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
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
        "-DTENSORFLOW_SOURCE_DIR:PATH=${SOURCE_PATH}"
        "-DFLATBUFFERS_FLATC_EXECUTABLE:FILEPATH=${FLATC}"
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
