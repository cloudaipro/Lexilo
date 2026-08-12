#!/bin/sh
set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(dirname "$SCRIPT_DIRECTORY")
RUNTIME_VERSION="1.13.2"
ARCHIVE_NAME="sherpa-onnx-v${RUNTIME_VERSION}-ios.tar.bz2"
ARCHIVE_SHA256="2886a04df4f8d5066c6c8b6e712278d65d7b60fc9e45990223df50262861d38b"
DOWNLOAD_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/v${RUNTIME_VERSION}/${ARCHIVE_NAME}"
DOWNLOAD_DIRECTORY="$PROJECT_DIRECTORY/.build/sherpa-runtime"
ARCHIVE_PATH="$DOWNLOAD_DIRECTORY/$ARCHIVE_NAME"
EXTRACT_DIRECTORY="$DOWNLOAD_DIRECTORY/extracted-v${RUNTIME_VERSION}"
VENDOR_DIRECTORY="$PROJECT_DIRECTORY/Vendor/SherpaOnnx"

mkdir -p "$DOWNLOAD_DIRECTORY" "$EXTRACT_DIRECTORY" "$VENDOR_DIRECTORY"

if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "Downloading sherpa-onnx iOS runtime v${RUNTIME_VERSION}..."
    curl --fail --location --output "$ARCHIVE_PATH" "$DOWNLOAD_URL"
fi

if ! echo "$ARCHIVE_SHA256  $ARCHIVE_PATH" | shasum -a 256 --check --status; then
    echo "Runtime archive checksum mismatch: $ARCHIVE_PATH" >&2
    echo "Remove that file and run this script again." >&2
    exit 1
fi

tar -xjf "$ARCHIVE_PATH" -C "$EXTRACT_DIRECTORY"

ditto \
    "$EXTRACT_DIRECTORY/build-ios/sherpa-onnx.xcframework" \
    "$VENDOR_DIRECTORY/sherpa-onnx.xcframework"
ditto \
    "$EXTRACT_DIRECTORY/build-ios/ios-onnxruntime/1.17.1/onnxruntime.xcframework" \
    "$VENDOR_DIRECTORY/onnxruntime.xcframework"

echo "Installed sherpa-onnx and ONNX Runtime XCFrameworks in Vendor/SherpaOnnx."
