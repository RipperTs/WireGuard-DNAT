#!/bin/bash

# 初始化
CONFIG_DIR="/etc/wireguard"
WG_CONF_FILE="$CONFIG_DIR/wg0.conf"
WG_SERVICE_NAME="wg-quick@wg0"

# 安装函数
install_wireguard() {
    echo "安装 WireGuard ..."
    # 更新并安装 WireGuard
    sudo apt update
    sudo apt install wireguard -y

    # 获取用户输入
    echo "请输入云服务器的公网IP（例如 49.233.31.159）："
    read SERVER_IP

    echo "请输入云服务器的公钥："
    read SERVER_PUBLIC_KEY

    # 自动生成内网私钥和公钥
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

    # 创建 WireGuard 配置文件
    sudo mkdir -p $CONFIG_DIR

    # 输出配置信息
    echo "[Interface]
Address = 10.10.0.2/24
PrivateKey = $CLIENT_PRIVATE_KEY

# 让内网服务器的出口走云服务器（可选）
PostUp = ip route add default dev wg0 table 200
PostUp = ip rule add from 10.10.0.2 table 200
PostDown = ip rule del from 10.10.0.2 table 200
PostDown = ip route del default dev wg0 table 200

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 15" | sudo tee $WG_CONF_FILE

    # 启动 WireGuard 服务
    sudo systemctl enable $WG_SERVICE_NAME
    sudo systemctl start $WG_SERVICE_NAME

    echo "WireGuard 安装并配置成功！"
    echo "你可以通过执行 'sudo wg show' 来查看连接状态。"
    echo "内网服务器私钥：$CLIENT_PRIVATE_KEY"
    echo "内网服务器公钥：$CLIENT_PUBLIC_KEY"
}

# 卸载函数
uninstall_wireguard() {
    echo "卸载 WireGuard ..."
    sudo systemctl stop $WG_SERVICE_NAME
    sudo systemctl disable $WG_SERVICE_NAME
    sudo apt purge wireguard -y
    sudo rm -rf $CONFIG_DIR
    echo "WireGuard 已完全卸载并删除配置文件。"
}

# 启动 WireGuard 服务
start_wireguard() {
    echo "启动 WireGuard 服务 ..."
    sudo systemctl start $WG_SERVICE_NAME
    echo "WireGuard 服务已启动！"
}

# 停止 WireGuard 服务
stop_wireguard() {
    echo "停止 WireGuard 服务 ..."
    sudo systemctl stop $WG_SERVICE_NAME
    echo "WireGuard 服务已停止！"
}

# 主菜单
echo "请选择操作："
echo "1. 安装 WireGuard 客户端"
echo "2. 卸载 WireGuard 客户端"
echo "3. 启动 WireGuard 服务"
echo "4. 停止 WireGuard 服务"
read -p "请输入数字选择操作（1/2/3/4）: " choice

case $choice in
    1)
        install_wireguard
        ;;
    2)
        uninstall_wireguard
        ;;
    3)
        start_wireguard
        ;;
    4)
        stop_wireguard
        ;;
    *)
        echo "无效的选择！"
        exit 1
        ;;
esac
