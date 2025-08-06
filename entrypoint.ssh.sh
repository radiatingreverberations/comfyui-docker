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

# SSH host key setup and fingerprint generation
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A

# Get host key fingerprint for display
FPR="$(ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key | awk '{print $2}')"

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

# Create SSH user account with appropriate settings
if ! id -u "$SSH_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$SSH_USER"
else
  chsh -s /bin/bash "$SSH_USER" || true
fi
passwd -d "$SSH_USER" >/dev/null 2>&1 || true   # Set empty password by default

# Allow setting a password via environment variable for additional security
if [ -n "${SSH_PASSWORD:-}" ]; then
  echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
fi

# Create message of the day with connection instructions
cat >/etc/motd <<'EOF'
You are now connected through SSH.
Access ComfyUI at: http://localhost:8188
(If you didn't start a tunnel, reconnect like this:)
  ssh -p 2222 -L 8188:127.0.0.1:8188 <user>@<host>
EOF

# Configure SSH daemon with security settings
cat >/etc/ssh/sshd_config <<EOF
Port 2222
UsePAM no
PasswordAuthentication yes
KbdInteractiveAuthentication no
PermitEmptyPasswords $([ -z "${SSH_PASSWORD:-}" ] && echo yes || echo no)
PubkeyAuthentication no

AllowUsers ${SSH_USER}
AllowTcpForwarding local
PermitOpen 127.0.0.1:8188
PermitTTY yes
AllowAgentForwarding no
GatewayPorts no
X11Forwarding no
AuthorizedKeysFile none
StrictModes yes

ClientAliveInterval 30
ClientAliveCountMax 3
TCPKeepAlive yes

PrintMotd yes
Subsystem sftp internal-sftp
EOF

# Prepare SSH daemon directory and start in background
mkdir -p /run/sshd
chmod 0755 /run/sshd
sshd -t -f /etc/ssh/sshd_config
/usr/sbin/sshd -e -D -f /etc/ssh/sshd_config &

# Hand off to the main application entrypoint
exec ./entrypoint.extensions.sh "$@"
