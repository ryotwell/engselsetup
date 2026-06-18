#!/bin/bash
# OS: Debian 11
set -euo pipefail

# ==========================================
# Config
# ==========================================
DOMAIN="id2.engsel.qzz.io"
SWAP_SIZE="3G"
NOFILE_LIMIT=1048576

log() { echo -e "\n\e[1;34m>>> $1\e[0m"; }

# ==========================================
# BBR
# ==========================================
log "Mengaktifkan BBR..."
cat > /etc/sysctl.d/99-bbr.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl --system

# ==========================================
# Swap
# ==========================================
log "Mengatur swap ${SWAP_SIZE}..."
if [ -f /swapfile ]; then
    swapoff /swapfile
    rm -f /swapfile
    sed -i '/\/swapfile/d' /etc/fstab
fi
fallocate -l "${SWAP_SIZE}" /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap sw 0 0" >> /etc/fstab

# ==========================================
# Optimasi sysctl
# ==========================================
log "Mengoptimasi sysctl..."
cp /etc/sysctl.conf /etc/sysctl.conf.bak
cat > /etc/sysctl.conf <<EOF
# Queue
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 250000

# TCP
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1

# Memory
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Keepalive
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Swap
vm.swappiness = 4
EOF
sysctl -p

# ==========================================
# File Descriptor
# ==========================================
log "Menaikkan batas file descriptor..."
cat > /etc/security/limits.conf <<EOF
* soft nofile ${NOFILE_LIMIT}
* hard nofile ${NOFILE_LIMIT}
root soft nofile ${NOFILE_LIMIT}
root hard nofile ${NOFILE_LIMIT}
EOF

cat > /etc/systemd/system.conf <<EOF
[Manager]
DefaultLimitNOFILE=${NOFILE_LIMIT}
EOF

cat > /etc/systemd/user.conf <<EOF
[Manager]
DefaultLimitNOFILE=${NOFILE_LIMIT}
EOF

systemctl daemon-reexec

# ==========================================
# Install & Konfigurasi Nginx
# ==========================================
log "Menginstall Nginx..."
apt-get update -qq
apt-get install -y nginx

log "Mengkonfigurasi Nginx untuk domain: ${DOMAIN}..."
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak 2>/dev/null || true
cp nginx.conf /etc/nginx/nginx.conf

# Parse domain: comma-separated → first domain & space-separated list
FIRST_DOMAIN="${DOMAIN%%,*}"
DOMAIN_LIST="${DOMAIN//,/ }"

sed -i "s/DOMAIN_CERT/${FIRST_DOMAIN}/g" engsel.conf
sed -i "s/DOMAIN_LIST/${DOMAIN_LIST}/g" engsel.conf
cp engsel.conf /etc/nginx/conf.d/engsel.conf

log "Menguji konfigurasi Nginx..."
nginx -t

log "Merestart Nginx..."
systemctl restart nginx

log "Setup selesai!"

# curl https://get.acme.sh | sh
# ~/.acme.sh/acme.sh --issue -d id.engsel.qzz.io --standalone -k ec-256
# ~/.acme.sh/acme.sh --installcert -d id.engsel.qzz.io --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

# # Berikan akses baca ke file sertifikat
# chmod 644 /etc/xray/xray.crt
# chmod 644 /etc/xray/xray.key

# # Restart service yang menggunakan sertifikat tersebut (pilih salah satu)
# systemctl restart xray
# # ATAU
# systemctl restart nginx