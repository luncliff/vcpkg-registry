vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Maratyszcza/fp16
    REF 581ac1c79dd9d9f6f4e8b2934e7a55c7becf0799
    SHA512 a7898d9fe4ae183562c87b3e61865b1166dd45ab342f6874a42ec8123f8cf41c0074df0bce7696d378c364ff5f363d33942f12c63d804efacb7423b64f3c10f4
)

file(INSTALL    "${SOURCE_PATH}/include/fp16.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
)
file(INSTALL    "${SOURCE_PATH}/include/fp16/fp16.h"
                "${SOURCE_PATH}/include/fp16/bitcasts.h"
                "${SOURCE_PATH}/include/fp16/psimd.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/fp16"
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
