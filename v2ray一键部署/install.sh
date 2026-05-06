#!/bin/bash

# V2Ray 多协议一键部署脚本
# 支持 VMess / VLESS / Trojan / Shadowsocks
# 无交互安装: bash <(curl -L https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh) --UUID xxx --PORT 1080 ...
# 交互安装: sudo bash install.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 配置变量
INSTALL_DIR="/usr/local/v2ray"
CONFIG_DIR="/etc/v2ray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
V2RAY_VERSION="v5.10.0"
V2RAY_URL="https://github.com/v2fly/v2ray-core/releases/download/${V2RAY_VERSION}/v2ray-linux-64.zip"

# 默认值
DEFAULT_VMESS_PORT=1080
DEFAULT_VMESS_WS_PORT=10086
DEFAULT_SS_PORT=8388
DEFAULT_TROJAN_PORT=443
DEFAULT_VLESS_PORT=443

# 全局变量
VMESS_UUID=""
VLESS_UUID=""
TROJAN_PASSWORD=""
SS_PASSWORD=""
VMESS_PORT=""
VMESS_WS_PORT=""
SS_PORT=""
SERVER_IP=""
LANGUAGE="cn"

# 帮助信息
show_help() {
    cat << EOF
${GREEN}V2Ray 多协议一键部署脚本${NC}
${YELLOW}支持无交互安装和交互式安装${NC}

${CYAN}用法:${NC}
    bash <(curl -L https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh) [选项]

${CYAN}无交互安装示例:${NC}
    bash <(curl -L https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh) \\
        --uuid auto \\
        --port 1080 \\
        --ws-port 10086 \\
        --ss-port 8388 \\
        --server-ip auto

${CYAN}选项:${NC}
    --uuid              VMess/VLESS 的 UUID（auto = 自动生成）
    --port              VMess TCP 端口（默认: 1080）
    --ws-port           VMess WebSocket 端口（默认: 10086）
    --ss-port           Shadowsocks 端口（默认: 8388）
    --server-ip         服务器 IP（auto = 自动获取）
    --language          语言: cn/en（默认: cn）
    --trojan-port       Trojan 端口（默认: 443，与 VLESS 共用）
    --help              显示此帮助信息

${CYAN}纯交互式安装:${NC}
    sudo bash install.sh

${CYAN}管理命令:${NC}
    systemctl start v2ray    # 启动
    systemctl stop v2ray     # 停止
    systemctl restart v2ray  # 重启
    systemctl status v2ray   # 状态
    cat /etc/v2ray/config.txt    # 查看配置链接

EOF
    exit 0
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --uuid)
                VMESS_UUID="$2"
                VLESS_UUID="$2"
                shift 2
                ;;
            --port)
                VMESS_PORT="$2"
                shift 2
                ;;
            --ws-port)
                VMESS_WS_PORT="$2"
                shift 2
                ;;
            --ss-port)
                SS_PORT="$2"
                shift 2
                ;;
            --trojan-port)
                TROJAN_PORT="$2"
                shift 2
                ;;
            --vless-port)
                VLESS_PORT="$2"
                shift 2
                ;;
            --server-ip)
                SERVER_IP="$2"
                shift 2
                ;;
            --language)
                LANGUAGE="$2"
                shift 2
                ;;
            --help)
                show_help
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                show_help
                ;;
        esac
    done
}

# 生成随机字符串
generate_random_string() {
    cat /dev/urandom | tr -dc 'a-z0-9' | fold -w ${1:-32} | head -n 1
}

# 生成 UUID
generate_uuid() {
    if [[ -x "${INSTALL_DIR}/v2ctl" ]]; then
        ${INSTALL_DIR}/v2ctl uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# 获取服务器 IP
get_server_ip() {
    curl -s4 --connect-timeout 5 ifconfig.me || \
    curl -s4 --connect-timeout 5 icanhazip.com || \
    curl -s4 --connect-timeout 5 ipinfo.io/ip || \
    curl -s6 --connect-timeout 5 ifconfig.me || \
    echo "YOUR_SERVER_IP"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}请使用 root 权限运行此脚本${NC}"
        echo -e "${YELLOW}请运行: sudo bash $0${NC}"
        exit 1
    fi
}

