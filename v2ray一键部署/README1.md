# V2Ray 多协议一键部署脚本

## 🚀 一键部署命令

### 方法 1：直接下载运行（推荐）

```bash
bash <(curl -L https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh)
```

### 方法 2：wget 下载运行

```bash
wget -qO- https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh | bash -
```

### 方法 3：手动下载后运行

```bash
# 1. 下载脚本
wget -O install.sh https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh

# 2. 添加执行权限
chmod +x install.sh

# 3. 运行脚本
sudo ./install.sh
```

---

## ⚡ 无交互极速安装

### 一行命令示例

```bash
# 最简方式（自动生成所有参数）
bash <(curl -L https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh) \
  --uuid auto \
  --port 1080 \
  --ws-port 10086 \
  --ss-port 8388 \
  --server-ip auto
```

### 带自定义参数的示例

```bash
# 自定义端口和 UUID
bash <(curl -L https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh) \
  --uuid 20f7fca4-86e5-4ddf-9eed-24142073d197 \
  --port 12345 \
  --ws-port 12346 \
  --ss-port 12347 \
  --server-ip 1.2.3.4
```

### 无交互安装参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--uuid` | VMess/VLESS UUID（auto = 自动生成） | auto |
| `--port` | VMess TCP 端口 | 1080 |
| `--ws-port` | VMess WebSocket 端口 | 10086 |
| `--ss-port` | Shadowsocks 端口 | 8388 |
| `--server-ip` | 服务器 IP（auto = 自动获取） | auto |
| `--language` | 语言: cn/en | cn |

---

## 📋 脚本功能

- ✅ 自动检测系统（Debian/Ubuntu/CentOS/Alpine）
- ✅ 自动安装依赖（curl wget unzip jq）
- ✅ 支持 GitHub 官方 / ghproxy 镜像下载
- ✅ 自动生成 UUID 和随机密码
- ✅ 支持无交互安装（命令行参数）
- ✅ 支持交互式安装（一步步配置）
- ✅ 自动配置多协议（VMess/VLESS/Trojan/Shadowsocks）
- ✅ 自动配置防火墙
- ✅ 自动生成 TLS 证书
- ✅ 自动配置 systemd 服务
- ✅ 自动生成订阅链接和分享链接

---

## 📡 支持的协议

| 协议 | 端口 | 加密 | 传输方式 |
|------|------|------|----------|
| VMess | 1080 | UUID | TCP |
| VMess | 10086 | UUID | WebSocket |
| VLESS | 443 | UUID | TCP + TLS |
| Trojan | 443 | 密码 | TCP + TLS |
| Shadowsocks | 8388 | aes-256-gcm | TCP/UDP |

---

## 🎯 交互式安装流程

### 1. 运行脚本

```bash
sudo bash <(curl -L https://raw.githubusercontent.com/你的用户名/v2ray-install/main/install.sh)
```

### 2. 选择下载方式

```
========================================
V2Ray 多协议一键部署脚本
========================================

1. 从 GitHub 官方下载
2. 从 ghproxy 镜像下载（推荐国内）
3. 退出

请选择下载方式 [1-3]:
```

### 3. 配置参数

```
请输入 VMess/VLESS UUID（直接回车自动生成）:
VMess TCP 端口（直接回车使用默认 1080）:
VMess WebSocket 端口（直接回车使用默认 10086）:
Shadowsocks 端口（直接回车使用默认 8388）:
服务器 IP（直接回车自动获取）:
```

### 4. 等待自动安装完成

脚本会自动完成所有配置，最后显示配置信息和分享链接。

---

## 📱 客户端配置

### Windows - v2rayN

1. 下载 v2rayN：https://github.com/2dust/v2rayN/releases

2. **订阅方式**（推荐）：
   - 复制显示的订阅链接（base64 长字符串）
   - v2rayN 中点击"服务器" → "订阅设置" → 添加订阅
   - 粘贴订阅链接 → 确定
   - 点击"更新订阅"

3. **分享链接方式**：
   - 复制单独的分享链接（vmess:// vless:// 等）
   - v2rayN 中点击"服务器" → "从剪贴板导入"

### Android - v2rayNG

1. 下载 v2rayNG：https://github.com/2dust/v2rayNG/releases

2. 点击右上角 `+` → 选择"导入订阅"或"扫描二维码"

### macOS - V2rayU

1. 下载 V2rayU：https://github.com/yanue/V2rayU/releases

2. 点击菜单栏图标 → 服务器 → 导入订阅

### iOS - Shadowrocket

1. 在 App Store 下载 Shadowrocket

2. 点击右上角 `+` → 选择类型
3. 粘贴分享链接或手动输入配置

---

## 🔗 分享链接格式

### VMess
```
vmess://base64({"add":"IP","aid":"0","host":"","id":"UUID","net":"tcp","path":"","port":"端口","ps":"备注","tls":"","type":"none","v":"2"})
```

### VLESS
```
vless://UUID@IP:端口?encryption=none&security=tls&type=tcp&host=域名#备注
```

### Trojan
```
trojan://密码@IP:端口#备注
```

### Shadowsocks
```
ss://base64(方法:密码@IP:端口)#备注
```

---

## 🔧 管理命令

```bash
# 启动服务
sudo systemctl start v2ray

# 停止服务
sudo systemctl stop v2ray

# 重启服务
sudo systemctl restart v2ray

# 查看状态
sudo systemctl status v2ray

# 查看日志
sudo journalctl -u v2ray -f

# 查看配置链接
cat /etc/v2ray/config.txt

# 查看订阅链接
cat /etc/v2ray/subscription.txt
```

---

## 📂 文件位置

| 文件 | 路径 |
|------|------|
| V2Ray 程序 | `/usr/local/v2ray/v2ray` |
| V2Ray 控制工具 | `/usr/local/v2ray/v2ctl` |
| 配置文件 | `/etc/v2ray/config.json` |
| TLS 证书 | `/etc/v2ray/cert.crt` |
| TLS 私钥 | `/etc/v2ray/key.key` |
| 分享链接 | `/etc/v2ray/config.txt` |
| 订阅链接 | `/etc/v2ray/subscription.txt` |

---

## ⚠️ 重要提示

### 1. TLS 证书
- 脚本自动生成的是**自签名证书**，仅适合测试使用
- 正式环境请使用 Let's Encrypt 免费证书

### 2. 防火墙
确保开放以下端口：
- `80` (HTTP)
- `443` (HTTPS/TLS)
- `1080` (VMess TCP)
- `10086` (VMess WebSocket)
- `8388` (Shadowsocks)

### 3. 安全建议
- 部署后**立即**将配置信息备份到本地
- 生产环境建议关闭不需要的协议
- 定期更新 V2Ray 到最新版本

---

## ❓ 常见问题

### Q: 安装失败怎么办？
A: 检查：
- 是否使用 root 权限运行
- 网络是否正常
- 尝试切换下载方式

### Q: 如何更新 V2Ray？
A: 重新运行安装脚本即可更新

### Q: 如何修改配置？
A:
```bash
sudo nano /etc/v2ray/config.json
sudo systemctl restart v2ray
```

---

## 📚 相关链接

- V2Ray 官方文档：https://www.v2fly.org/
- V2Ray GitHub：https://github.com/v2fly/v2ray-core
- v2rayN 下载：https://github.com/2dust/v2rayN/releases
- ghproxy 镜像：https://ghproxy.com/
