#!/usr/bin/env bash
#
# Shared test framework — sourced by all test scripts.
#
# Provides: TEST_DIR, PROCESSORS_PATH, FAILED, PASSED, pass(), fail()
#
# The sourcing script's $0 is used to compute TEST_DIR (expects tests/ subdir).

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROCESSORS_PATH="${PROCESSORS_PATH:-/opt/provisioning-tools/processors}"

FAILED=0
PASSED=0

pass() { echo "  PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL: $1"; FAILED=$((FAILED + 1)); }
