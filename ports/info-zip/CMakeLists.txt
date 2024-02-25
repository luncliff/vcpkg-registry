cmake_minimum_required(VERSION 3.13)
project(zip VERSION 3.0 LANGUAGES C)

include(GNUInstallDirs)

set(CMAKE_C_STANDARD 11)

list(APPEND headers
    api.h
    crc32.h
    crypt.h
    ebcdic.h
    revision.h
    tailor.h
    timezone.h
    ttyio.h
    zip.h
    ziperr.h
)

add_library(zip STATIC
    ${headers}
    api.c
    crc32.c
    crypt.c
    # deflate.c
    fileio.c
    globals.c
    timezone.c
    # trees.c
    # ttyio.c
    # util.c
    # zbz2err.c
    # zip.c
    # zipcloak.c
    # zipfile.c
    # zipnote.c
    # zipsplit.c
    # zipup.c
)

set_target_properties(zip
PROPERTIES
    PUBLIC_HEADER "${headers}"
)

target_compile_definitions(zip PRIVATE
    UTIL DYNAMIC_CRC_TABLE
)

if(UNIX)
    target_compile_definitions(zip PRIVATE MMAP)
else()
    # target_compile_definitions(zip PRIVATE NO_UNISTD_H)
endif()

if(WIN32)
    target_compile_definitions(zip PRIVATE
        WINDLL W32_USE_IZ_TIMEZONE IZTZ_DEFINESTDGLOBALS
        _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_DEPRECATE
    )
endif()

if(BUILD_SHARED_LIBS)
    target_compile_definitions(zip PRIVATE ZIP_DLL)
endif()

find_package(BZip2)
if(BZip2_FOUND)
    target_compile_definitions(zip PRIVATE BZIP2_SUPPORT)
    target_link_libraries(zip PRIVATE BZip2::BZip2)
endif()

find_package(ZLIB REQUIRED)
if(ZLIB_FOUND)
    target_compile_definitions(zip PRIVATE USE_ZLIB)
    target_link_libraries(zip PRIVATE ZLIB::ZLIB)
endif()

install(TARGETS zip
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}
)
