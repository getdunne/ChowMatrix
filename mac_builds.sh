#!/bin/bash

# exit on failure
set -e

# clean up old builds
rm -Rf build/
rm -Rf bin/*Mac*

# set up build VST
VST_PATH=~/SDKs/VST_SDK/VST2_SDK/
sed -i '' "9s~.*~juce_set_vst2_sdk_path(${VST_PATH})~" CMakeLists.txt
sed -i '' '16s/#//' CMakeLists.txt

# cmake new builds
TEAM_ID="eveloper ID Application: Dunne & Associates Technology Consulting, Inc (W5AEHZN66V)"
cmake -Bbuild -GXcode -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="Developer ID Application" \
    -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="$TEAM_ID" \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_STYLE="Manual" \
    -D"CMAKE_OSX_ARCHITECTURES=arm64;x86_64" \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    -DCMAKE_XCODE_ATTRIBUTE_OTHER_CODE_SIGN_FLAGS="--timestamp" \
    -DMACOS_RELEASE=ON
cmake --build build --config Release -j8 | xcpretty

# copy builds to bin
mkdir -p bin/Mac
declare -a plugins=("ChowMatrix")
for plugin in "${plugins[@]}"; do
    cp -R build/${plugin}_artefacts/Release/Standalone/${plugin}.app bin/Mac/${plugin}.app
    cp -R build/${plugin}_artefacts/Release/VST/${plugin}.vst bin/Mac/${plugin}.vst
    cp -R build/${plugin}_artefacts/Release/VST3/${plugin}.vst3 bin/Mac/${plugin}.vst3
    cp -R build/${plugin}_artefacts/Release/AU/${plugin}.component bin/Mac/${plugin}.component
done

# reset CMakeLists.txt
git restore CMakeLists.txt

# run auval
echo "Running AU validation..."
rm -Rf ~/Library/Audio/Plug-Ins/Components/${plugin}.component
cp -R build/${plugin}_artefacts/Release/AU/${plugin}.component ~/Library/Audio/Plug-Ins/Components
manu=$(cut -f 6 -d ' ' <<< "$(grep 'PLUGIN_MANUFACTURER_CODE' CMakeLists.txt)")
code=$(cut -f 6 -d ' ' <<< "$(grep 'PLUGIN_CODE' CMakeLists.txt)")

set +e
auval_result=$(auval -v aufx "$code" "$manu")
auval_code="$?"
echo "AUVAL code: $auval_code"

if [ "$auval_code" != 0 ]; then
    echo "$auval_result"
    echo "auval FAIL!!!"
    exit 1
else
    echo "auval PASSED"
fi

# zip builds
echo "Zipping builds..."
VERSION=$(cut -f 2 -d '=' <<< "$(grep 'CMAKE_PROJECT_VERSION:STATIC' build/CMakeCache.txt)")
(
    cd bin
    rm -f "ChowMatrix-Mac-${VERSION}.zip"
    zip -r "ChowMatrix-Mac-${VERSION}.zip" Mac
)

# create installer
echo "Creating installer..."
(
    cd installers/mac
    bash build_mac_installer.sh
)
