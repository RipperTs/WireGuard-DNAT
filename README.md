# WireGuard-DNAT
基于WireGuard全端口映射给内网服务器分配公网IP   

目前仅在 Ubuntu 22 系统上进行测试

## 安装

### 云服务器端
安装脚本：
```bash
wget https://raw.githubusercontent.com/RipperTs/WireGuard-DNAT/refs/heads/main/cloud-server-install.sh -O wireguard-install.sh

# 启动
chmod 755 ./wireguard-install.sh && ./wireguard-install.sh
```

### 内网机器
安装脚本：
```bash
wget https://raw.githubusercontent.com/RipperTs/WireGuard-DNAT/refs/heads/main/setup-wg-client.sh -O setup-wg-client.sh

# 启动
chmod 755 ./setup-wg-client.sh && ./setup-wg-client.sh
```

## 使用
- 首先在云服务器上执行脚本，得到公钥和服务器外网IP
- 在内网机器上执行脚本，填写服务器公网IP和公钥，最后得到一个内网服务器的公钥
- 将内网服务器公钥填写到云服务器的配置文件中的指定位置
- 重启云服务器的 WireGuard 服务
- 重启内网服务器的 WireGuard 服务
