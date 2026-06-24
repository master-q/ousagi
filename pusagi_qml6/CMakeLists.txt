cmake_minimum_required(VERSION 3.16)
project(pusagi VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Quick Pdf)

qt6_add_resources(APP_RESOURCES resources.qrc)

add_executable(pusagi main.cpp ${APP_RESOURCES})
target_link_libraries(pusagi PRIVATE Qt6::Quick Qt6::Pdf)
