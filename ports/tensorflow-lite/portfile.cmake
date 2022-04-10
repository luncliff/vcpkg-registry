
# Currently links with an internal library 'fft2d'
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.7.1
    SHA512 d818f4c2640dd8240cf66c4c64d79fa90508b5c4af3c2e2905b0535fb0fe9c70d3495d8d1e74f7e92c6c6e986ad70855e31147516811a4800a412a927cb398ea
    PATCHES
        fix-cmakelists.patch
        fix-gpu-build.patch
        fix-gpu-source.patch
)
file(REMOVE_RECURSE "${SOURCE_PATH}/third_party/eigen3")
file(CREATE_LINK "${CURRENT_INSTALLED_DIR}/include/eigen3" "${SOURCE_PATH}/third_party/eigen3" SYMBOLIC)

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
