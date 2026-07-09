#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="${ROOT}/Native/CommandPaletteNucleoFFI"
DERIVED_DATA="${COTERM_NUCLEO_FFI_DERIVED_DATA:-/tmp/coterm-nucleo-ffi-unit}"
LOG_PATH="${COTERM_NUCLEO_FFI_LOG:-/tmp/coterm-nucleo-ffi-tests.log}"

cargo build --manifest-path "${CRATE_DIR}/Cargo.toml" --release

LIB_PATH="${CRATE_DIR}/target/release/libcoterm_command_palette_nucleo_ffi.dylib"
if [ ! -f "${LIB_PATH}" ]; then
  echo "error: expected nucleo FFI library at ${LIB_PATH}" >&2
  exit 1
fi

if [ "${COTERM_NUCLEO_FFI_CLEAN:-0}" = "1" ]; then
  rm -rf "${DERIVED_DATA}"
fi
NSUnbufferedIO=YES COTERM_NUCLEO_FFI_LIB="${LIB_PATH}" \
  xcodebuild \
    -project "${ROOT}/coterm.xcodeproj" \
    -scheme coterm-unit \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA}" \
    -only-testing:cotermTests/CommandPaletteNucleoFFITests \
    test | tee "${LOG_PATH}"

if ! grep 'BENCH cmd+p nucleo-ffi' "${LOG_PATH}"; then
  echo "error: CommandPaletteNucleoFFITests did not emit benchmark output" >&2
  exit 1
fi
