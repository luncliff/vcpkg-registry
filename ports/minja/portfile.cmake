
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/minja
    REF f06140fa52fd140fe38e531ec373d8dc9c86aa06
    SHA512 7ddbfbbdbeff0e05f9c8106173f14a855962e570dd97cdc3224ccc1b6e10035ee3df7bc03ff06229ddd1dfdd611124a842cba19be45a73e9a36a43e8105b76a6
    HEAD_REF main
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DMINJA_TEST_ENABLED=OFF
        -DMINJA_EXAMPLE_ENABLED=OFF
        -DMINJA_FUZZTEST_ENABLED=OFF
)
vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
