vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
  URLS https://icl.utk.edu/projectsfiles/magma/downloads/magma-${VERSION}.tar.gz
  FILENAME magma-${VERSION}.tar.gz
  SHA512 233beb3d2809c12a27a9b7a6a0eb0bec0ade91fa6bf1a63e1ca4d491491ed5a8729996ac8fbf68ab8d678acab6ed56b7728689358a7b76b20b101227a9851c16
)

vcpkg_extract_source_archive(SOURCE_PATH
  ARCHIVE "${ARCHIVE}"
  PATCHES
    fix-cmake4.patch
    fix-no-tests.patch
    fix-pkgconfig.patch
    fix-cuda13.patch
)
vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_toolkit_root) 

if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
  list(APPEND PLATFORM_OPTIONS
    -DCMAKE_CUDA_SEPARABLE_COMPILATION:BOOL=OFF
  )
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
  FEATURES
    openmp  CMAKE_DISABLE_FIND_PACKAGE_OpenMP
    fortran USE_FORTRAN
)


vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    "-DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=${VCPKG_TARGET_IS_WINDOWS}"
    -DMAGMA_ENABLE_CUDA=ON
    -DMAGMA_ENABLE_HIP=OFF
    "-DCMAKE_CUDA_COMPILER:FILEPATH=${NVCC}"
    "-DCUDAToolkit_ROOT=${cuda_toolkit_root}"
    ${PLATFORM_OPTIONS}
    ${FEATURE_OPTIONS}
)
vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()

# file(READ "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/magma.pc" contents)
# string(REGEX REPLACE "Cflags: [^\n]+" "Cflags: -I\${includedir}" contents "${contents}")
# file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/magma.pc" "${contents}")

# if(NOT VCPKG_BUILD_TYPE)
#   file(READ "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/magma.pc" contents)
#   string(REGEX REPLACE "Cflags: [^\n]+" "Cflags: -I\${includedir}" contents "${contents}")
#   file(WRITE "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/magma.pc" "${contents}")
# endif()

file(REMOVE_RECURSE
  "${CURRENT_PACKAGES_DIR}/debug/include"
  "${CURRENT_PACKAGES_DIR}/debug/share"
)
file(INSTALL "${SOURCE_PATH}/ReleaseNotes" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYRIGHT")
