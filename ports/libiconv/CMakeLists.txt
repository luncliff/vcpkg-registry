cmake_minimum_required(VERSION 3.21)
project(libiconv VERSION 1.17 LANGUAGES C)
set(CMAKE_C_STANDARD 11)

include(GNUInstallDirs)
include(CheckTypeSize)
include(CheckSymbolExists)
include(CheckLibraryExists)
include(CheckIncludeFile)

# header generation
check_type_size("ptrdiff_t"     SIZEOF_PTRDIFF_T)
check_type_size("sig_atomic_t"  SIZEOF_SIG_ATOMIC_T)
check_type_size("size_t"        SIZEOF_SIZE_T)
check_type_size("wchar_t"       SIZEOF_WCHAR_T)
check_type_size("wint_t"        SIZEOF_WINT_T)
check_symbol_exists("scanf"  "stdio.h" GNULIB_SCANF)
check_symbol_exists("fscanf" "stdio.h" GNULIB_FSCANF)
configure_file(config.h.in config.h @ONLY)

# set(DLL_VARIABLE ...)
# set(EILSEQ ...)
set(ICONV_CONST const)
set(HAVE_WCHAR_T 1)
set(USE_MBSTATE_T 1)
set(BROKEN_WCHAR_H 0)
configure_file(include/iconv.h.in iconv.h @ONLY)
list(APPEND headers
    ${CMAKE_CURRENT_BINARY_DIR}/iconv.h
)

configure_file(srclib/uniwidth.in.h uniwidth.h @ONLY)

check_include_file("unistd.h"       HAVE_UNISTD_H)
check_include_file("winsock2.h"     UNISTD_H_HAVE_WINSOCK2_H)
check_include_file("sys/random.h"   UNISTD_H_HAVE_SYS_RANDOM_H)

# see https://www.gnu.org/savannah-checkouts/gnu/gnulib/manual/html_node/Function-Substitutes.html
if(WIN32)
    check_symbol_exists("gethostname" "winsock2.h" GNULIB_GETHOSTNAME)
    set(UNISTD_H_HAVE_WINSOCK2_H_AND_USE_SOCKETS 1)
else()
    check_symbol_exists("gethostname" "unistd.h" GNULIB_GETHOSTNAME)
    set(UNISTD_H_HAVE_WINSOCK2_H_AND_USE_SOCKETS 0)
endif()
check_symbol_exists("symlinkat" "stdio.h"       GNULIB_SYMLINKAT)
check_symbol_exists("unlink"    "stdio.h"       GNULIB_UNLINK)
check_symbol_exists("unlinkat"  "fcntl.h"       GNULIB_UNLINKAT)
# GNULIB_GETENTROPY
check_symbol_exists("fchownat"  "sys/stat.h"    GNULIB_FCHOWNAT)
check_symbol_exists("getopt"    "getopt.h"      GNULIB_GETOPT_POSIX)
check_symbol_exists("getopt"    "unistd.h"      GNULIB_UNISTD_H_GETOPT)
check_symbol_exists("access"    "unistd.h"      GNULIB_ACCESS)
# REPLACE_ACCESS
# GNULIB_MDA_ACCESS
check_symbol_exists("chdir"     "direct.h"      GNULIB_CHDIR)
# GNULIB_MDA_CHDIR
check_symbol_exists("chown"     "direct.h"      GNULIB_CHOWN)
check_symbol_exists("close"     "io.h"          GNULIB_CLOSE)
# GNULIB_MDA_CLOSE
# GNULIB_COPY_FILE_RANGE
check_symbol_exists("dup"       "io.h"          GNULIB_DUP)
# GNULIB_MDA_DUP
check_symbol_exists("dup2"      "io.h"          GNULIB_DUP2)
# GNULIB_MDA_DUP2
# GNULIB_DUP3
check_symbol_exists("environ"   "unistd.h"      GNULIB_ENVIRON)
# GNULIB_EUIDACCESS
# GNULIB_EXECL
# GNULIB_MDA_EXECL
# GNULIB_EXECLE
# GNULIB_MDA_EXECLE
# GNULIB_EXECLP
# GNULIB_MDA_EXECLP
# GNULIB_EXECV
# GNULIB_MDA_EXECV
# GNULIB_EXECVE
# GNULIB_MDA_EXECVE
# GNULIB_EXECVP
# GNULIB_MDA_EXECVP
# GNULIB_EXECVPE
# REPLACE_EXECVPE
# GNULIB_MDA_EXECVPE
# GNULIB_FACCESSAT
# GNULIB_FCHDIR
# GNULIB_FCHOWNAT
# GNULIB_FDATASYNC
# GNULIB_FSYNC
# GNULIB_FTRUNCATE
# GNULIB_GETCWD
# REPLACE_GETCWD
# GNULIB_MDA_GETCWD
# GNULIB_GETDOMAINNAME
# REPLACE_GETDOMAINNAME
# GNULIB_GETDTABLESIZE
# REPLACE_GETDTABLESIZE
# GNULIB_GETENTROPY
# HAVE_GETENTROPY
# GNULIB_GETGROUPS
# REPLACE_GETGROUPS
# GNULIB_GETLOGIN
# GNULIB_GETLOGIN_R
# GNULIB_GETPAGESIZE
# GNULIB_GETPASS
# REPLACE_GETPASS
# HAVE_GETPASS
# GNULIB_MDA_GETPID
# GNULIB_GETUSERSHELL
# HAVE_DECL_GETUSERSHELL
# GNULIB_GROUP_MEMBER
# HAVE_GROUP_MEMBER
# GNULIB_ISATTY
# REPLACE_ISATTY
configure_file(srclib/unistd.in.h unistd.h @ONLY)

add_library(libiconv)

set_target_properties(libiconv
PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS TRUE
    PUBLIC_HEADER "${headers}"
    VERSION 1.17
    SOVERSION 1
)

target_include_directories(libiconv
PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}
    ${PROJECT_SOURCE_DIR}/src
    ${PROJECT_SOURCE_DIR}/srclib
    ${PROJECT_SOURCE_DIR}/lib
)

file(GLOB sources
    "src/*.c"
)

target_sources(libiconv PRIVATE ${sources})

install(TARGETS libiconv
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
