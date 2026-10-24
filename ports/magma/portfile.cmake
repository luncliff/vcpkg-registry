vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
  URLS https://icl.utk.edu/projectsfiles/magma/downloads/magma-${VERSION}.tar.gz
  FILENAME magma-${VERSION}.tar.gz
  SHA512 7262cdfa70f5ffb20f2297fe520bdc7a3ac8f60ccb195542147234289bd23cbeb7cfb6983459d301d9a7f25b63a4f8e513380ce1d3fcd9d95e8eb9a108b7299e
)

vcpkg_extract_source_archive(SOURCE_PATH
  ARCHIVE "${ARCHIVE}"
  PATCHES
    fix-no-tests.patch
    clang-cuda.patch
    fix-cuda13-preprocessor.patch
    fix-cuda13-cpp17.patch
)
vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_toolkit_root)

if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
  list(APPEND PLATFORM_OPTIONS
    -DCMAKE_CUDA_SEPARABLE_COMPILATION:BOOL=OFF
  )
endif()

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    "-DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=${VCPKG_TARGET_IS_WINDOWS}"
    -DMAGMA_ENABLE_CUDA=ON
    -DMAGMA_ENABLE_HIP=OFF
    -DUSE_FORTRAN=OFF
    -DCMAKE_CUDA_STANDARD=17
    "-DCMAKE_CUDA_COMPILER:FILEPATH=${NVCC}"
    "-DCUDAToolkit_ROOT=${cuda_toolkit_root}"
    ${PLATFORM_OPTIONS}
)
vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()

file(READ "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/magma.pc" contents)
string(REGEX REPLACE "Cflags: [^\n]+" "Cflags: -I\${includedir}" contents "${contents}")
file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/magma.pc" "${contents}")

if(NOT VCPKG_BUILD_TYPE)
  file(READ "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/magma.pc" contents)
  string(REGEX REPLACE "Cflags: [^\n]+" "Cflags: -I\${includedir}" contents "${contents}")
  file(WRITE "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/magma.pc" "${contents}")
endif()

file(REMOVE_RECURSE
  "${CURRENT_PACKAGES_DIR}/debug/include"
  "${CURRENT_PACKAGES_DIR}/debug/share"
)
file(INSTALL "${SOURCE_PATH}/ReleaseNotes" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYRIGHT")
