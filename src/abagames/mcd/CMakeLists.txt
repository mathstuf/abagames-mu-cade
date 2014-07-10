set(mcd_srcs
    barrage.d
    bullet.d
    bulletimpl.d
    bulletpool.d
    bullettarget.d
    enemy.d
    field.d
    gamemanager.d
    letter.d
    particle.d
    prefmanager.d
    replay.d
    screen.d
    shape.d
    ship.d
    shot.d
    soundmanager.d
    spec.d
    stagemanager.d
    title.d)

add_library(mcd STATIC
    ${mcd_srcs})
target_link_libraries(mcd
    mcd_util
    mcd_util_support
    mcd_util_bulletml
    mcd_util_ode
    mcd_util_sdl
    Derelict::ode
    Derelict::${gl_impl}
    Derelict::sdl2
    Derelict::util)
set_target_properties(mcd
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

add_executable(mu-cade
    boot.d)
target_link_libraries(mu-cade
    mcd
    mcd_util
    mcd_util_support
    mcd_util_bulletml
    mcd_util_ode
    mcd_util_sdl)
set_target_properties(mu-cade
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
