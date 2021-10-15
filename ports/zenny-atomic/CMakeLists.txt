project(stdatomic LANGUAGES C)
include(GNUInstallDirs)

set(CMAKE_C_STANDARD 11)

add_library(zenny_atomic stdatomic.h stdatomic.c)

set_target_properties(zenny_atomic
PROPERTIES
    PUBLIC_HEADER stdatomic.h
)

install(TARGETS zenny_atomic
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
