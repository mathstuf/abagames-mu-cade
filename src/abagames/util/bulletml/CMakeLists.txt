set(util_bulletml_srcs
    bullet.d
    bulletsmanager.d)

add_library(mcd_util_bulletml STATIC
    ${util_bulletml_srcs})
target_link_libraries(mcd_util_bulletml
    mcd_util
    BulletML::bulletml)
set_target_properties(mcd_util_bulletml
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