# 检测系统
detect_os() {
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
        echo -e "${GREEN}检测到 Debian/Ubuntu 系统${NC}"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        echo -e "${GREEN}检测到 CentOS/RHEL 系统${NC}"
    elif [[ -f /etc/alpine-release ]]; then
        OS="alpine"
        echo -e "${GREEN}检测到 Alpine Linux 系统${NC}"
    else
        OS="unknown"
        echo -e "${YELLOW}未知系统，尝试继续安装...${NC}"
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}安装依赖...${NC}"

    if [[ $OS == "debian" ]]; then
        apt update -qq 2>/dev/null || true
        apt install -y -qq curl wget unzip jq 2>/dev/null || apt install -y curl wget unzip jq
    elif [[ $OS == "centos" ]]; then
        yum install -y -q curl wget unzip jq 2>/dev/null || yum install -y curl wget unzip jq
    elif [[ $OS == "alpine" ]]; then
        apk add --quiet curl wget unzip jq bash 2>/dev/null || apk add curl wget unzip jq bash
    else
        echo -e "${YELLOW}尝试安装基础依赖...${NC}"
        which curl wget unzip jq >/dev/null 2>&1 || {
            echo -e "${RED}请手动安装 curl wget unzip jq${NC}"
            exit 1
        }
    fi
}

# 选择下载方式
select_download_method() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}V2Ray 多协议一键部署脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1. 从 GitHub 官方下载"
    echo "2. 从 ghproxy 镜像下载（推荐国内）"
    echo "3. 退出"
    echo ""

    read -p "请选择下载方式 [1-3]: " choice

    case $choice in
        1)
            DOWNLOAD_URL="${V2RAY_URL}"
            echo -e "${GREEN}使用 GitHub 官方下载...${NC}"
            ;;
        2)
            DOWNLOAD_URL="https://ghproxy.net/${V2RAY_URL}"
            echo -e "${GREEN}使用 ghproxy 镜像下载...${NC}"
            ;;
        3)
            echo -e "${YELLOW}退出安装${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            exit 1
            ;;
    esac
}

# 下载 V2Ray
download_v2ray() {
    echo -e "${BLUE}下载 V2Ray...${NC}"

    cd /tmp

    if wget -q --show-progress --progress=bar:force:noscroll -O v2ray.zip "${DOWNLOAD_URL}"; then
        echo -e "${GREEN}V2Ray 下载完成${NC}"
    else
        echo -e "${RED}V2Ray 下载失败，尝试备用地址...${NC}"
        BACKUP_URL="https://mirror.ghproxy.com/${V2RAY_URL}"
        wget -q --show-progress --progress=bar:force:noscroll -O v2ray.zip "${BACKUP_URL}" || {
            echo -e "${RED}下载失败，请检查网络连接${NC}"
            exit 1
        }
    fi
}

# 安装 V2Ray
install_v2ray() {
    echo -e "${BLUE}安装 V2Ray...${NC}"

    mkdir -p ${INSTALL_DIR}
    mkdir -p ${CONFIG_DIR}

    cd /tmp
    unzip -o v2ray.zip -d v2ray_temp

    cp v2ray_temp/v2ray ${INSTALL_DIR}/
    cp v2ray_temp/v2ctl ${INSTALL_DIR}/
    cp v2ray_temp/geoip.dat ${INSTALL_DIR}/
    cp v2ray_temp/geosite.dat ${INSTALL_DIR}/

    chmod +x ${INSTALL_DIR}/v2ray
    chmod +x ${INSTALL_DIR}/v2ctl

    rm -rf /tmp/v2ray.zip /tmp/v2ray_temp

    echo -e "${GREEN}V2Ray 安装完成${NC}"
}

