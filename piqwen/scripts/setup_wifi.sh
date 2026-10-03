#!/bin/bash
# PiQwen Wi-Fi Hotspot Setup Script
# Configures Raspberry Pi as a Wi-Fi access point

set -e

echo "========================================"
echo "PiQwen Wi-Fi Hotspot Configuration"
echo "========================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Configuration
SSID="PiQwen"
PASSWORD="piqwen2024"
INTERFACE="wlan0"
AP_IP="192.168.4.1"
NETMASK="255.255.255.0"
DHCP_START="192.168.4.10"
DHCP_END="192.168.4.100"

# Prompt for password
read -p "Enter Wi-Fi password (min 8 chars) [$PASSWORD]: " INPUT_PASSWORD
if [[ -n "$INPUT_PASSWORD" ]]; then
    if [[ ${#INPUT_PASSWORD} -lt 8 ]]; then
        echo "Password must be at least 8 characters"
        exit 1
    fi
    PASSWORD="$INPUT_PASSWORD"
fi

read -p "Enter SSID [$SSID]: " INPUT_SSID
if [[ -n "$INPUT_SSID" ]]; then
    SSID="$INPUT_SSID"
fi

echo ""
echo "Configuring hotspot with:"
echo "  SSID: $SSID"
echo "  Password: $PASSWORD"
echo "  Interface: $INTERFACE"
echo "  AP IP: $AP_IP"
echo ""

# Backup existing configs
echo "Backing up existing configurations..."
cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.backup 2>/dev/null || true
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true
cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup 2>/dev/null || true

# Stop services
echo "Stopping services..."
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

# Configure hostapd
echo "Configuring hostapd..."
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$INTERFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
ieee80211n=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
EOF

# Update hostapd default config
cat > /etc/default/hostapd <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

# Configure dnsmasq
echo "Configuring dnsmasq..."
cat > /etc/dnsmasq.conf <<EOF
interface=$INTERFACE
dhcp-range=$DHCP_START,$DHCP_END,$NETMASK,24h
dhcp-option=3,$AP_IP
dhcp-option=6,$AP_IP
server=8.8.8.8
server=8.8.4.4
log-queries
log-dhcp
listen-address=$AP_IP
bind-interfaces
EOF

# Configure dhcpcd for static IP on wlan0
echo "Configuring dhcpcd..."
# Remove any existing wlan0 config
sed -i '/^interface wlan0$/,/^$/d' /etc/dhcpcd.conf
cat >> /etc/dhcpcd.conf <<EOF

interface $INTERFACE
static ip_address=$AP_IP/24
nohook wpa_supplicant
EOF

# Enable IP forwarding
echo "Enabling IP forwarding..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Configure NAT (optional - for internet sharing if needed)
echo "Configuring NAT..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -A FORWARD -i eth0 -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i $INTERFACE -o eth0 -j ACCEPT 2>/dev/null || true

# Save iptables rules
apt-get install -y iptables-persistent 2>/dev/null || true
netfilter-persistent save 2>/dev/null || true

# Unmask and enable services
echo "Enabling services..."
systemctl unmask hostapd 2>/dev/null || true
systemctl enable hostapd
systemctl enable dnsmasq

# Start services
echo "Starting services..."
systemctl start hostapd
systemctl start dnsmasq

# Wait a moment for services to start
sleep 2

# Check status
echo ""
echo "Checking service status..."
systemctl status hostapd --no-pager -l
echo ""
systemctl status dnsmasq --no-pager -l

echo ""
echo "========================================"
echo "Wi-Fi Hotspot Configured!"
echo "========================================"
echo ""
echo "SSID: $SSID"
echo "Password: $PASSWORD"
echo "AP IP: $AP_IP"
echo ""
echo "Connect your Apple Watch to '$SSID' network"
echo "Then test connection at: http://$AP_IP:8000/health"
echo ""
echo "To change password later, run this script again."