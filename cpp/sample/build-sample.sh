rm -rf ./build
mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../signalr-client-cpp/submodules/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build .