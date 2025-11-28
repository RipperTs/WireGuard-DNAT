#!/bin/bash

CONFIG_DIR="/etc/wireguard"
WG_CONF_FILE="$CONFIG_DIR/wg0.conf"
WG_SERVICE_NAME="wg-quick@wg0"
DEFAULT_WG_PORT=51820
VPN_NET_IP="10.10.0.1"
VPN_NET_CIDR="10.10.0.1/24"
CLIENT_VPN_IP="10.10.0.2/32"

require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 或 sudo 运行本脚本。"
    exit 1
  fi
}

detect_local_ip_and_iface() {
  route_info=$(ip -4 route get 1.1.1.1 2>/dev/null | head -n1)
  LOCAL_IFACE=$(echo "$route_info" | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
  LOCAL_IP=$(echo "$route_info" | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

  if [ -z "$LOCAL_IFACE" ] || [ -z "$LOCAL_IP" ]; then
    echo "自动检测失败，请手动输入："
    read -rp "请输入云服务器内网IP（例如 10.2.20.11）：" LOCAL_IP
    read -rp "请输入出口网卡名（例如 eth0）：" LOCAL_IFACE
  fi

  echo "检测到内网 IP: $LOCAL_IP, 出口网卡: $LOCAL_IFACE"
}

disable_firewalls() {
  echo "关闭系统防火墙..."

  if command -v ufw >/dev/null 2>&1; then
    ufw disable || true
  fi

  iptables -F
  iptables -X
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT

  echo "🔥 所有端口已开放，防火墙已关闭。"
}

install_server() {
  require_root
  echo "开始安装 WireGuard 服务端..."

  apt update
  apt install -y wireguard iproute2 iptables

  detect_local_ip_and_iface

  read -rp "请输入 WireGuard 监听端口（默认 ${DEFAULT_WG_PORT}）：" WG_PORT
  WG_PORT=${WG_PORT:-$DEFAULT_WG_PORT}

  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"

  SERVER_PRIVATE_KEY=$(wg genkey)
  SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

  cat > "$WG_CONF_FILE" <<EOF
[Interface]
Address = ${VPN_NET_CIDR}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}

# 开启内核转发
PostUp   = sysctl -w net.ipv4.ip_forward=1

# 1）对从 ${LOCAL_IFACE} 进来的流量做 DNAT（避免本机自己访问 ${LOCAL_IP} 也被转走）
# 2）排除 WireGuard 自己的 ${WG_PORT} 端口
PostUp   = iptables -t nat -A PREROUTING -i ${LOCAL_IFACE} -d ${LOCAL_IP} -p udp ! --dport ${WG_PORT} -j DNAT --to-destination 10.10.0.2
PostUp   = iptables -t nat -A PREROUTING -i ${LOCAL_IFACE} -d ${LOCAL_IP} -p tcp -j DNAT --to-destination 10.10.0.2

# 出口 SNAT 把从客户端来的流量伪装成 ${LOCAL_IP}
PostUp   = iptables -t nat -A POSTROUTING -s 10.10.0.2 -o ${LOCAL_IFACE} -j SNAT --to-source ${LOCAL_IP}

PostDown = iptables -t nat -D PREROUTING -i ${LOCAL_IFACE} -d ${LOCAL_IP} -p udp ! --dport ${WG_PORT} -j DNAT --to-destination 10.10.0.2
PostDown = iptables -t nat -D PREROUTING -i ${LOCAL_IFACE} -d ${LOCAL_IP} -p tcp -j DNAT --to-destination 10.10.0.2
PostDown = iptables -t nat -D POSTROUTING -s 10.10.0.2 -o ${LOCAL_IFACE} -j SNAT --to-source ${LOCAL_IP}

[Peer]
# 修改此行替换成客户端公钥
PublicKey = CLIENT_PUBLIC_KEY_PLACEHOLDER
AllowedIPs = ${CLIENT_VPN_IP}
EOF

  chmod 600 "$WG_CONF_FILE"

  disable_firewalls

  systemctl enable "${WG_SERVICE_NAME}"
  systemctl restart "${WG_SERVICE_NAME}"

  echo "=============================================="
  echo "✅ WireGuard 服务端安装完成"
  echo
  echo "🔑 服务端公钥（客户端需要填入）："
  echo "$SERVER_PUBLIC_KEY"
  echo
  echo "📌 云服务器内网 IP：${LOCAL_IP}"
  echo "📌 WireGuard 监听端口：${WG_PORT}"
  echo "📌 配置文件路径：${WG_CONF_FILE}"
  echo
  echo "⚠️ 请把客户端公钥填回 wg0.conf（替换 CLIENT_PUBLIC_KEY_PLACEHOLDER）"
  echo "=============================================="
}

uninstall_server() {
  require_root
  echo "卸载 WireGuard 服务端..."
  systemctl stop "${WG_SERVICE_NAME}" 2>/dev/null || true
  systemctl disable "${WG_SERVICE_NAME}" 2>/dev/null || true
  apt purge -y wireguard wireguard-tools 2>/dev/null || true
  rm -rf "$CONFIG_DIR"
  echo "🔥 WireGuard 及配置已全部删除。"
}

start_server() {
  require_root
  echo "启动 WireGuard..."
  systemctl start "${WG_SERVICE_NAME}"
  echo "已启动。"
}

stop_server() {
  require_root
  echo "停止 WireGuard..."
  systemctl stop "${WG_SERVICE_NAME}"
  echo "已停止。"
}

show_info() {
  require_root
  echo "=== 当前状态 ==="
  wg show || echo "WireGuard 未运行"
}

echo "============== WireGuard 服务端管理 =============="
echo "1) 安装并初始化服务端（含关闭防火墙）"
echo "2) 卸载服务端并删除全部配置"
echo "3) 启动 WireGuard"
echo "4) 停止 WireGuard"
echo "5) 查看当前状态"
echo "=================================================="
read -rp "请选择(1-5): " choice

case "$choice" in
  1) install_server ;;
  2) uninstall_server ;;
  3) start_server ;;
  4) stop_server ;;
  5) show_info ;;
  *) echo "输入错误"; exit 1 ;;
esac

