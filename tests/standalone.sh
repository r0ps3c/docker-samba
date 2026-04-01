#!/bin/sh
# Standalone runtime tests for samba container
# Verifies smbd starts and listens without testing share access

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-samba:main}"
CONTAINER_NAME="samba-test-standalone-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Standalone Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container
log_info "Starting samba container in standalone mode..."
if docker run -d --name "$CONTAINER_NAME" "$IMAGE_NAME"; then
    log_success "Container started successfully"
else
    log_error "Container failed to start"
    exit 1
fi

# Test 1: Container stays running (stability check)
log_info "Test 1: Container stability check"
if wait_container_stable "$CONTAINER_NAME" 5; then
    log_success "Container is stable and running"
else
    log_error "Container is not stable (crashed on startup)"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
fi

# Test 2: smbd process is running
log_info "Test 2: smbd process is running"
if docker exec "$CONTAINER_NAME" sh -c 'ps aux | grep -v grep | grep -q smbd'; then
    log_success "smbd process is running"
else
    log_error "smbd process not found"
    docker exec "$CONTAINER_NAME" ps aux || true
fi

# Test 3: Port 445 is listening
log_info "Test 3: Port 445 (SMB) is listening"
if wait_for_port "$CONTAINER_NAME" 445 30; then
    log_success "Port 445 is listening"
else
    log_error "Port 445 is not listening after 30s"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
fi

# Test 4: No fatal errors in logs
log_info "Test 4: No fatal errors in logs"
if docker logs "$CONTAINER_NAME" 2>&1 | grep -qiE "FATAL|failed to start|unable to open|permission denied|address already in use"; then
    log_error "Fatal errors found in logs"
    docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "FATAL|failed|unable|permission|address" | head -10
else
    log_success "No fatal errors in logs"
fi

# Test 5: Config valid at runtime (testparm inside running container)
log_info "Test 5: smb.conf valid at runtime"
if docker exec "$CONTAINER_NAME" testparm -s >/dev/null 2>&1; then
    log_success "smb.conf is valid"
else
    log_error "testparm failed at runtime"
    docker exec "$CONTAINER_NAME" testparm -s 2>&1 | tail -10 || true
fi

# Test 6: Container still running after all checks
log_info "Test 6: Container still running after all tests"
if is_container_running "$CONTAINER_NAME"; then
    log_success "Container still running"
else
    log_error "Container stopped during tests"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
fi

# Print summary and exit
print_summary "Standalone Tests"
exit $TEST_FAILED
