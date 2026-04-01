#!/bin/sh
# Structure tests for samba Docker image
# Pure POSIX sh - no external dependencies
# Tests: binary existence, packages, config files, image hygiene

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-samba:main}"
CONTAINER_NAME="samba-test-structure-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Structure Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container for inspection (override entrypoint)
log_info "Starting container for structure inspection..."
docker run -d --name "$CONTAINER_NAME" --entrypoint sleep "$IMAGE_NAME" 3600 >/dev/null 2>&1

# Test 1: samba package installed
log_info "Test 1: samba package installed"
if docker exec "$CONTAINER_NAME" apk info samba 2>/dev/null | grep -q "^samba-"; then
    log_success "samba package is installed"
else
    log_error "samba package is not installed"
fi

# Test 2: smbd binary exists
log_info "Test 2: smbd binary exists at /usr/sbin/smbd"
if docker exec "$CONTAINER_NAME" test -f /usr/sbin/smbd; then
    log_success "smbd binary exists"
else
    log_error "smbd binary not found at /usr/sbin/smbd"
fi

# Test 3: smbd binary is executable
log_info "Test 3: smbd binary is executable"
if docker exec "$CONTAINER_NAME" test -x /usr/sbin/smbd; then
    log_success "smbd binary is executable"
else
    log_error "smbd binary is not executable"
fi

# Test 4: testparm binary exists
log_info "Test 4: testparm binary exists"
if docker exec "$CONTAINER_NAME" test -x /usr/bin/testparm; then
    log_success "testparm is available"
else
    log_error "testparm not found"
fi

# Test 5: smb.conf installed
log_info "Test 5: smb.conf installed at /etc/samba/smb.conf"
if docker exec "$CONTAINER_NAME" test -f /etc/samba/smb.conf; then
    log_success "smb.conf exists"
else
    log_error "smb.conf not found at /etc/samba/smb.conf"
fi

# Test 6: smb.conf.d directory and override.conf exist
log_info "Test 6: smb.conf.d directory and override.conf exist"
if docker exec "$CONTAINER_NAME" test -d /etc/samba/smb.conf.d && \
   docker exec "$CONTAINER_NAME" test -f /etc/samba/smb.conf.d/override.conf; then
    log_success "smb.conf.d directory and override.conf exist"
else
    log_error "smb.conf.d directory or override.conf not found"
fi

# Test 7: smb.conf is valid (testparm)
log_info "Test 7: smb.conf passes testparm validation"
if docker exec "$CONTAINER_NAME" testparm -s /etc/samba/smb.conf >/dev/null 2>&1; then
    log_success "smb.conf is valid"
else
    log_error "smb.conf failed testparm validation"
    docker exec "$CONTAINER_NAME" testparm -s /etc/samba/smb.conf 2>&1 | tail -10 || true
fi

# Test 8: Version extractable and valid semver format
log_info "Test 8: samba version extractable and valid semver format"
VERSION=$(docker exec "$CONTAINER_NAME" sh -c "apk info samba 2>/dev/null | grep '^samba-' | head -1 | cut -d- -f2 | cut -dr -f1")
if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    log_success "Version is extractable and valid: $VERSION"
else
    log_error "Version format invalid or not extractable: '$VERSION'"
fi

# Test 9: Ports 139 and 445 are exposed
log_info "Test 9: Image exposes ports 139 and 445"
EXPOSED_PORTS=$(docker inspect "$IMAGE_NAME" --format='{{json .Config.ExposedPorts}}' 2>/dev/null || echo "")
if echo "$EXPOSED_PORTS" | grep -q "139" && echo "$EXPOSED_PORTS" | grep -q "445"; then
    log_success "Ports 139 and 445 are exposed"
else
    log_error "Expected ports not exposed: $EXPOSED_PORTS"
fi

# Test 10: No APK cache files left behind
log_info "Test 10: No APK cache files in /var/cache/apk"
CACHE_COUNT=$(docker exec "$CONTAINER_NAME" sh -c 'ls /var/cache/apk 2>/dev/null | wc -l')
if [ "$CACHE_COUNT" = "0" ]; then
    log_success "No APK cache files"
else
    log_warn "Found $CACHE_COUNT items in /var/cache/apk"
fi

# Test 11: Base image is Alpine
log_info "Test 11: Base image is Alpine Linux"
if docker exec "$CONTAINER_NAME" cat /etc/os-release 2>/dev/null | grep -q "Alpine"; then
    log_success "Base image is Alpine Linux"
else
    log_error "Base image is not Alpine Linux"
fi

# Test 12: No temp files in /tmp
log_info "Test 12: No temp files in /tmp"
TMP_COUNT=$(docker exec "$CONTAINER_NAME" sh -c 'ls /tmp 2>/dev/null | wc -l')
if [ "$TMP_COUNT" = "0" ]; then
    log_success "No temp files in /tmp"
else
    log_warn "Found $TMP_COUNT items in /tmp"
fi

# Print summary and exit
print_summary "Structure Tests"
exit $TEST_FAILED
