cmake_minimum_required(VERSION 3.8)
project(lua LANGUAGES C CXX VERSION ${LUA_VERSION})

option(BUILD_FOR_CXX    "Build for C++" OFF)
option(BUILD_TOOLS      "Build Lua interpreter / compiler" OFF)

include(GNUInstallDirs)

add_library(lua
    src/lapi.h src/lauxlib.h src/lcode.h src/lctype.h src/ldebug.h src/ldo.h src/lfunc.h
    src/lgc.h src/llex.h src/llimits.h src/lmem.h src/lobject.h src/lopcodes.h src/lparser.h
    src/lstate.h src/lstring.h src/ltable.h src/ltm.h src/lua.h src/luaconf.h src/lualib.h
    src/lundump.h src/lvm.h src/lzio.h
)

list(APPEND headers
    src/lualib.h
    src/lua.h
    src/luaconf.h
    src/lauxlib.h
)
if(NOT BUILD_FOR_CXX)
    list(APPEND headers src/lua.hpp) # extern "C" wrapper
endif()

set_target_properties(lua
PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    PUBLIC_HEADER "${headers}"
)

target_include_directories(lua
PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

list(APPEND sources
    src/lapi.c src/lauxlib.c src/lbaselib.c src/lbitlib.c src/lcode.c src/lcorolib.c
    src/lctype.c src/ldblib.c src/ldebug.c src/ldo.c src/ldump.c src/lfunc.c src/lgc.c
    src/linit.c src/liolib.c src/llex.c src/lmathlib.c src/lmem.c src/loadlib.c src/lobject.c
    src/lopcodes.c src/loslib.c src/lparser.c src/lstate.c src/lstring.c src/lstrlib.c
    src/ltable.c src/ltablib.c src/ltm.c src/lundump.c src/lutf8lib.c src/lvm.c src/lzio.c
)
target_sources(lua
PRIVATE
    ${sources}
)

if(BUILD_FOR_CXX)
    set_target_properties(lua
    PROPERTIES
        CXX_STANDARD 11
    )
    set_source_files_properties(${sources}
    PROPERTIES
        LANGUAGE CXX
    )
else()
    set_target_properties(lua
    PROPERTIES
        C_STANDARD 11
    )
endif()

if(WIN32)
    target_compile_definitions(lua
    PRIVATE
        _CRT_SECURE_NO_WARNINGS
    )
    if(BUILD_SHARED_LIBS)
        target_compile_definitions(lua
        PUBLIC
            LUA_BUILD_AS_DLL
        )
    endif()
else()
    target_compile_definitions(lua
    PRIVATE
        LUA_USE_DLOPEN
    )
    target_link_libraries(lua
    PRIVATE
        ${CMAKE_DL_LIBS}
    )
endif()

if(UNIX OR ANDROID)
    find_library(LIB_MATH NAMES m)
    if(LIB_MATH)
        target_link_libraries(lua
        PRIVATE
            ${LIB_MATH}
        )
    endif()
endif()

install(TARGETS lua
        EXPORT lua-config
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
install(EXPORT lua-config
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/${PROJECT_NAME}
)

include(CMakePackageConfigHelpers)
set(VERSION_FILE_PATH   ${CMAKE_BINARY_DIR}/cmake/lua-config-version.cmake)
write_basic_package_version_file(${VERSION_FILE_PATH}
    VERSION         ${PROJECT_VERSION}
    COMPATIBILITY   SameMinorVersion
)
install(FILES   ${VERSION_FILE_PATH} 
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/${PROJECT_NAME}
)

if(BUILD_TOOLS)
    if(BUILD_FOR_CXX)
        set_source_files_properties(src/luac.c src/lua.c
        PROPERTIES
            LANGUAGE CXX
        )
    endif()
    # compiler. uses non-exported APIs
    add_executable(luac src/luac.c)
    target_include_directories(luac
    PRIVATE
        src
    )
    target_link_libraries(luac
    PRIVATE
        lua
    )
    # interpreter
    add_executable(luai src/lua.c)
    target_link_libraries(luai
    PRIVATE
        lua
    )
    if(UNIX)
        if(CMAKE_SYSTEM_NAME STREQUAL FreeBSD)
            find_library(LIB_READLINE NAMES edit)
            target_include_directories(luai
            PRIVATE
                /usr/include/edit
            )
        else()
            find_library(LIB_READLINE NAMES readline)
        endif()
        if(LIB_READLINE)
            target_compile_definitions(luai
            PRIVATE
                LUA_USE_READLINE
            )
            target_link_libraries(luai
            PRIVATE
                ${LIB_READLINE}
            )
        endif()
    endif()
    install(TARGETS luai luac
            RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/tools/${PROJECT_NAME}
    )
endif()