# 配置防火墙
configure_firewall() {
    echo -e "${BLUE}配置防火墙...${NC}"

    PORTS="${VMESS_PORT} ${VMESS_WS_PORT} ${SS_PORT} 443 80"

    if command -v ufw &>/dev/null; then
        for port in $PORTS; do
            ufw allow $port/tcp >/dev/null 2>&1 || true
            ufw allow $port/udp >/dev/null 2>&1 || true
        done
        echo -e "${GREEN}UFW 防火墙已配置${NC}"
    elif command -v firewall-cmd &>/dev/null; then
        for port in $PORTS; do
            firewall-cmd --permanent --add-port=$port/tcp >/dev/null 2>&1 || true
            firewall-cmd --permanent --add-port=$port/udp >/dev/null 2>&1 || true
        done
        firewall-cmd --reload >/dev/null 2>&1 || true
        echo -e "${GREEN}Firewalld 防火墙已配置${NC}"
    elif command -v iptables &>/dev/null; then
        for port in $PORTS; do
            iptables -I INPUT -p tcp --dport $port -j ACCEPT >/dev/null 2>&1 || true
            iptables -I INPUT -p udp --dport $port -j ACCEPT >/dev/null 2>&1 || true
        done
        echo -e "${GREEN}IPTables 防火墙已配置${NC}"
    else
        echo -e "${YELLOW}未检测到防火墙，请手动开放端口: ${PORTS}${NC}"
    fi
}

# 生成多协议配置
generate_config() {
    echo -e "${BLUE}生成多协议配置...${NC}"

    # 如果 UUID 为空，生成新的
    if [[ -z "${VMESS_UUID}" ]] || [[ "${VMESS_UUID}" == "auto" ]]; then
        VMESS_UUID=$(generate_uuid)
    fi
    if [[ -z "${VLESS_UUID}" ]] || [[ "${VLESS_UUID}" == "auto" ]]; then
        VLESS_UUID=$(generate_uuid)
    fi

    TROJAN_PASSWORD=$(generate_random_string 32)
    SS_PASSWORD=$(generate_random_string 16)

    # 设置默认端口
    VMESS_PORT=${VMESS_PORT:-${DEFAULT_VMESS_PORT}}
    VMESS_WS_PORT=${VMESS_WS_PORT:-${DEFAULT_VMESS_WS_PORT}}
    SS_PORT=${SS_PORT:-${DEFAULT_SS_PORT}}

    # 获取服务器 IP
    if [[ -z "${SERVER_IP}" ]] || [[ "${SERVER_IP}" == "auto" ]]; then
        SERVER_IP=$(get_server_ip)
    fi

    cat > ${CONFIG_FILE} << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${VMESS_PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${VMESS_UUID}",
            "alterId": 0,
            "email": "vmess@example.com"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      }
    },
    {
      "port": ${VMESS_WS_PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${VMESS_UUID}",
            "alterId": 0,
            "email": "vmess_ws@example.com"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/v2ray"
        }
      }
    },
    {
      "port": ${DEFAULT_TROJAN_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${VLESS_UUID}",
            "email": "vless@example.com",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/v2ray/cert.crt",
              "keyFile": "/etc/v2ray/key.key"
            }
          ]
        }
      }
    },
    {
      "port": ${DEFAULT_TROJAN_PORT},
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${TROJAN_PASSWORD}",
            "email": "trojan@example.com"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/v2ray/cert.crt",
              "keyFile": "/etc/v2ray/key.key"
            }
          ]
        }
      }
    },
    {
      "port": ${SS_PORT},
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-256-gcm",
        "password": "${SS_PASSWORD}",
        "network": "tcp,udp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

    echo -e "${GREEN}配置文件已生成${NC}"
}

# 生成自签名证书
generate_self_signed_cert() {
    echo -e "${BLUE}生成自签名证书（仅用于测试，生产环境请使用 Let's Encrypt）...${NC}"

    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout ${CONFIG_DIR}/key.key \
        -out ${CONFIG_DIR}/cert.crt \
        -subj "/CN=${SERVER_IP}" \
        -days 3650 2>/dev/null || {

        openssl req -x509 -nodes -newkey rsa:2048 \
            -keyout ${CONFIG_DIR}/key.key \
            -out ${CONFIG_DIR}/cert.crt \
            -subj "/CN=${SERVER_IP}" \
            -days 3650
    }

    echo -e "${GREEN}自签名证书已生成${NC}"
}

