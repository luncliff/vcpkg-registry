if(EXISTS ${CURRENT_INSTALLED_DIR}/include/openssl/ssl.h)
  message(FATAL_ERROR "Can't build '${PORT}' if another SSL library is installed. Please remove existing one and try install '${PORT}' again if you need it.")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO quictls/openssl
    REF 77248f1c1c8ea8dc57d624050b78eab0b3a10a04 # 2021-05-03
    SHA512 881639f0bfd83858ce5d28aaf013dc34105cbc9c2fcc040c873c41ca45a0ea3dcb9dfd8e81821b21e92d4b9577f86d11ac010bb1f3746713892969c62d46fda6
    HEAD_REF openssl-3.0.0-alpha15+quic
)

vcpkg_find_acquire_program(PERL)
get_filename_component(PERL_EXE_PATH ${PERL} DIRECTORY)
vcpkg_add_to_path(${PERL_EXE_PATH})

set(OPENSSL_SHARED no-shared)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(OPENSSL_SHARED shared)
endif()

set(CONFIGURE_OPTIONS 
    # from existing 'openssl' port
    enable-static-engine enable-capieng
    -utf-8
    ${OPENSSL_SHARED}
    # from 'microsoft/msquic'
    enable-tls1_3 no-makedepend no-dgram no-ssl3 no-psk no-srp
    no-zlib no-egd no-idea no-rc5 no-rc4 no-afalgeng
    no-comp no-cms no-ct no-srp no-srtp no-ts no-gost no-dso no-ec2m
    no-tls1 no-tls1_1 no-tls1_2 no-dtls no-dtls1 no-dtls1_2 no-ssl
    no-ssl3-method no-tls1-method no-tls1_1-method no-tls1_2-method no-dtls1-method no-dtls1_2-method
    no-siphash no-whirlpool no-aria no-bf no-blake2 no-sm2 no-sm3 no-sm4 no-camellia no-cast no-md4 no-mdc2 no-ocb no-rc2 no-rmd160 no-scrypt
    no-weak-ssl-ciphers no-tests
)

if(VCPKG_TARGET_IS_UWP)
    include(${CMAKE_CURRENT_LIST_DIR}/uwp/portfile.cmake)
elseif(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
    include(${CMAKE_CURRENT_LIST_DIR}/windows/portfile.cmake)
else()
    include(${CMAKE_CURRENT_LIST_DIR}/unix/portfile.cmake)
endif()

file(INSTALL ${SOURCE_PATH}/LICENSE.txt 
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
