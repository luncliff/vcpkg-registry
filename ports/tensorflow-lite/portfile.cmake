vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.8.0
    SHA512 9cddb78c0392b7810e71917c3731f895e31c250822031ac7f498bf20435408c640b2fba4de439fa4a47c70dbff38b86e50fed2971df1f1916f23f9490241cfed
    PATCHES
        fix-cmake.patch
        fix-cmake-gpu.patch
        fix-source-gpu.patch
)
file(REMOVE_RECURSE "${SOURCE_PATH}/third_party/eigen3")
file(CREATE_LINK "${CURRENT_INSTALLED_DIR}/include/eigen3" "${SOURCE_PATH}/third_party/eigen3" SYMBOLIC)

if("gpu" IN_LIST FEATURES)
    find_program(FLATC_EXECUTABLE NAMES flatc PATHS ${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
    message(STATUS "Using flatc: ${FLATC_EXECUTABLE}")
    find_program(PROTOC_EXECUTABLE NAMES protoc PATHS ${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
    message(STATUS "Using protoc: ${PROTOC_EXECUTABLE}")
    list(APPEND PLATFORM_OPTIONS
        -DFLATC_EXECUTABLE:FILE_PATH=${FLATC_EXECUTABLE}
        -DPROTOC_EXECUTABLE:FILE_PATH=${PROTOC_EXECUTABLE}
    )
    if(VCPKG_TARGET_IS_OSX) # .proto files for coreml_mlmodel_codegen
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
    OPTIONS_DEBUG
        -DTFLITE_ENABLE_NNAPI_VERBOSE_VALIDATION=${VCPKG_TARGET_IS_ANDROID}
    MAYBE_UNUSED_VARIABLES
        COREML_SOURCE_DIR
        FLATC_EXECUTABLE
        PROTOC_EXECUTABLE
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
