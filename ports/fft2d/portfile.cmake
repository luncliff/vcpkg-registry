vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO petewarden/OouraFFT
    REF v1.0
    SHA512 89c6e8fd57abf26351b3efb792008a1bbe62d404a4225dcae8aa666b3782a421be071bdc9760ebb0c95b5336ee5ea517d2fa43ab915045f7cf6fd76e73578079
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/${PORT}")

vcpkg_download_distfile(FFT2D_HEADER_1
    URLS "https://raw.githubusercontent.com/tensorflow/tensorflow/v2.7.0/third_party/fft2d/fft.h"
    FILENAME tensorflow-fft2d-header-1.txt
    SHA512 afaa5baf9c26d713ae02f3a1ee06d87bedd5a902d1d2a41c0e637aa205442647ba29908f86965d22015da13ac98a5c6f16d6febe8d7040a954eadc335158047a
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/fft2d/fft.h")
file(INSTALL "${FFT2D_HEADER_1}" DESTINATION "${CURRENT_PACKAGES_DIR}/include/fft2d" RENAME "fft.h")

vcpkg_download_distfile(FFT2D_HEADER_2
    URLS "https://raw.githubusercontent.com/tensorflow/tensorflow/v2.7.0/third_party/fft2d/fft2d.h"
    FILENAME tensorflow-fft2d-header-2.txt
    SHA512 f4c581619882a819ed116053165cc0d6f8546b6229a3c56a6077ca939d982b306c50973723c04107985fcd0fb177e76fc78f9ca774a0173e5aacbad38e3fc394
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/fft2d/fft2d.h")
file(INSTALL "${FFT2D_HEADER_2}" DESTINATION "${CURRENT_PACKAGES_DIR}/include/fft2d" RENAME "fft2d.h")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${SOURCE_PATH}/readme.txt"   DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/readme2d.txt")
