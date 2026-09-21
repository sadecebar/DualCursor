cmake_minimum_required(VERSION 3.20)
project(DualCursor LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(DualCursor WIN32
    src/main.cpp
    src/devices.cpp
    src/overlay.cpp
    src/config.cpp
)

target_compile_definitions(DualCursor PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)

target_link_libraries(DualCursor PRIVATE user32 gdi32 shell32 ole32 uuid advapi32)

if(MSVC)
    # /utf-8: the sources are UTF-8 without a BOM. Without it MSVC assumes the
    # system ANSI codepage and mangles every non-ASCII character, wide string
    # literals included.
    target_compile_options(DualCursor PRIVATE /W4 /permissive- /utf-8)
    set_target_properties(DualCursor PROPERTIES LINK_FLAGS "/ENTRY:wWinMainCRTStartup")
else()
    target_compile_options(DualCursor PRIVATE -Wall -Wextra -municode)
    target_link_options(DualCursor PRIVATE -municode -static-libgcc -static-libstdc++)
endif()
