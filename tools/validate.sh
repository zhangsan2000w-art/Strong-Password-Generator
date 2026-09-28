#!/usr/bin/env bash
set -euo pipefail

mode="${1:---all}"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="${PYTHON:-}"

if [[ -z "${python_bin}" ]]; then
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then
        python_bin="$(command -v python3)"
    elif command -v python >/dev/null 2>&1 && python -c 'import sys' >/dev/null 2>&1; then
        python_bin="$(command -v python)"
    else
        echo "ERROR: a working Python 3 interpreter is required." >&2
        exit 1
    fi
fi

usage() {
    echo "Usage: $0 [--all|--static|--firmware]" >&2
}

run_static_checks() {
    local actionlint_bin

    "${python_bin}" tools/check_repo.py

    if ! command -v moon >/dev/null 2>&1; then
        echo "ERROR: moon is not available; install the MoonBit toolchain first." >&2
        return 1
    fi
    MOONBIT_NEW_NATIVE=0 moon -C moonbit check --target native --deny-warn
    moon -C moonbit test \
        -p folotoy/strong-password-generator-ai-passport/securegen \
        --target wasm-gc --release --deny-warn
    moon -C moonbit run examples/cli --target wasm-gc --release >/dev/null
    MOONBIT_NEW_NATIVE=0 moon -C moonbit test --target native --release

    actionlint_bin="${ACTIONLINT_BIN:-}"
    if [[ -z "${actionlint_bin}" ]]; then
        actionlint_bin="$(command -v actionlint || true)"
    fi
    if [[ -z "${actionlint_bin}" || ! -x "${actionlint_bin}" ]]; then
        actionlint_bin="$(./tools/install-actionlint.sh)"
    fi
    "${actionlint_bin}" -color .github/workflows/*.yml

    # ui_pixel_math / demo_navigation 的纯逻辑已经并入 MoonBit 核心，由上面的
    # moon test 覆盖；C 侧不再保留只跑这两块逻辑的主机测试。
    PYTHONDONTWRITEBYTECODE=1 "${python_bin}" tests/test_verify_firmware.py
    PYTHONDONTWRITEBYTECODE=1 "${python_bin}" tests/test_screenshot_convert.py
    echo "Host tests: PASS"
}

run_firmware_checks() (
    local validation_build_dir
    local idf_args=()

    if ! command -v idf.py >/dev/null 2>&1; then
        echo "ERROR: idf.py is not available; activate ESP-IDF 5.5.3 first." >&2
        return 1
    fi

    if [[ "${IDF_NO_CCACHE:-0}" == "1" ]]; then
        idf_args+=(--no-ccache)
    fi

    validation_build_dir="$(mktemp -d /tmp/ai-passport-firmware.XXXXXX)"
    trap 'case "${validation_build_dir}" in /tmp/ai-passport-firmware.*) rm -rf -- "${validation_build_dir}" ;; esac' EXIT

    SDKCONFIG_DEFAULTS="${repo_root}/sdkconfig.defaults" \
        idf.py "${idf_args[@]}" -B "${validation_build_dir}" \
        -D "SDKCONFIG=${validation_build_dir}/sdkconfig" build
    idf.py "${idf_args[@]}" -B "${validation_build_dir}" merge-bin \
        -o "${validation_build_dir}/FoloToy-AI-Passport-full.bin"
    "${python_bin}" tools/verify_firmware.py "${validation_build_dir}"
    mkdir -p "${repo_root}/build"
    install -m 0644 \
        "${validation_build_dir}/FoloToy-AI-Passport-full.bin" \
        "${repo_root}/build/FoloToy-AI-Passport-full.bin"
    echo "Firmware build: PASS"
)

cd "${repo_root}"
case "${mode}" in
    --all)
        run_static_checks
        run_firmware_checks
        ;;
    --static)
        run_static_checks
        ;;
    --firmware)
        run_firmware_checks
        ;;
    *)
        usage
        exit 2
        ;;
esac
