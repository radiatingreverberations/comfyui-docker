#!/bin/bash
set -euo pipefail

SECRET_FILE=/run/secrets/SSH_HOST_ED25519_KEY_B64
umask 077

if [ -s "$SECRET_FILE" ]; then
    base64 -d "$SECRET_FILE" > /tmp/host_ed25519_key || { echo "[ssh] Failed to decode base64 host key" >&2; exit 1; }
    if ! ssh-keygen -y -f /tmp/host_ed25519_key > /tmp/host_ed25519_key.pub 2>/dev/null; then
        echo "[ssh] Secret does not contain a valid OpenSSH Ed25519 private key" >&2
        exit 1
    fi
    NEW_FPR=$(ssh-keygen -l -E sha256 -f /tmp/host_ed25519_key 2>/dev/null | awk '{print $2}' || true)
    [ -n "$NEW_FPR" ] || NEW_FPR=$(ssh-keygen -l -f /tmp/host_ed25519_key 2>/dev/null | awk '{print $2}') || true
    mv /tmp/host_ed25519_key /etc/ssh/ssh_host_ed25519_key
    mv /tmp/host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
    chown root:root /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub
    chmod 600 /etc/ssh/ssh_host_ed25519_key
    chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
    echo "[ssh] Baked Ed25519 host key fingerprint: $NEW_FPR"
else
    echo "[ssh] No baked host key secret provided; apt-generated (or runtime) key retained"
fi

# Remove other host key types so only Ed25519 ships.
rm -f /etc/ssh/ssh_host_rsa_key* /etc/ssh/ssh_host_ecdsa_key* 2>/dev/null || true
