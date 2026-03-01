#!/usr/bin/env bash
# verify-install.sh - Verify OpenClaw installation on Termux (glibc architecture)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARN=$((WARN + 1))
}

echo "=== OpenClaw on Android - Installation Verification ==="
echo ""

# 1. Node.js version
if command -v node &>/dev/null; then
    NODE_VER=$(node -v)
    NODE_MAJOR="${NODE_VER%%.*}"
    NODE_MAJOR="${NODE_MAJOR#v}"
    if [ "$NODE_MAJOR" -ge 22 ] 2>/dev/null; then
        check_pass "Node.js $NODE_VER (>= 22)"
    else
        check_fail "Node.js $NODE_VER (need >= 22)"
    fi
else
    check_fail "Node.js not found"
fi

# 2. npm available
if command -v npm &>/dev/null; then
    check_pass "npm $(npm -v)"
else
    check_fail "npm not found"
fi

# 3. openclaw command
if command -v openclaw &>/dev/null; then
    CLAW_VER=$(openclaw --version 2>/dev/null || echo "error")
    if [ "$CLAW_VER" != "error" ]; then
        check_pass "openclaw $CLAW_VER"
    else
        check_warn "openclaw found but --version failed"
    fi
else
    check_fail "openclaw command not found"
fi

# 4. Environment variables
if [ -n "${TMPDIR:-}" ]; then
    check_pass "TMPDIR=$TMPDIR"
else
    check_fail "TMPDIR not set"
fi

if [ "${CONTAINER:-}" = "1" ]; then
    check_pass "CONTAINER=1 (systemd bypass)"
else
    check_warn "CONTAINER not set"
fi

if [ "${OA_GLIBC:-}" = "1" ]; then
    check_pass "OA_GLIBC=1 (glibc architecture)"
else
    check_fail "OA_GLIBC not set"
fi

# 5. glibc components
COMPAT_FILE="$HOME/.openclaw-android/patches/glibc-compat.js"
if [ -f "$COMPAT_FILE" ]; then
    check_pass "glibc-compat.js exists"
else
    check_fail "glibc-compat.js not found at $COMPAT_FILE"
fi

GLIBC_MARKER="$HOME/.openclaw-android/.glibc-arch"
if [ -f "$GLIBC_MARKER" ]; then
    check_pass "glibc architecture marker (.glibc-arch)"
else
    check_fail "glibc architecture marker not found"
fi

GLIBC_LDSO="${PREFIX:-}/glibc/lib/ld-linux-aarch64.so.1"
if [ -f "$GLIBC_LDSO" ]; then
    check_pass "glibc dynamic linker (ld-linux-aarch64.so.1)"
else
    check_fail "glibc dynamic linker not found at $GLIBC_LDSO"
fi

# Check glibc node wrapper (should be a bash script, not a binary)
NODE_WRAPPER="$HOME/.openclaw-android/node/bin/node"
if [ -f "$NODE_WRAPPER" ] && head -1 "$NODE_WRAPPER" 2>/dev/null | grep -q "bash"; then
    check_pass "glibc node wrapper script"
else
    check_fail "glibc node wrapper not found or not a wrapper script"
fi

# 6. Directories
for DIR in "$HOME/.openclaw-android" "$HOME/.openclaw" "$PREFIX/tmp"; do
    if [ -d "$DIR" ]; then
        check_pass "Directory $DIR exists"
    else
        check_fail "Directory $DIR missing"
    fi
done

# 7. code-server (non-critical)
if command -v code-server &>/dev/null; then
    CS_VER=$(code-server --version 2>/dev/null | head -1 || true)
    if [ -n "$CS_VER" ]; then
        check_pass "code-server $CS_VER"
    else
        check_warn "code-server found but --version failed"
    fi
else
    check_warn "code-server not installed (non-critical)"
fi

# 8. OpenCode command (non-critical)
if command -v opencode &>/dev/null; then
    check_pass "opencode command available"
else
    check_warn "opencode not installed (non-critical)"
fi

# 9. .bashrc contains env block
if grep -qF "OpenClaw on Android" "$HOME/.bashrc" 2>/dev/null; then
    check_pass ".bashrc contains environment block"
else
    check_fail ".bashrc missing environment block"
fi

# Summary
echo ""
echo "==============================="
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo "==============================="
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Installation verification FAILED.${NC}"
    echo "Please check the errors above and re-run install.sh"
    exit 1
else
    echo -e "${GREEN}Installation verification PASSED!${NC}"
fi
