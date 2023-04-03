#!/usr/bin/env bash
set -Eeuo pipefail
BUILD_BASE="$PWD"
cd "${BUILD_BASE}/src"
mkdir -p "${BUILD_BASE}/release"
tar -czf "${BUILD_BASE}/release/plymouth-theme-arch-elegant.tar.gz" ./*
