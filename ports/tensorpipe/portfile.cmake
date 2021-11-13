vcpkg_fail_port_install(ON_TARGET "windows" "uwp")
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/tensorpipe
    REF d2aa3485e8229c98891dfd604b514a39d45a5c99
    SHA512 fbefc18792458ac2234045df8e3cce8dbb17a5e719258f020c2c1d388092358bd2562e53a0377ca18f40bcfbeae4367c277a74c31c5e45296b891453a962e460
    PATCHES
        fix-cmakelists.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/TensorpipeConfig.cmake.in" DESTINATION "${SOURCE_PATH}/cmake")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        cuda        TP_USE_CUDA
        cuda        TP_ENABLE_CUDA_IPC
        pybind11    TP_BUILD_PYTHON
)

if("pybind11" IN_LIST FEATURES)
    vcpkg_find_acquire_program(PYTHON3)
    list(APPEND FEATURE_OPTIONS -DPYTHON_EXECUTABLE=${PYTHON3})
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DTP_ENABLE_SHM=${VCPKG_TARGET_IS_LINUX}
        -DTP_ENABLE_IBV=OFF
        -DTP_ENABLE_CMA=OFF
        -DTP_BUILD_LIBUV=OFF # will use libuv package
        -DTP_ENABLE_CUDA_GDR=OFF
        -DTP_BUILD_TESTING=OFF
    MAYBE_UNUSED_VARIABLES
        TP_ENABLE_CUDA_GDR
        TP_ENABLE_CUDA_IPC
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/cmake/Tensorpipe")

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
)
