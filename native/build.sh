#!/bin/sh
# Builds the shell's native QML module into build/qml/Nafeel.
# Needs cmake, a C++ compiler, qt6-base, qt6-declarative, wayland,
# wayland-protocols. Rebuild after a Qt major/minor upgrade.
set -eu
cd "$(dirname "$0")"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -Wno-dev >/dev/null
cmake --build build -j"$(nproc)"
echo "built $(pwd)/build/qml/Nafeel"
