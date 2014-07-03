set(util_sdl_srcs
    displaylist.d
    gamemanager.d
    input.d
    mainloop.d
    recordableinput.d
    screen.d
    screen3d.d
    sdlexception.d
    shape.d
    sound.d
    texture.d
    twinstickpad.d)

add_library(mcd_util_sdl STATIC
    ${util_sdl_srcs})
target_link_libraries(mcd_util_sdl
    mcd_util
    Derelict::opengl3
    Derelict::sdl2
    Derelict::util)
set_target_properties(mcd_util_sdl
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
