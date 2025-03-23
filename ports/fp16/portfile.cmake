vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Maratyszcza/fp16
    REF 98b0a46bce017382a6351a19577ec43a715b6835
    SHA512 d3ae46b5b0c944f1d8dcfbb90689266f4abaff3e0b5ef338d5d79193367f06d1bfbb9ad85a5a7685a894daeee6dc73fc5d73631718be1379cc6918655a0289aa
)

file(INSTALL    "${SOURCE_PATH}/include/fp16.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
)

# https://learn.microsoft.com/en-us/cpp/intrinsics/
file(GLOB HEADERS "${SOURCE_PATH}/include/fp16/*.h")
file(INSTALL ${HEADERS} DESTINATION "${CURRENT_PACKAGES_DIR}/include/fp16")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
