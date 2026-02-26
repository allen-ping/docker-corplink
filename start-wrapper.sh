#!/bin/bash
echo ">>> Injecting VPN bypass routes..."

# 获取 Docker 分配给容器的原始网关 IP
GW=$(ip route show default | awk '/default/ {print $3}' | head -n1)

if [ -n "$GW" ]; then
    # 建立 128 专属路由表
    ip route add default via $GW dev eth0 table 128 || echo "Failed to add route"

    # 给 VNC 和代理端口打标记 (0x100)
    iptables -t mangle -A OUTPUT -p tcp -m multiport --sports 6901,8888,1088 -j MARK --set-mark 0x100 || echo "Failed to add iptables mark"

    # 应用策略路由
    ip rule add fwmark 0x100 table 128 priority 100 || echo "Failed to add ip rule"

    echo ">>> Bypass rules injected successfully. Gateway: $GW"
else
    echo ">>> Warning: Could not detect default gateway!"
fi

echo ">>> Starting KasmVNC..."
# 移交控制权：执行 Kasm 原始的启动脚本，并传递所有参数
exec /dockerstartup/vnc_startup.sh "$@"