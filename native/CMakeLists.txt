# The shell's native QML module, "Nafeel": what QML alone can't do on umbriel.
#
#   WindowThumb   a live picture of one window (ext-image-copy-capture), only
#                 while it's visible, new frames only when the window changes
#   Keyboard      the modifiers held right now (the switcher's Alt release)
#   BlobGroup, BlobRect, BlobInvertedRect
#                 the frame as SDF blobs that merge (Ryoku's engine, GPL-3.0)
#   NightLight    warmer colour temperature (Noctalia's gamma service, MIT)
#   Clipboard     clipboard history (Noctalia's clipboard service, MIT, src/noctalia)
#   ScreenSaver   org.freedesktop.ScreenSaver (apps keeping the screen awake)
#   AnnotationCanvas  the annotator's image and annotations (tools after
#                 Noctalia's annotator, MIT)
#   M3Shapes      (its own module) Material 3 Expressive shapes with morphing:
#                 soramanew/m3shapes, Apache-2.0, vendored in third_party/
#   CavaProvider  the audio visualiser's bars (Caelestia's, GPL-3.0, src/caelestia:
#                 PipeWire capture + cava's core, MIT, vendored in src/cava)
#
# Build: ./build.sh  ->  build/qml/Nafeel (the supervisor adds build/qml to
# QML_IMPORT_PATH).
cmake_minimum_required(VERSION 3.21)
project(nafeel-native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Quick ShaderTools DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client)
pkg_get_variable(WL_PROTOCOLS wayland-protocols pkgdatadir)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

set(protocols
    ext-foreign-toplevel-list
    ext-image-capture-source
    ext-image-copy-capture)
set(protocol_sources)
foreach(p IN LISTS protocols)
    set(xml "${WL_PROTOCOLS}/staging/${p}/${p}-v1.xml")
    add_custom_command(
        OUTPUT ${p}-v1-client-protocol.h ${p}-v1-protocol.c
        COMMAND ${WAYLAND_SCANNER} client-header ${xml} ${p}-v1-client-protocol.h
        COMMAND ${WAYLAND_SCANNER} private-code ${xml} ${p}-v1-protocol.c
        DEPENDS ${xml})
    list(APPEND protocol_sources
        ${CMAKE_CURRENT_BINARY_DIR}/${p}-v1-client-protocol.h
        ${CMAKE_CURRENT_BINARY_DIR}/${p}-v1-protocol.c)
