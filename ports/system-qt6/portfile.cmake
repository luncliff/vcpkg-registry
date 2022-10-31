if(NOT TARGET_TRIPLET STREQUAL _HOST_TRIPLET)
    message(WARNING "system-qt6 is a host-only port; please mark it as a host port in your dependencies.")
endif()

if(DEFINED ENV{Qt6_DIR})
    set(Qt6_DIR "$ENV{Qt6_DIR}")
elseif(DEFINED ENV{QTDIR})
    set(Qt6_DIR "$ENV{QTDIR}")
elseif(NOT DEFINED Qt6_DIR)
    message(WARNING
        "Requires Qt6_DIR. "
        " set(\"C:/Qt/6.3.1/msvc2019_64/lib/cmake/Qt6\") or"
        " set(\"/Users/user/Qt/6.3.1/macos/lib/cmake/Qt6\")"
        " in your triplet"
    )
    message(FATAL_ERROR "Please define Qt6_DIR variable in the triplet.")
endif()
message(STATUS "Using Qt6: ${Qt6_DIR}")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/qt6_make_path_options.cmake"
             "${CMAKE_CURRENT_LIST_DIR}/vcpkg-port-config.cmake"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
