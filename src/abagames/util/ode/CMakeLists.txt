set(util_ode_srcs
    odeactor.d
    world.d)

add_library(mcd_util_ode STATIC
    ${util_ode_srcs})
target_link_libraries(mcd_util_ode
    mcd_util
    Derelict::ode
    Derelict::util)
