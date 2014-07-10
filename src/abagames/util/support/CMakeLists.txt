set(util_support_srcs
    gl.d)

add_library(mcd_util_support STATIC
    ${util_support_srcs})
target_link_libraries(mcd_util_support
    Derelict::${gl_impl})
set_target_properties(mcd_util_support
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
