#!/usr/bin/env bash
set -ex
START_COMMAND="/opt/apps/com.volcengine.feilian/files/corplink"
PGREP="corplink"
export MAXIMIZE="true"
export MAXIMIZE_NAME="Corplink"
export NODE_ENV=production
MAXIMIZE_SCRIPT=$STARTUPDIR/maximize_window.sh
DEFAULT_ARGS="--no-sandbox"
ARGS=${APP_ARGS:-$DEFAULT_ARGS}

options=$(getopt -o gau: -l go,assign,url: -n "$0" -- "$@") || exit
eval set -- "$options"

while [[ $1 != -- ]]; do
    case $1 in
        -g|--go) GO='true'; shift 1;;
        -a|--assign) ASSIGN='true'; shift 1;;
        -u|--url) OPT_URL=$2; shift 2;;
        *) echo "bad option: $1" >&2; exit 1;;
    esac
done
shift

# Process non-option arguments.
for arg; do
    echo "arg! $arg"
done

FORCE=$2

kasm_exec() {
    if [ -n "$OPT_URL" ] ; then
        URL=$OPT_URL
    elif [ -n "$1" ] ; then
        URL=$1
    fi 
    
    # Since we are execing into a container that already has the browser running from startup, 
    #  when we don't have a URL to open we want to do nothing. Otherwise a second browser instance would open. 
    if [ -n "$URL" ] ; then
        /usr/bin/filter_ready
        /usr/bin/desktop_ready
        bash ${MAXIMIZE_SCRIPT} &
        $START_COMMAND $ARGS $OPT_URL
    else
        echo "No URL specified for exec command. Doing nothing."
    fi
}

kasm_startup() {
    if [ -n "$KASM_URL" ] ; then
        URL=$KASM_URL
    elif [ -z "$URL" ] ; then
        URL=$LAUNCH_URL
    fi

    if [ -z "$DISABLE_CUSTOM_STARTUP" ] ||  [ -n "$FORCE" ] ; then

        echo "Entering process startup loop"
        set +x
        while true
        do
            if ! pgrep -x $PGREP > /dev/null
            then
                /usr/bin/filter_ready
                /usr/bin/desktop_ready
                set +e
                bash ${MAXIMIZE_SCRIPT} &
                $START_COMMAND $ARGS $URL
                set -e
            fi
            sleep 1
        done
        set -x
    
    fi

} 
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

sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t nat -A POSTROUTING -j MASQUERADE
sudo iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
sudo /usr/bin/supervisord 2>/dev/null || true

if [ -n "$GO" ] || [ -n "$ASSIGN" ] ; then
    kasm_exec
else
    kasm_startup
fi


