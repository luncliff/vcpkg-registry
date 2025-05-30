if(NOT VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v${VERSION}
    SHA512 f9647621c93b6a7d3c43d92b7cfa0ec481de0f43e4936c0d946e305b440aa1caa72a48cbf4ccef7efc270f1e6d7926c2c327dfd2af9f649707e52bb10bd86235
    PATCHES
        fix-cmake-vcpkg.patch
        fix-cmake-c-api.patch
        fix-includes.patch
        disable-android-gl-delegates.patch
)

file(REMOVE_RECURSE
    "${SOURCE_PATH}/third_party/eigen3"
    # "${SOURCE_PATH}/third_party/xla" # create openxla-xla in future?
)
file(COPY "${CURRENT_INSTALLED_DIR}/include/eigen3" DESTINATION "${SOURCE_PATH}/third_party")

find_program(FLATC NAMES flatc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
message(STATUS "Using flatc: ${FLATC}")

function(codegen_flatc_cpp) # https://flatbuffers.dev/flatc/
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "DIRECTORY;LOGNAME" "SOURCES;FLATC_ARGS")
    vcpkg_execute_required_process(
        COMMAND "${FLATC}" --cpp ${arg_FLATC_ARGS} ${arg_SOURCES}
        LOGNAME "${arg_LOGNAME}"
        WORKING_DIRECTORY "${arg_DIRECTORY}"
    )
endfunction()

find_program(PROTOC NAMES protoc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
message(STATUS "Using protoc: ${PROTOC}")

function(codegen_protoc) # https://protobuf.dev/reference/cpp/cpp-generated/
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "DIRECTORY;LOGNAME" "SOURCES")
    vcpkg_execute_required_process(
        COMMAND "${PROTOC}" --cpp_out . ${arg_SOURCES}
        LOGNAME "${arg_LOGNAME}"
        WORKING_DIRECTORY "${arg_DIRECTORY}"
    )
endfunction()

# Run codegen with existing .fbs, .proto files
set(TENSORFLOW_SOURCE_DIR "${SOURCE_PATH}")
set(TFLITE_SOURCE_DIR "${SOURCE_PATH}/tensorflow/lite")

# see ${ACCELERATION_CONFIGURATION_PATH}/BUILD
set(ACCELERATION_CONFIGURATION_PATH "${TFLITE_SOURCE_DIR}/acceleration/configuration")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --proto configuration.proto
    LOGNAME codegen-flatc-configuration
    WORKING_DIRECTORY "${ACCELERATION_CONFIGURATION_PATH}"
)
vcpkg_replace_string("${ACCELERATION_CONFIGURATION_PATH}/configuration.fbs" "tflite.proto" "tflite")

codegen_protoc(
    DIRECTORY "${ACCELERATION_CONFIGURATION_PATH}"
    SOURCES configuration.proto
    LOGNAME codegen-protoc-configuration
)
codegen_flatc_cpp(
    DIRECTORY "${ACCELERATION_CONFIGURATION_PATH}"
    SOURCES configuration.fbs
    FLATC_ARGS --gen-compare
    LOGNAME codegen-flatc-configuration
)

codegen_flatc_cpp(
    DIRECTORY "${TFLITE_SOURCE_DIR}/stablehlo/schema"
    SOURCES schema.fbs
    FLATC_ARGS --gen-mutable --gen-object-api
    LOGNAME codegen-flatc-stablehlo
)

# ${SOURCE_PATH}/tensorflow/compiler/mlir/lite/schema
codegen_flatc_cpp(
    DIRECTORY "${TENSORFLOW_SOURCE_DIR}/tensorflow/compiler/mlir/lite/schema"
    SOURCES schema.fbs
            schema_v0.fbs
            schema_v1.fbs
            schema_v2.fbs
            schema_v3.fbs
            schema_v3a.fbs
            schema_v3b.fbs
            schema_v3c.fbs
            conversion_metadata.fbs
            debug_metadata.fbs
    FLATC_ARGS --gen-mutable --gen-object-api
    LOGNAME codegen-flatc-schema
)

codegen_flatc_cpp(
    DIRECTORY "${TFLITE_SOURCE_DIR}/delegates/xnnpack"
    SOURCES weight_cache_schema.fbs
    FLATC_ARGS --gen-mutable --gen-object-api
    LOGNAME codegen-flatc-xnnpack
)

codegen_flatc_cpp(
    DIRECTORY "${TFLITE_SOURCE_DIR}/delegates/gpu/common/task"
    SOURCES serialization_base.fbs
    FLATC_ARGS --scoped-enums
    LOGNAME codegen-flatc-serialization_base
)

codegen_flatc_cpp(
    DIRECTORY "${TFLITE_SOURCE_DIR}/delegates/gpu/common"
    SOURCES gpu_model.fbs
    FLATC_ARGS --scoped-enums -I "${TENSORFLOW_SOURCE_DIR}"
    LOGNAME codegen-flatc-gpu_model
)

codegen_flatc_cpp(
    DIRECTORY "${TFLITE_SOURCE_DIR}/delegates/gpu/cl"
    SOURCES compiled_program_cache.fbs
            serialization.fbs
    FLATC_ARGS --scoped-enums -I "${TENSORFLOW_SOURCE_DIR}"
    LOGNAME codegen-flatc-cl
)

if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    codegen_flatc_cpp(
        DIRECTORY "${TFLITE_SOURCE_DIR}/delegates/gpu/metal"
        SOURCES inference_context.fbs
        FLATC_ARGS --scoped-enums -I "${TENSORFLOW_SOURCE_DIR}"
        LOGNAME codegen-flatc-metal
    )
else()
    codegen_flatc_cpp(
        DIRECTORY "${TFLITE_SOURCE_DIR}/delegates/gpu/gl"
        SOURCES common.fbs
                metadata.fbs
                workgroups.fbs
                compiled_model.fbs
        FLATC_ARGS --scoped-enums
        LOGNAME codegen-flatc-gl
    )
endif()

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
    if((VCPKG_TARGET_ARCHITECTURE STREQUAL "arm") OR (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64"))
        # We have to locate LLVM/ARM64/bin/clang-cl.exe and its forks, but too complicated for now
        unset(VCPKG_PLATFORM_TOOLSET)
    endif()
    set(GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
    # temporary disable ClangCL build to workaround intrinsic build error
    unset(VCPKG_PLATFORM_TOOLSET)
    unset(GENERATOR_OPTIONS)
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
        -DTFLITE_C_OUTPUT_NAME=${PORT} # see fix-cmake-c-api.patch
        -DCMAKE_CROSSCOMPILING=${VCPKG_CROSSCOMPILING}
        "-DTFLITE_HOST_TOOLS_DIR:PATH=${CURRENT_HOST_INSTALLED_DIR}/tools"        
        "-DFLATC_BIN:FILEPATH=${FLATC}"
        "-DFLATBUFFERS_FLATC_EXECUTABLE:FILEPATH=${FLATC}"
        "-DTENSORFLOW_SOURCE_DIR:PATH=${SOURCE_PATH}"
    OPTIONS_DEBUG
        -DTFLITE_ENABLE_NNAPI_VERBOSE_VALIDATION=${VCPKG_TARGET_IS_ANDROID}
    MAYBE_UNUSED_VARIABLES
        TFLITE_HOST_TOOLS_DIR
        FLATC_BIN
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/${PORT}" PACKAGE_NAME tensorflow-lite)

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