# 配置 systemd 服务
configure_systemd() {
    echo -e "${BLUE}配置 systemd 服务...${NC}"

    cat > /etc/systemd/system/v2ray.service << 'EOF'
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/v2ray/v2ray run -config /etc/v2ray/config.json
Restart=on failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable v2ray
    systemctl start v2ray

    if systemctl is-active --quiet v2ray; then
        echo -e "${GREEN}V2Ray 服务已启动${NC}"
    else
        echo -e "${RED}V2Ray 服务启动失败，请检查日志: journalctl -u v2ray -n 50${NC}"
    fi
}

# 生成客户端配置信息
generate_client_info() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}        V2Ray 部署完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    echo -e "${YELLOW}━━━━━━━━ 服务器信息 ━━━━━━━━${NC}"
    echo -e "  服务器 IP: ${GREEN}${SERVER_IP}${NC}"
    echo ""

    echo -e "${YELLOW}━━━━━━━━ VMess (TCP) ━━━━━━━━${NC}"
    echo -e "  地址:     ${SERVER_IP}"
    echo -e "  端口:     ${VMESS_PORT}"
    echo -e "  UUID:     ${VMESS_UUID}"
    echo -e "  AlterId:  0"
    echo -e "  传输协议: tcp"
    echo ""

    echo -e "${YELLOW}━━━━━━━━ VMess (WebSocket) ━━━━━━━━${NC}"
    echo -e "  地址:     ${SERVER_IP}"
    echo -e "  端口:     ${VMESS_WS_PORT}"
    echo -e "  UUID:     ${VMESS_UUID}"
    echo -e "  AlterId:  0"
    echo -e "  传输协议: ws"
    echo -e "  路径:     /v2ray"
    echo ""

    echo -e "${YELLOW}━━━━━━━━ VLESS (TLS) ━━━━━━━━${NC}"
    echo -e "  地址:     ${SERVER_IP}"
    echo -e "  端口:     ${DEFAULT_TROJAN_PORT}"
    echo -e "  UUID:     ${VLESS_UUID}"
    echo -e "  传输协议: tcp"
    echo -e "  TLS:      开启"
    echo ""

    echo -e "${YELLOW}━━━━━━━━ Trojan (TLS) ━━━━━━━━${NC}"
    echo -e "  地址:     ${SERVER_IP}"
    echo -e "  端口:     ${DEFAULT_TROJAN_PORT}"
    echo -e "  密码:     ${TROJAN_PASSWORD}"
    echo ""

    echo -e "${YELLOW}━━━━━━━━ Shadowsocks ━━━━━━━━${NC}"
    echo -e "  地址:     ${SERVER_IP}"
    echo -e "  端口:     ${SS_PORT}"
    echo -e "  密码:     ${SS_PASSWORD}"
    echo -e "  加密方式: aes-256-gcm"
    echo ""

    # 生成分享链接
    VMESS_TCP_LINK="vmess://$(echo "{\"add\":\"${SERVER_IP}\",\"aid\":\"0\",\"host\":\"\",\"id\":\"${VMESS_UUID}\",\"net\":\"tcp\",\"path\":\"\",\"port\":\"${VMESS_PORT}\",\"ps\":\"vmess-tcp\",\"tls\":\"\",\"type\":\"none\",\"v\":\"2\"}" | base64 -w 0)"
    VMESS_WS_LINK="vmess://$(echo "{\"add\":\"${SERVER_IP}\",\"aid\":\"0\",\"host\":\"\",\"id\":\"${VMESS_UUID}\",\"net\":\"ws\",\"path\":\"/v2ray\",\"port\":\"${VMESS_WS_PORT}\",\"ps\":\"vmess-ws\",\"tls\":\"\",\"type\":\"none\",\"v\":\"2\"}" | base64 -w 0)"
    VLESS_LINK="vless://${VLESS_UUID}@${SERVER_IP}:443?encryption=none&security=tls&type=tcp&host=${SERVER_IP}#vless-tls"
    TROJAN_LINK="trojan://${TROJAN_PASSWORD}@${SERVER_IP}:443#trojan-tls"
    SS_LINK="ss://YWVzLTI1Ni1nY206${SS_PASSWORD}@${SERVER_IP}:${SS_PORT}#shadowsocks"

    ALL_LINKS="${VMESS_TCP_LINK}
