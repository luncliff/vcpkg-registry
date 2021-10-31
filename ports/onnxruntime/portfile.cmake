
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF v1.9.1
    SHA512 66c4bff4c4f633885ba7d0601337d0f16c0eeef7e3c1f492f2d21f27f06f748260e28105083b5defbebf624f4f26dc59355de7e3e0ef81c6c27b01b936a98ce9
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        training onnxruntime_ENABLE_TRAINING
        training onnxruntime_ENABLE_TRAINING_OPS
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DBUILD_PKGCONFIG_FILES=ON
        -Donnxruntime_PREFER_SYSTEM_LIB=ON
        -Donnxruntime_USE_EXTENSIONS=OFF
        -Donnxruntime_USE_MPI=${VCPKG_TARGET_IS_LINUX}
        -Donnxruntime_BUILD_UNIT_TESTS=OFF
        -Donnxruntime_ENABLE_PYTHON=OFF
        -Donnxruntime_USE_FULL_PROTOBUF=ON
        -Donnxruntime_USE_PREINSTALLED_EIGEN=ON
    OPTIONS_DEBUG
        -Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
)
vcpkg_cmake_install()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)
vcpkg_cmake_config_fixup(CONFIG_PATH "share/${PORT}")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${SOURCE_PATH}/LICENSE"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)
