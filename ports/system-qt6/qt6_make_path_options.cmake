#[===[.md:
# qt6_make_path_options.cmake

In vcpkg.json file,

```json
{
  "dependencies": [
    {
      "name": "system-qt6",
      "host": true
    }
  ]
}
```

In `portfile.cmake` file,

```cmake
qt6_make_path_options(qt6_path_options WITH_TOOLS
COMPONENTS
    Gui Widgets
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${qt6_path_options}
)
```

#]===]
if(Z_qt6_make_path_options_GUARD)
    return()
endif()
set(Z_qt6_make_path_options_GUARD ON CACHE INTERNAL "Guard variable for 'qt6_make_path_options'")

function(qt6_make_path_options out_var)
    cmake_parse_arguments(PARSE_ARGV 1 arg "WITH_TOOLS" "Qt6_DIR" "COMPONENTS")
    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} was passed extra arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()

    # supported triplet?
    if((NOT VCPKG_TARGET_IS_WINDOWS) AND (NOT VCPKG_TARGET_IS_UWP) AND (NOT VCPKG_TARGET_IS_OSX))
        message(WARNING "The triplet is not supported")
    endif()

    # the most importatnt option.
    if((NOT DEFINED Qt6_DIR) AND (NOT DEFINED arg_Qt6_DIR))
        message(FATAL_ERROR "Qt6_DIR is required for this function")
    endif()
    if(DEFINED arg_Qt6_DIR)
        get_filename_component(Qt6_DIR "${arg_Qt6_DIR}" ABSOLUTE)
    endif()
    list(APPEND options -DQt6_DIR:PATH=${Qt6_DIR})

    # ex) ".../msvc2019_64/lib/cmake/Qt6" -> ".../msvc2019_64/lib/cmake"
    get_filename_component(qt6_cmake_dir "${Qt6_DIR}" PATH)
    list(APPEND options -DQt6Core5Compat_DIR:PATH=${qt6_cmake_dir}/Qt6Core5Compat)

    message(VERBOSE "Searching ${qt6_cmake_dir} ...")
    if(DEFINED arg_WITH_TOOLS)
        # ex) Qt6CoreTools, Qt6WidgetsTools, etc.
        file(GLOB tool_folders "${qt6_cmake_dir}/Qt6*Tools")
        foreach(tool_folder ${tool_folders})
            get_filename_component(tool_name "${tool_folder}" NAME)
            message(VERBOSE "  ${tool_name}")
            list(APPEND options -D${tool_name}_DIR:PATH=${tool_folder})
        endforeach()
    endif()

    message(VERBOSE "Checking components...")
    if(DEFINED arg_COMPONENTS)
        # ex) Core, Network ...
        foreach(component IN LISTS arg_COMPONENTS)
            message(VERBOSE "  ${component}")
            list(APPEND options -DQt6${component}_DIR:PATH=${qt6_cmake_dir}/Qt6${component})
        endforeach()
    endif()

    set("${out_var}" "${options}" PARENT_SCOPE)
endfunction()
