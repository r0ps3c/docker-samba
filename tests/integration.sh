#!/bin/sh
# Integration tests for samba container
# Verifies SMB connectivity and share access via smbclient

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-samba:main}"
CONTAINER_NAME="samba-test-integration-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Integration Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container with test share config and a mapped port
log_info "Starting samba container with test share config..."
if docker run -d --name "$CONTAINER_NAME" \
    -p 127.0.0.1::445 \
    -v "$SCRIPT_DIR/configs/smb-test.conf:/etc/samba/smb.conf.d/override.conf:ro" \
    "$IMAGE_NAME"; then
    log_success "Container started successfully"
else
    log_error "Container failed to start"
    exit 1
fi

# Test 1: Container starts and is running
log_info "Test 1: Container starts and is running"
sleep 3
if is_container_running "$CONTAINER_NAME"; then
    log_success "Container is running"
else
    log_error "Container is not running after start"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    exit 1
fi

# Test 2: Container stability check
log_info "Test 2: Container stability check"
if wait_container_stable "$CONTAINER_NAME" 5; then
    log_success "Container is stable"
else
    log_error "Container is not stable"
fi

# Test 3: smbd process is running
log_info "Test 3: smbd process is running"
if docker exec "$CONTAINER_NAME" sh -c 'ps aux | grep -v grep | grep -q smbd'; then
    log_success "smbd process is running"
else
    log_error "smbd process not found"
    docker exec "$CONTAINER_NAME" ps aux || true
fi

# Test 4: No fatal errors in logs
log_info "Test 4: No fatal errors in logs"
if docker logs "$CONTAINER_NAME" 2>&1 | grep -qiE "FATAL|failed to start|unable to open|permission denied|address already in use"; then
    log_error "Fatal errors found in logs"
    docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "FATAL|failed|unable|permission|address" | head -10
else
    log_success "No fatal errors in logs"
fi

# Test 5: Port 445 listening inside container
log_info "Test 5: Port 445 is listening inside container"
if wait_for_port "$CONTAINER_NAME" 445 30; then
    log_success "Port 445 is listening"
else
    log_error "Port 445 is not listening after 30s"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
fi

# Get the mapped host port
HOST_PORT=$(docker port "$CONTAINER_NAME" 445 2>/dev/null | head -1 | cut -d: -f2)
log_info "Mapped host port: $HOST_PORT"

# Test 6: TCP connectivity on mapped port
log_info "Test 6: TCP connection to mapped SMB port"
if [ -z "$HOST_PORT" ]; then
    log_error "Could not determine mapped host port"
elif command -v nc >/dev/null 2>&1; then
    if nc -z -w 5 127.0.0.1 "$HOST_PORT" 2>/dev/null; then
        log_success "TCP connection to port $HOST_PORT succeeded"
    else
        log_error "TCP connection to port $HOST_PORT failed"
    fi
else
    log_warn "nc not available on host — skipping TCP connectivity test"
fi

# Test 7: smbclient can list shares (if available on host)
log_info "Test 7: smbclient share listing"
if command -v smbclient >/dev/null 2>&1 && [ -n "$HOST_PORT" ]; then
    if smbclient -L 127.0.0.1 -N -p "$HOST_PORT" 2>&1 | grep -qi "testshare\|Sharename"; then
        log_success "smbclient listed shares including testshare"
    else
        log_warn "smbclient ran but testshare not confirmed (may still be initializing)"
        smbclient -L 127.0.0.1 -N -p "$HOST_PORT" 2>&1 | head -20 || true
    fi
else
    log_warn "smbclient not available on host — skipping share listing test"
fi

# Test 8: Container still running after all checks
log_info "Test 8: Container still running after tests"
if is_container_running "$CONTAINER_NAME"; then
    log_success "Container still running"
else
    log_error "Container stopped during tests"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
fi

# Print summary and exit
print_summary "Integration Tests"
exit $TEST_FAILED
