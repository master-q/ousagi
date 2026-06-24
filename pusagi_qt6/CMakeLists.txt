cmake_minimum_required(VERSION 3.16)
project(pusagi_qt6 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Pdf)

qt_add_executable(pusagi pusagi.cpp)

target_link_libraries(pusagi PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Pdf
)
