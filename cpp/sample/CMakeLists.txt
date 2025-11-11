cmake_minimum_required(VERSION 3.5)
project(signalrclient-sample)

# ----------------------------------------------------------------
# Step 1: Define relative paths
# ----------------------------------------------------------------

# Relative path to the shared library (.so) file
set(SIGNALR_SO_PATH 
    "${CMAKE_CURRENT_LIST_DIR}/signalr-client-cpp/build.release/bin/libmicrosoft-signalr.so"
)

set(SIGNALR_TEST_SO_PATH 
    "${CMAKE_CURRENT_LIST_DIR}/signalr-client-cpp/build.release/bin/signalrclienttests"
)

# Relative path to header directories
set(SIGNALR_INCLUDE_DIR 
    "${CMAKE_CURRENT_LIST_DIR}/signalr-client-cpp/include"
)

set(SIGNALR_INCLUDE_DIR2
    "${CMAKE_CURRENT_LIST_DIR}/signalr-client-cpp/src"
)

set(SIGNALR_TEST_INCLUDE_DIR 
    "${CMAKE_CURRENT_LIST_DIR}/signalr-client-cpp/test"
)

# ----------------------------------------------------------------
# Step 2: Create imported targets
# ----------------------------------------------------------------

# Create an imported shared library target for microsoft-signalr
add_library(microsoft-signalr_IMPORTED SHARED IMPORTED)

# Set properties for the imported target
set_target_properties(microsoft-signalr_IMPORTED PROPERTIES
    IMPORTED_LOCATION "${SIGNALR_SO_PATH}"
    INTERFACE_INCLUDE_DIRECTORIES "${SIGNALR_INCLUDE_DIR};${SIGNALR_INCLUDE_DIR2}"
)

add_library(microsoft-signalr-test_IMPORTED SHARED IMPORTED)

# Set properties for the imported test target
set_target_properties(microsoft-signalr-test_IMPORTED PROPERTIES
    IMPORTED_LOCATION "${SIGNALR_TEST_SO_PATH}"
    INTERFACE_INCLUDE_DIRECTORIES "${SIGNALR_TEST_INCLUDE_DIR};${SIGNALR_INCLUDE_DIR}/signalrclient;${SIGNALR_INCLUDE_DIR2}/signalrclient"
)

# ----------------------------------------------------------------
# Step 3: Link to your executable
# ----------------------------------------------------------------

add_executable(sample chat.cpp)

if(NOT MSVC)
    target_compile_options(sample PRIVATE -fms-extensions)
endif()

target_link_libraries(sample PRIVATE microsoft-signalr_IMPORTED microsoft-signalr-test_IMPORTED)

# ----------------------------------------------------------------
# Note: Runtime dependencies
# When running the executable (sample), the Linux loader must be able to find libmicrosoft-signalr.so and its dependencies.
# You may need to set the LD_LIBRARY_PATH environment variable before running:
# export LD_LIBRARY_PATH=${CMAKE_CURRENT_LIST_DIR}/signalr-client-cpp/build.release/bin:$LD_LIBRARY_PATH
# ----------------------------------------------------------------