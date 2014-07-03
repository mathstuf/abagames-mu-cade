set(util_ode_srcs
    odeactor.d
    world.d)

add_library(mcd_util_ode STATIC
    ${util_ode_srcs})
target_link_libraries(mcd_util_ode
    mcd_util
    Derelict::ode
    Derelict::util)
set_target_properties(mcd_util_ode
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
