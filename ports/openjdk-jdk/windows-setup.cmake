# choco install zip
find_program(ZIP NAMES zip PATHS "C:/ProgramData/chocolatey/bin" REQUIRED)
message(STATUS "Using zip: ${ZIP}")
get_filename_component(ZIP_PATH "${ZIP}" PATH)
vcpkg_add_to_path(PREPEND "${ZIP_PATH}")

# vcpkg_acquire_msys(MSYS_ROOT PACKAGES bash autoconf make gzip unzip ..)
vcpkg_acquire_msys(MSYS_ROOT Z_ALL_PACKAGES)
vcpkg_add_to_path(PREPEND "${MSYS_ROOT}")
vcpkg_add_to_path(PREPEND "${MSYS_ROOT}/usr/bin")
find_program(BASH NAMES bash PATHS "${MSYS_ROOT}/usr/bin" REQUIRED NO_DEFAULT_PATH)
message(STATUS "Using bash: ${BASH}")

find_program(MAKE NAMES make PATHS "${MSYS_ROOT}/usr/bin" REQUIRED NO_DEFAULT_PATH)
message(STATUS "Using make: ${MAKE}")

# OpenJDK 21 from https://learn.microsoft.com/en-us/java/openjdk/download
vcpkg_download_distfile(MICROSOFT_JDK_21_PATH
    URLS "https://aka.ms/download-jdk/microsoft-jdk-21.0.2-windows-x64.zip"
    FILENAME microsoft-jdk-21.0.2-windows-x64.zip
    SHA512 e31c8d3fb6ff7e894b47b7faac3e1c13b959055dadba5f42025af541bf5ea7614b7088266e23d8774dcb7ea293d32f38378e59a6b79a9200e1502fa05f46d888
)
file(ARCHIVE_EXTRACT INPUT "${MICROSOFT_JDK_21_PATH}" DESTINATION "${CURRENT_BUILDTREES_DIR}")
get_filename_component(BOOTJDK_PATH "${CURRENT_BUILDTREES_DIR}/jdk-21.0.2+13" ABSOLUTE)

list(APPEND CONFIG_TOOLCHAIN_OPTIONS
    "--with-toolchain-type=microsoft"
)
