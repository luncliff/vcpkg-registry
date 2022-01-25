
# Currently links with an internal library 'fft2d'
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tensorflow/tensorflow
    REF v2.6.1
    SHA512 34dcec08b73ef25cb6e5bcb0e083c2f43d8364bc9a465e59d63dc3f162a129d011e03faaecf7d563cbbe39f0c2bbf2d1795ccfb8b2ea3f108ed8db992cea9475
    PATCHES
        fix-cmakelists.patch
        fix-gpu-build-windows.patch
        fix-eigen3-import.patch
)

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
    if(NOT VCPKG_TARGET_IS_OSX)
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/coreml")
    endif()
    if(NOT VCPKG_TARGET_IS_ANDROID)
        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/nnapi"
                            "${CURRENT_PACKAGES_DIR}/include/tensorflow/lite/delegates/nnapi"
        )
    endif()
endif()
