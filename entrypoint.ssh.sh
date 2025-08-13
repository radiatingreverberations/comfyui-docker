#!/bin/bash
set -e

# Generate random long username; expose it for users to read
SSH_USER="${SSH_USER:-u-$(tr -d '-' </proc/sys/kernel/random/uuid | cut -c1-30)}"

# Detect public IP addresses for connection instructions
get_public_ipv4() {
  for u in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com https://checkip.amazonaws.com; do
    ip="$(curl -4 -fs --max-time 2 "$u" 2>/dev/null | tr -d '\r\n')"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && { echo "$ip"; return 0; }
  done
}

# Try IPv6 only if the kernel has IPv6 enabled; silence errors.
get_public_ipv6() {
  [[ -r /proc/net/if_inet6 && -s /proc/net/if_inet6 ]] || return 0
  for u in https://api.ipify.org https://ifconfig.me https://icanhazip.com; do
    ip="$(curl -6 -fs --max-time 2 "$u" 2>/dev/null | tr -d '\r\n')"
    [[ "$ip" == *:* ]] && { echo "$ip"; return 0; }
  done
}

PUB4="$(get_public_ipv4)"
PUB6="$(get_public_ipv6)"
HOST_HINT="${PUB4:-${PUB6:-<host-ip>}}"

# Store username for easy retrieval
echo "${SSH_USER}" | tee /run/ssh-user >/dev/null

# SSH host key setup (supports injecting a pinned key via env)
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  if [ -n "${SSH_HOST_ED25519_KEY_B64:-}" ]; then
    umask 077
    echo "${SSH_HOST_ED25519_KEY_B64}" | base64 -d > /etc/ssh/ssh_host_ed25519_key || {
      echo "Failed to decode SSH_HOST_ED25519_KEY_B64" >&2; exit 1;
    }
    chown root:root /etc/ssh/ssh_host_ed25519_key
    chmod 600 /etc/ssh/ssh_host_ed25519_key
    ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub
  else
    # No pinned key provided – generate default host keys
    ssh-keygen -A
  fi
else
  # Ensure matching public key exists if only the private key was baked in
  [ -f /etc/ssh/ssh_host_ed25519_key.pub ] || ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub || true
fi

# Get host key fingerprint for display (SHA256)
FPR="$(ssh-keygen -l -E sha256 -f /etc/ssh/ssh_host_ed25519_key | awk '{print $2}')"

# Setup terminal colors if supported
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
else
  BOLD=""; DIM=""; RESET=""
fi

# Display connection information banner
echo
echo "================================================================================"
echo " ${BOLD}ComfyUI + SSH Tunnel${RESET}"
echo "================================================================================"
echo " User:        ${BOLD}${SSH_USER}${RESET}"
echo " SSH Port:    ${BOLD}2222${RESET}"
echo " Host key ID: ${BOLD}${FPR}${RESET}"
if [ -n "${SSH_KEY:-}" ]; then
  echo " Auth method: ${BOLD}SSH Key${RESET}"
elif [ -n "${SSH_PASSWORD:-}" ]; then
  echo " Auth method: ${BOLD}Password${RESET}"
else
  echo " Auth method: ${BOLD}No password (empty)${RESET}"
fi
echo
[ -n "$PUB4" ] && echo " Public IPv4: ${BOLD}${PUB4}${RESET}"
[ -n "$PUB6" ] && echo " Public IPv6: ${BOLD}${PUB6}${RESET}"
echo
echo " How to connect:"
echo "   ssh -p 2222 ${SSH_USER}@${HOST_HINT} -L 8188:127.0.0.1:8188"
echo
echo " Note! The actual IP address and port you need to connect to may be different"
echo " depending on your hosting provider. Check their dashboard for the correct"
echo " values if the above does not work."
echo "================================================================================"
echo

# Create SSH user with root UID (0) to avoid file permission issues in Docker
if ! id -u "$SSH_USER" >/dev/null 2>&1; then
  # Create user mapped to root (UID 0) with home set to /comfyui
  useradd -M -d /comfyui -s /bin/bash -u 0 -o "$SSH_USER" 2>/dev/null || true