endforeach()
# Protocols kept in protocols/: wlr-gamma-control (night light), and for the
# clipboard wlr-data-control and virtual-keyboard (ext-data-control comes from
# wayland-protocols).
foreach(xml IN ITEMS
        ${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-data-control-unstable-v1.xml
        ${CMAKE_CURRENT_SOURCE_DIR}/protocols/virtual-keyboard-unstable-v1.xml
        ${WL_PROTOCOLS}/staging/ext-data-control/ext-data-control-v1.xml)
    get_filename_component(p ${xml} NAME_WE)
    add_custom_command(
        OUTPUT ${p}-client-protocol.h ${p}-protocol.c
        COMMAND ${WAYLAND_SCANNER} client-header ${xml} ${p}-client-protocol.h
        COMMAND ${WAYLAND_SCANNER} private-code ${xml} ${p}-protocol.c
        DEPENDS ${xml})
    list(APPEND protocol_sources
        ${CMAKE_CURRENT_BINARY_DIR}/${p}-client-protocol.h
        ${CMAKE_CURRENT_BINARY_DIR}/${p}-protocol.c)
endforeach()

# wlr-gamma-control (night light), kept in protocols/.
set(gamma_xml ${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-gamma-control-unstable-v1.xml)
add_custom_command(
    OUTPUT wlr-gamma-control-unstable-v1-client-protocol.h wlr-gamma-control-unstable-v1-protocol.c
    COMMAND ${WAYLAND_SCANNER} client-header ${gamma_xml} wlr-gamma-control-unstable-v1-client-protocol.h
    COMMAND ${WAYLAND_SCANNER} private-code ${gamma_xml} wlr-gamma-control-unstable-v1-protocol.c
    DEPENDS ${gamma_xml})
list(APPEND protocol_sources
    ${CMAKE_CURRENT_BINARY_DIR}/wlr-gamma-control-unstable-v1-client-protocol.h
    ${CMAKE_CURRENT_BINARY_DIR}/wlr-gamma-control-unstable-v1-protocol.c)

qt_policy(SET QTP0001 NEW)
qt_add_library(nafeelnative SHARED)
qt_add_qml_module(nafeelnative
    URI Nafeel
    VERSION 1.0
    PLUGIN_TARGET nafeelnative
    NO_GENERATE_PLUGIN_SOURCE
    CLASS_NAME NafeelPlugin
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/Nafeel
    SOURCES
        src/plugin.cpp
        src/capture.h src/capture.cpp
        src/windowthumb.h src/windowthumb.cpp
        src/keyboard.h
        src/annotationcanvas.h src/annotationcanvas.cpp
        src/screensaver.h src/screensaver.cpp
        src/blobgroup.hpp src/blobgroup.cpp
        src/blobshape.hpp src/blobshape.cpp
        src/blobrect.hpp src/blobrect.cpp
        src/blobinvertedrect.hpp src/blobinvertedrect.cpp
        src/blobmaterial.hpp src/blobmaterial.cpp
        src/nightlight.h src/nightlight.cpp
        src/clipboard.h src/clipboard.cpp
        src/caelestia/service.hpp src/caelestia/service.cpp
        src/caelestia/serviceref.hpp src/caelestia/serviceref.cpp
        src/caelestia/audiocollector.hpp src/caelestia/audiocollector.cpp
        src/caelestia/audioprovider.hpp src/caelestia/audioprovider.cpp
        src/caelestia/cavaprovider.hpp src/caelestia/cavaprovider.cpp)
target_sources(nafeelnative PRIVATE ${protocol_sources})
# Noctalia's clipboard stack, ported as it is (src/noctalia, MIT).
file(GLOB_RECURSE noctalia_sources CONFIGURE_DEPENDS src/noctalia/*.cpp)
target_sources(nafeelnative PRIVATE ${noctalia_sources})
pkg_check_modules(SODIUM REQUIRED IMPORTED_TARGET libsodium)
pkg_check_modules(SECRET REQUIRED IMPORTED_TARGET libsecret-1)
pkg_check_modules(XKB REQUIRED IMPORTED_TARGET xkbcommon)
# The visualiser: cava's core (MIT, src/cava) on FFTW, PipeWire capture.
target_sources(nafeelnative PRIVATE src/cava/cavacore.c)
pkg_check_modules(FFTW REQUIRED IMPORTED_TARGET fftw3)
pkg_check_modules(PIPEWIRE REQUIRED IMPORTED_TARGET libpipewire-0.3)
target_include_directories(nafeelnative PRIVATE ${CMAKE_CURRENT_BINARY_DIR} src src/noctalia src/caelestia)
target_link_libraries(nafeelnative PRIVATE Qt6::Gui Qt6::Quick Qt6::DBus PkgConfig::WAYLAND PkgConfig::SODIUM PkgConfig::SECRET PkgConfig::XKB PkgConfig::FFTW PkgConfig::PIPEWIRE)

qt_add_shaders(nafeelnative "blob_shaders"
    BATCHABLE
    GLSL "300es,330"
    PREFIX "/"
    FILES
        shaders/blob.vert
        shaders/blob.frag)

# Material 3 Expressive shapes (soramanew/m3shapes, Apache-2.0): its own QML
# module, built next to Nafeel so `import M3Shapes` works as in Caelestia.
set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml)
add_subdirectory(third_party/m3shapes EXCLUDE_FROM_ALL)
add_dependencies(nafeelnative m3shapes m3shapesplugin)
