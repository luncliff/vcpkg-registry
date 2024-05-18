# choco install zip
find_program(ZIP NAMES zip REQUIRED)
message(STATUS "Using zip: ${ZIP}")

find_program(BASH NAMES bash REQUIRED)
message(STATUS "Using bash: ${BASH}")

find_program(MAKE NAMES make REQUIRED)
message(STATUS "Using make: ${MAKE}")

# OpenJDK 21 from https://learn.microsoft.com/en-us/java/openjdk/download
vcpkg_download_distfile(MICROSOFT_JDK_21_PATH
    URLS "https://aka.ms/download-jdk/microsoft-jdk-21.0.2-linux-x64.tar.gz"
    FILENAME microsoft-jdk-21.0.2-linux-x64.tar.gz
    SHA512 3e94145d956558184c23023e84486337e853901953b5b927162ddd039529ebfd8ef664491dda1573c5ca4d3d3d8161fffaef8630702dd3a2b706212ab1405da3
)
file(ARCHIVE_EXTRACT INPUT "${MICROSOFT_JDK_21_PATH}" DESTINATION "${CURRENT_BUILDTREES_DIR}")
get_filename_component(BOOTJDK_PATH "${CURRENT_BUILDTREES_DIR}/jdk-21.0.2+13" ABSOLUTE)

list(APPEND CONFIG_TOOLCHAIN_OPTIONS
    "--with-toolchain-type=gcc"
    "--with-stdc++lib=${VCPKG_CRT_LINKAGE}" # dynamic, static, default        
)
