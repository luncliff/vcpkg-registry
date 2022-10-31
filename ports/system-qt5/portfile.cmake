if(NOT TARGET_TRIPLET STREQUAL _HOST_TRIPLET)
    message(WARNING "system-qt5 is a host-only port; please mark it as a host port in your dependencies.")
endif()

if(DEFINED ENV{Qt5_DIR})
    set(Qt5_DIR "$ENV{Qt5_DIR}")
elseif(DEFINED ENV{QTDIR})
    set(Qt5_DIR "$ENV{QTDIR}")
elseif(NOT DEFINED Qt5_DIR)
    message(WARNING
        "Requires Qt5_DIR. "
        " set(\"C:/Qt/5.15.2/msvc2019_64/lib/cmake/Qt5\") or"
        " set(\"/Users/user/Qt/5.15.2/clang_64/lib/cmake/Qt5\")"
        " in your triplet"
    )
    message(FATAL_ERROR "Please define Qt5_DIR variable in the triplet.")
endif()
message(STATUS "Using Qt5: ${Qt5_DIR}")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/qt5_make_path_options.cmake"
             "${CMAKE_CURRENT_LIST_DIR}/vcpkg-port-config.cmake"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
