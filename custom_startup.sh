#!/bin/bash
echo ">>> Injecting VPN bypass routes (Kasm Official Source-IP Style)..."

# 1. 获取默认网关
GW=$(sudo ip route show default | awk '/default/ {print $3}' | head -n1)
# 2. 获取 eth0 网卡（容器生命线）的真实 IP 地址
ETH0_IP=$(sudo ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -n "$GW" ] && [ -n "$ETH0_IP" ]; then
    # 3. 创建 128 专属路由表，指明出口为原网关
    sudo ip route add default via $GW dev eth0 table 128 || true

    # 4. 核心魔法（官方方案）：只要源 IP 是 eth0 的，就强制查 128 表
    sudo ip rule add from $ETH0_IP table 128 priority 100 || true

    echo ">>> Bypass rules injected successfully. IP: $ETH0_IP, Gateway: $GW"
else
    echo ">>> Warning: Could not detect default gateway or eth0 IP!"
fi