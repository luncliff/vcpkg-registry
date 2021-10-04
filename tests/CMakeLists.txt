cmake_minimum_required(VERSION 3.19)
project(registry_test)

find_package(PkgConfig REQUIRED)

get_filename_component(REGISTRTY_SCRIPT_PATH ${PROJECT_SOURCE_DIR} PATH)
get_filename_component(REGISTRTY_SCRIPT_PATH ${REGISTRTY_SCRIPT_PATH}/scripts ABSOLUTE)
message(STATUS "Using scripts: ${REGISTRTY_SCRIPT_PATH}")

list(APPEND CMAKE_MODULE_PATH
    ${REGISTRTY_SCRIPT_PATH}
)

if(WIN32)
    # scripts/
    find_package(QtANGLE)

    # ports/
    # todo: add some `find_package` for the ports ...

else()
    # ports/
    # todo: add some `find_package` for the ports ...

endif()