${VMESS_WS_LINK}
${VLESS_LINK}
${TROJAN_LINK}
${SS_LINK}"

    SUBSCRIPTION_BASE64=$(echo -n "${ALL_LINKS}" | base64 -w 0)

    echo "${ALL_LINKS}" > ${CONFIG_DIR}/config.txt
    echo "${SUBSCRIPTION_BASE64}" > ${CONFIG_DIR}/subscription.txt

    echo -e "${CYAN}━━━━━━━━ 订阅链接 ━━━━━━━━${NC}"
    echo -e "${GREEN}复制以下链接，粘贴到客户端订阅设置中:${NC}"
    echo ""
    echo -e "${MAGENTA}${SUBSCRIPTION_BASE64}${NC}"
    echo ""

    echo -e "${CYAN}━━━━━━━━ 单独分享链接 ━━━━━━━━${NC}"
    echo -e "${GREEN}VMess TCP:${NC}"
    echo "${VMESS_TCP_LINK}"
    echo ""
    echo -e "${GREEN}VMess WebSocket:${NC}"
    echo "${VMESS_WS_LINK}"
    echo ""
    echo -e "${GREEN}VLESS TLS:${NC}"
    echo "${VLESS_LINK}"
    echo ""
    echo -e "${GREEN}Trojan TLS:${NC}"
    echo "${TROJAN_LINK}"
    echo ""
    echo -e "${GREEN}Shadowsocks:${NC}"
    echo "${SS_LINK}"
    echo ""

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}管理命令:${NC}"
    echo -e "  查看所有链接: ${CYAN}cat /etc/v2ray/config.txt${NC}"
    echo -e "  查看订阅链接: ${CYAN}cat /etc/v2ray/subscription.txt${NC}"
    echo -e "  重启服务:     ${CYAN}systemctl restart v2ray${NC}"
    echo -e "  查看状态:     ${CYAN}systemctl status v2ray${NC}"
    echo -e "  查看日志:     ${CYAN}journalctl -u v2ray -f${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# 交互式配置
interactive_config() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}V2Ray 多协议一键部署脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo -e "${YELLOW}开始交互式配置...${NC}"
    echo ""

    # UUID
    read -p "请输入 VMess/VLESS UUID（直接回车自动生成）: " input_uuid
    if [[ -z "${input_uuid}" ]]; then
        VMESS_UUID="auto"
        VLESS_UUID="auto"
    else
        VMESS_UUID="${input_uuid}"
        VLESS_UUID="${input_uuid}"
    fi

    # 端口
    read -p "VMess TCP 端口（直接回车使用默认 ${DEFAULT_VMESS_PORT}）: " input_port
    VMESS_PORT=${input_port:-${DEFAULT_VMESS_PORT}}

    read -p "VMess WebSocket 端口（直接回车使用默认 ${DEFAULT_VMESS_WS_PORT}）: " input_ws_port
    VMESS_WS_PORT=${input_ws_port:-${DEFAULT_VMESS_WS_PORT}}

    read -p "Shadowsocks 端口（直接回车使用默认 ${DEFAULT_SS_PORT}）: " input_ss_port
    SS_PORT=${input_ss_port:-${DEFAULT_SS_PORT}}

    # 服务器 IP
    auto_ip=$(get_server_ip)
    read -p "服务器 IP（直接回车自动获取: ${auto_ip}）: " input_ip
    SERVER_IP=${input_ip:-${auto_ip}}

    echo ""
    echo -e "${GREEN}配置完成，开始安装...${NC}"
}

# 一键安装函数
install_all() {
    check_root
    detect_os
    install_dependencies
    download_v2ray
    install_v2ray
    generate_config
    generate_self_signed_cert
    configure_firewall
    configure_systemd
    generate_client_info
}

# 主函数
main() {
    # 解析命令行参数
    parse_args "$@"

    # 检查是否有非交互参数
    if [[ -n "${VMESS_UUID}" ]] || [[ -n "${VMESS_PORT}" ]] || [[ -n "${VMESS_WS_PORT}" ]] || [[ -n "${SS_PORT}" ]] || [[ -n "${SERVER_IP}" ]]; then
        # 无交互模式
        echo -e "${GREEN}检测到无交互参数，开始快速安装...${NC}"
        install_all
    else
        # 交互模式
        interactive_config
        select_download_method
        install_all
    fi
}

# 运行
main "$@"
