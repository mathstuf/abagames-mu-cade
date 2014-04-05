set(util_bulletml_srcs
    bullet.d
    bulletsmanager.d)

add_library(mcd_util_bulletml STATIC
    ${util_bulletml_srcs})
target_link_libraries(mcd_util_bulletml
    mcd_util
    BulletML::bulletml)