else
  chsh -s /bin/bash "$SSH_USER" || true
fi
# Ensure home is set to /comfyui regardless of whether the user existed
usermod -d /comfyui "$SSH_USER" 2>/dev/null || true
passwd -d "$SSH_USER" >/dev/null 2>&1 || true   # Set empty password by default

# Allow setting a password via environment variable for additional security
if [ -n "${SSH_PASSWORD:-}" ]; then
  echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
fi

# Setup SSH key authentication if SSH_KEY is provided
if [ -n "${SSH_KEY:-}" ]; then
  # Create .ssh directory for the user inside their actual home
  SSH_HOME="$(getent passwd "$SSH_USER" | cut -d: -f6)"
  SSH_HOME="${SSH_HOME:-/comfyui}"

  mkdir -p "${SSH_HOME}/.ssh"
  chmod 700 "${SSH_HOME}/.ssh"

  # Write the public key to authorized_keys
  echo "${SSH_KEY}" > "${SSH_HOME}/.ssh/authorized_keys"
  chmod 600 "${SSH_HOME}/.ssh/authorized_keys"

  # Set proper ownership
  chown -R "${SSH_USER}:${SSH_USER}" "${SSH_HOME}/.ssh" 2>/dev/null || \
  chown -R "$(id -u "$SSH_USER")":"$(id -g "$SSH_USER")" "${SSH_HOME}/.ssh" 2>/dev/null || true
fi

# Create message of the day with connection instructions
if [ -n "${SSH_KEY:-}" ]; then
  cat >/etc/motd <<'EOF'
You are now connected through SSH (key authentication).
Access ComfyUI at: http://localhost:8188
(If you didn't start a tunnel, reconnect like this:)
  ssh -p 2222 -i <private_key_file> -L 8188:127.0.0.1:8188 <user>@<host>
EOF
else
  cat >/etc/motd <<'EOF'
You are now connected through SSH.
Access ComfyUI at: http://localhost:8188
(If you didn't start a tunnel, reconnect like this:)
  ssh -p 2222 -L 8188:127.0.0.1:8188 <user>@<host>
EOF
fi

# Configure SSH daemon with security settings
cat >/etc/ssh/sshd_config <<EOF
Port 2222
UsePAM no
PasswordAuthentication $([ -z "${SSH_KEY:-}" ] && echo yes || echo no)
KbdInteractiveAuthentication no
PermitEmptyPasswords $([ -z "${SSH_PASSWORD:-}" ] && [ -z "${SSH_KEY:-}" ] && echo yes || echo no)
PermitRootLogin yes
PubkeyAuthentication $([ -n "${SSH_KEY:-}" ] && echo yes || echo no)

AllowUsers ${SSH_USER}
AllowTcpForwarding local
PermitOpen 127.0.0.1:8188
PermitTTY yes
AllowAgentForwarding no
GatewayPorts no
X11Forwarding no
AuthorizedKeysFile $([ -n "${SSH_KEY:-}" ] && echo ".ssh/authorized_keys" || echo "none")
StrictModes yes

ClientAliveInterval 30
ClientAliveCountMax 3
TCPKeepAlive yes

PrintMotd yes
Subsystem sftp internal-sftp
EOF

# Auto-activate the ComfyUI virtual environment for interactive bash sessions
cat >/etc/profile.d/comfyui-venv.sh <<'EOF'
# Auto-activate ComfyUI venv for interactive sessions
if [ -n "${BASH_VERSION:-}" ]; then
  case $- in
    *i*)
      if [ -z "${VIRTUAL_ENV:-}" ] && [ -f /comfyui/venv/bin/activate ]; then
        . /comfyui/venv/bin/activate
      fi
    ;;
  esac
fi
EOF
chmod 0644 /etc/profile.d/comfyui-venv.sh

# Prepare SSH daemon directory and start in background
mkdir -p /run/sshd
chmod 0755 /run/sshd
sshd -t -f /etc/ssh/sshd_config
/usr/sbin/sshd -e -D -f /etc/ssh/sshd_config &

# Hand off to the main application entrypoint
exec ./entrypoint.extensions.sh "$@"
