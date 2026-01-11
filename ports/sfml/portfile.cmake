vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO SFML/SFML
    REF ${VERSION}
    SHA512 7fc3f91b84ba2353b4216c0d0a71fd15f7349b8e22630dd727fc98a1f8c295a69fe21f3e1e878413966662047280ed4f195b51ee3302061c3903aea4958a6999
    HEAD_REF master
    PATCHES
        01-fix-dependency-resolve.patch
        03-fix-android-install-path.patch
)

if(VCPKG_TARGET_IS_LINUX)
    message(STATUS "SFML currently requires the following libraries from the system package manager:\n    libudev\n    libx11\n    libxi\n    libxrandr\n    libxcursor\n    opengl\n\nThese can be installed on Ubuntu systems via apt-get install libx11-dev libxi-dev libxrandr-dev libxcursor-dev libudev-dev libgl1-mesa-dev")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DSFML_BUILD_WINDOW=ON
        -DSFML_BUILD_GRAPHICS=ON
        -DSFML_BUILD_AUDIO=ON
        -DSFML_BUILD_NETWORK=ON
        -DSFML_BUILD_FRAMEWORKS=OFF
        -DSFML_USE_SYSTEM_DEPS=ON
        -DSFML_INSTALL_PKGCONFIG_FILES=ON
        -DSFML_MISC_INSTALL_PREFIX=share/sfml
        -DSFML_GENERATE_PDB=OFF
    MAYBE_UNUSED_VARIABLES
        SFML_MISC_INSTALL_PREFIX
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/SFML)
vcpkg_copy_pdbs()

# move sfml-main to manual link dir
if(EXISTS "${CURRENT_PACKAGES_DIR}/lib/sfml-main.lib")
    file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib/manual-link")
    file(COPY "${CURRENT_PACKAGES_DIR}/lib/sfml-main.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib/manual-link")
    file(REMOVE "${CURRENT_PACKAGES_DIR}/lib/sfml-main.lib")
    file(GLOB FILES "${CURRENT_PACKAGES_DIR}/share/sfml/SFMLMain*Targets-*.cmake")
    foreach(FILE ${FILES})
        vcpkg_replace_string("${FILE}" "/lib/sfml-main" "/lib/manual-link/sfml-main")
    endforeach()
endif()
if(EXISTS "${CURRENT_PACKAGES_DIR}/debug/lib/sfml-main-d.lib")
    file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/debug/lib/manual-link")
    file(COPY "${CURRENT_PACKAGES_DIR}/debug/lib/sfml-main-d.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib/manual-link")
    file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/lib/sfml-main-d.lib")
endif()

file(REMOVE_RECURSE 
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_fixup_pkgconfig()

file(COPY "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/license.md")
