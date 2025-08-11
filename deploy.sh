#!/bin/bash

# Komari Telegram Bot 自动部署脚本 (修正版)
# 此脚本将自动安装所有必要的依赖并设置项目

set -e
echo "========== Komari Telegram Bot 自动部署脚本 (修正版) =========="

# 检查是否为root用户运行
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用root权限运行此脚本 (sudo ./deploy.sh)"
  exit 1
fi

# 检测系统类型
if [ -f /etc/debian_version ]; then
  echo "[1/7] 检测到 Debian/Ubuntu 系统，安装依赖..."
  apt update
  apt install -y curl build-essential pkg-config libssl-dev libsqlite3-dev git
else
  if [ -f /etc/redhat-release ]; then
    echo "[1/7] 检测到 CentOS/RHEL 系统，安装依赖..."
    yum install -y curl gcc gcc-c++ make openssl-devel sqlite-devel pkgconfig git
  else
    echo "不支持的系统类型，请手动安装依赖"
    exit 1
  fi
fi

# 安装Rust
echo "[2/7] 安装 Rust 环境..."
if ! command -v rustc &> /dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  echo "Rust 安装完成"
else
  echo "Rust 已安装，跳过"
fi

# 克隆项目（修正GitHub仓库地址）
echo "[3/7] 检查项目文件..."
if [ ! -f "Cargo.toml" ]; then
  # 检查是否存在项目目录
  if [ -d "komari-tg-bot" ]; then
    echo "检测到已存在 komari-tg-bot 目录"
    echo "是否要删除现有目录并重新从 GitHub 拉取最新代码？"
    echo "y) 是，删除现有目录并重新下载"
    echo "n) 否，使用现有目录"
    read -r overwrite_choice
    
    case $overwrite_choice in
      y|Y|yes|YES)
        echo "正在删除现有目录..."
        rm -rf komari-tg-bot
        echo "正在从 GitHub 克隆最新项目..."
        git clone https://github.com/GenshinMinecraft/komari-tg-bot.git
        cd komari-tg-bot
        ;;
      n|N|no|NO)
        echo "使用现有项目目录"
        cd komari-tg-bot
        ;;
      *)
        echo "无效选择，默认使用现有目录"
        cd komari-tg-bot
        ;;
    esac
  else
    echo "未找到项目文件，正在克隆..."
    git clone https://github.com/GenshinMinecraft/komari-tg-bot.git
    cd komari-tg-bot
  fi
else
  echo "当前目录已包含项目文件，继续部署..."
fi

# 设置Telegram Token
echo "[4/7] 设置 Telegram Bot Token..."
echo "请输入您的 Telegram Bot Token（从BotFather获取）："
read -r token
echo -n "$token" > src/telegram.token
echo "Token 已保存"

# 创建配置文件 (新增 - 修复关键问题)
echo "[5/7] 创建配置文件..."
echo "请输入 Bot 用户名（不带@，如: your_bot_name）："
read -r bot_name

echo "请输入 Webhook 回调端口（默认: 3000）："
read -r callback_port
callback_port=${callback_port:-3000}

echo "请输入 Webhook 回调 URL（如: http://your-domain.com 或 http://IP地址）："
read -r callback_url

echo "请选择日志级别："
echo "1) debug"
echo "2) info (推荐)"
echo "3) warn"
echo "4) error"
read -r log_choice

case $log_choice in
  1) log_level="debug" ;;
  3) log_level="warn" ;;
  4) log_level="error" ;;
  *) log_level="info" ;;
esac

# 生成 config.json 文件
cat > config.json << EOF
{
  "db_file": "bot.db",
  "telegram_token": "$token",
  "bot_name": "$bot_name",
  "callback_http_port": $callback_port,
  "callback_http_url": "$callback_url",
  "log_level": "$log_level"
}
EOF

echo "配置文件 config.json 已创建"

# 编译项目
echo "[6/7] 编译项目..."
export RUSTFLAGS="-C target-cpu=native"
cargo build --release

# 创建服务文件（可选）
echo "[7/7] 创建系统服务..."
echo "是否创建系统服务以便开机自启？(y/n)"
read -r create_service

if [ "$create_service" = "y" ] || [ "$create_service" = "Y" ]; then
  # 获取当前目录的绝对路径
  CURRENT_DIR=$(pwd)
  
  # 获取真实用户名（处理sudo情况）
  REAL_USER=${SUDO_USER:-$(logname 2>/dev/null || whoami)}
  
  # 确保数据库文件有正确的权限
  touch "$CURRENT_DIR/bot.db"
  chown "$REAL_USER:$REAL_USER" "$CURRENT_DIR/bot.db"
  chmod 644 "$CURRENT_DIR/bot.db"
  
  # 确保整个项目目录权限正确
  chown -R "$REAL_USER:$REAL_USER" "$CURRENT_DIR"
  
  # 创建服务文件
  cat > /etc/systemd/system/komari-tgbot.service << EOF
[Unit]
Description=Komari Telegram Bot
After=network.target

[Service]
Type=simple
User=$REAL_USER
Group=$REAL_USER
WorkingDirectory=$CURRENT_DIR
ExecStart=$CURRENT_DIR/target/release/komari-tgbot
Restart=on-failure
RestartSec=5
Environment=RUST_BACKTRACE=1
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
EOF

  # 启用并启动服务
  systemctl daemon-reload
  systemctl enable komari-tgbot.service
  systemctl start komari-tgbot.service
  
  echo "系统服务已创建并启动"
  echo "可以使用以下命令管理服务："
  echo "  启动: sudo systemctl start komari-tgbot"
  echo "  停止: sudo systemctl stop komari-tgbot"
  echo "  重启: sudo systemctl restart komari-tgbot"
  echo "  状态: sudo systemctl status komari-tgbot"
  echo "  查看日志: sudo journalctl -u komari-tgbot -f"
else
  echo "跳过创建系统服务"
fi

# 打印运行命令
echo "\n========== 部署完成 ==========" 

if [ "$create_service" = "y" ] || [ "$create_service" = "Y" ]; then
  echo "服务已自动启动，无需手动运行"
  echo "查看日志: sudo journalctl -u komari-tgbot -f"
else
  echo "请选择运行方式："
  echo "1. 后台运行"
  echo "2. 手动运行"
  read -r run_choice
  
  case $run_choice in
    1)
      echo "正在后台启动 Komari Telegram Bot..."
      nohup ./target/release/komari-tgbot > komari-bot.log 2>&1 &
      echo $! > komari-bot.pid
      echo "Bot已在后台启动，进程ID: $!"
      echo "查看日志: tail -f komari-bot.log"
      ;;
    2)
      echo "您可以使用以下命令手动运行 Komari Telegram Bot："
      echo "  ./target/release/komari-tgbot"
      echo "或者使用 Cargo 运行："
      echo "  cargo run --release"
      ;;
    *)
      echo "无效选择，默认提供手动运行命令"
      echo "您可以使用以下命令手动运行 Komari Telegram Bot："
      echo "  ./target/release/komari-tgbot"
      echo "或者使用 Cargo 运行："
      echo "  cargo run --release"
      ;;
  esac
fi

# 注册全局命令 mbot
echo "[额外] 注册全局命令 'mbot'..."
CURRENT_DIR=$(pwd)
MBOT_SCRIPT="/usr/local/bin/mbot"

cat > "$MBOT_SCRIPT" << 'EOF'
#!/bin/bash

# Komari Telegram Bot 全局管理命令 (修正版)
# 支持更新、管理和切换到项目目录

PROJECT_DIR=""
REPO_URL="https://github.com/GenshinMinecraft/komari-tg-bot"

# 查找项目目录
find_project_dir() {
    # 优先查找当前目录
    if [ -f "Cargo.toml" ] && grep -q "komari-tgbot" "Cargo.toml" 2>/dev/null; then
        PROJECT_DIR=$(pwd)
        return 0
    fi
    
    # 查找常见位置
    for dir in "/opt/komari-tg-bot" "/home/*/komari-tg-bot" "/root/komari-tg-bot"; do
        if [ -d "$dir" ] && [ -f "$dir/Cargo.toml" ]; then
            PROJECT_DIR="$dir"
            return 0
        fi
    done
    
    # 查找所有可能的位置
    PROJECT_DIR=$(find /home /opt /root -name "Cargo.toml" -path "*/komari-tg-bot/*" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
    
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
        return 0
    fi
    
    return 1
}

show_help() {
    echo "Komari Telegram Bot 管理工具 (修正版)"
    echo "用法: mbot [选项]"
    echo ""
    echo "选项:"
    echo "  help, -h        显示此帮助信息"
    echo "  update          更新项目到最新版本"
    echo "  manage          进入管理菜单"
    echo "  status          查看运行状态"
    echo "  logs            查看日志"
    echo "  cd              切换到项目目录"
    echo "  path            显示项目路径"
    echo ""
}

update_project() {
    if ! find_project_dir; then
        echo "错误: 未找到 Komari Telegram Bot 项目目录"
        echo "请确保项目已正确安装"
        return 1
    fi
    
    echo "项目目录: $PROJECT_DIR"
    cd "$PROJECT_DIR" || return 1
    
    echo "正在更新项目..."
    
    # 停止服务（如果正在运行）
    if systemctl is-active --quiet komari-tgbot 2>/dev/null; then
        echo "停止服务..."
        systemctl stop komari-tgbot
        SERVICE_WAS_RUNNING=true
    else
        SERVICE_WAS_RUNNING=false
        # 停止后台进程
        if [ -f "komari-bot.pid" ]; then
            PID=$(cat komari-bot.pid)
            if kill -0 "$PID" 2>/dev/null; then
                echo "停止后台进程..."
                kill "$PID"
                rm -f komari-bot.pid
                BG_WAS_RUNNING=true
            fi
        fi
    fi
    
    # 备份配置文件
    if [ -f "config.json" ]; then
        cp "config.json" "/tmp/config.json.backup"
        echo "已备份配置文件"
    fi
    
    # 更新代码
    echo "拉取最新代码..."
    git fetch origin
    git reset --hard origin/main
    
    # 恢复配置文件
    if [ -f "/tmp/config.json.backup" ]; then
        cp "/tmp/config.json.backup" "config.json"
        rm -f "/tmp/config.json.backup"
        echo "已恢复配置文件"
    fi
    
    # 重新编译
    echo "重新编译项目..."
    export RUSTFLAGS="-C target-cpu=native"
    cargo build --release
    
    # 恢复服务运行状态
    if [ "$SERVICE_WAS_RUNNING" = true ]; then
        echo "重新启动服务..."
        systemctl start komari-tgbot
    elif [ "$BG_WAS_RUNNING" = true ]; then
        echo "重新启动后台进程..."
        nohup ./target/release/komari-tgbot > komari-bot.log 2>&1 &
        echo $! > komari-bot.pid
    fi
    
    echo "更新完成！"
}

manage_bot() {
    if ! find_project_dir; then
        echo "错误: 未找到 Komari Telegram Bot 项目目录"
        return 1
    fi
    
    cd "$PROJECT_DIR" || return 1
    
    # 管理菜单
    if [ -f "/etc/systemd/system/komari-tgbot.service" ]; then
        # systemd 服务管理
        while true; do
            echo
            echo "===== Komari Telegram Bot 服务管理 ====="
            echo "1) 启动服务"
            echo "2) 停止服务"
            echo "3) 重启服务"
            echo "4) 查看状态"
            echo "5) 查看日志 (按 Ctrl+C 退出)"
            echo "6) 退出菜单"
            read -r -p "请选择 [1-6]: " svc_choice
            case "$svc_choice" in
                1)
                    systemctl start komari-tgbot && echo "已启动"
                    ;;
                2)
                    systemctl stop komari-tgbot && echo "已停止"
                    ;;
                3)
                    systemctl restart komari-tgbot && echo "已重启"
                    ;;
                4)
                    systemctl status komari-tgbot --no-pager || true
                    ;;
                5)
                    echo "正在查看日志，按 Ctrl+C 退出..."
                    journalctl -u komari-tgbot -f
                    ;;
                6)
                    echo "已退出菜单"
                    sleep 0.2
                    clear
                    break
                    ;;
                *)
                    echo "无效选择，请重试"
                    ;;
            esac
        done
    else
        # 后台进程管理
        BIN="$PROJECT_DIR/target/release/komari-tgbot"
        LOG="$PROJECT_DIR/komari-bot.log"
        PIDFILE="$PROJECT_DIR/komari-bot.pid"
        
        while true; do
            echo
            echo "===== Komari Telegram Bot 后台管理 ====="
            echo "1) 启动后台"
            echo "2) 停止后台"
            echo "3) 重启后台"
            echo "4) 查看状态"
            echo "5) 查看日志 (按 Ctrl+C 退出)"
            echo "6) 退出菜单"
            read -r -p "请选择 [1-6]: " bg_choice
            case "$bg_choice" in
                1)
                    if [ -x "$BIN" ]; then
                        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
                            echo "后台已在运行，PID: $(cat "$PIDFILE")"
                        else
                            echo "正在后台启动..."
                            nohup "$BIN" > "$LOG" 2>&1 &
                            echo $! > "$PIDFILE"
                            echo "已启动，PID: $(cat "$PIDFILE")"
                            echo "查看日志: tail -f $LOG"
                        fi
                    else
                        echo "未找到可执行文件: $BIN，请先编译 (cargo build --release)"
                    fi
                    ;;
                2)
                    if [ -f "$PIDFILE" ]; then
                        PID=$(cat "$PIDFILE")
                        if kill -0 "$PID" 2>/dev/null; then
                            kill "$PID" && echo "已停止 (PID: $PID)" || echo "停止失败"
                        else
                            echo "记录的 PID ($PID) 未在运行"
                        fi
                        rm -f "$PIDFILE"
                    else
                        PIDS=$(pgrep -f "$BIN" || true)
                        if [ -n "$PIDS" ]; then
                            echo "发现进程: $PIDS，正在停止..."
                            for p in $PIDS; do kill "$p" || true; done
                            echo "已尝试停止所有匹配进程"
                        else
                            echo "未发现后台进程"
                        fi
                    fi
                    ;;
                3)
                    # 重启 = 停止 + 启动
                    if [ -f "$PIDFILE" ]; then
                        PID=$(cat "$PIDFILE")
                        kill "$PID" 2>/dev/null || true
                        rm -f "$PIDFILE"
                    else
                        for p in $(pgrep -f "$BIN" || true); do kill "$p" 2>/dev/null || true; done
                    fi
                    if [ -x "$BIN" ]; then
                        echo "正在后台启动..."
                        nohup "$BIN" > "$LOG" 2>&1 &
                        echo $! > "$PIDFILE"
                        echo "已重启，PID: $(cat "$PIDFILE")"
                        echo "查看日志: tail -f $LOG"
                    else
                        echo "未找到可执行文件: $BIN，请先编译 (cargo build --release)"
                    fi
                    ;;
                4)
                    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
                        echo "后台运行中，PID: $(cat "$PIDFILE")"
                    else
                        PIDS=$(pgrep -f "$BIN" || true)
                        if [ -n "$PIDS" ]; then
                            echo "后台可能运行中，进程: $PIDS (未使用PID文件)"
                        else
                            echo "后台未运行"
                        fi
                    fi
                    ;;
                5)
                    if [ -f "$LOG" ]; then
                        echo "正在查看日志，按 Ctrl+C 退出..."
                        tail -f "$LOG"
                    else
                        echo "暂无日志文件: $LOG"
                    fi
                    ;;
                6)
                    echo "已退出菜单"
                    break
                    ;;
                *)
                    echo "无效选择，请重试"
                    ;;
            esac
        done
    fi
}

show_status() {
    if ! find_project_dir; then
        echo "错误: 未找到 Komari Telegram Bot 项目目录"
        return 1
    fi
    
    cd "$PROJECT_DIR" || return 1
    
    if systemctl is-active --quiet komari-tgbot 2>/dev/null; then
        echo "状态: systemd 服务运行中"
        systemctl status komari-tgbot --no-pager
    elif [ -f "komari-bot.pid" ] && kill -0 "$(cat komari-bot.pid 2>/dev/null)" 2>/dev/null; then
        echo "状态: 后台进程运行中，PID: $(cat komari-bot.pid)"
    else
        echo "状态: 未运行"
    fi
}

show_logs() {
    if ! find_project_dir; then
        echo "错误: 未找到 Komari Telegram Bot 项目目录"
        return 1
    fi
    
    cd "$PROJECT_DIR" || return 1
    
    if systemctl is-active --quiet komari-tgbot 2>/dev/null; then
        echo "显示 systemd 服务日志 (按 Ctrl+C 退出):"
        journalctl -u komari-tgbot -f
    elif [ -f "komari-bot.log" ]; then
        echo "显示后台进程日志 (按 Ctrl+C 退出):"
        tail -f komari-bot.log
    else
        echo "未找到日志文件"
    fi
}

case "$1" in
    ""|manage)
        manage_bot
        ;;
    update)
        update_project
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    cd)
        if find_project_dir; then
            echo "cd $PROJECT_DIR"
        else
            echo "错误: 未找到项目目录"
        fi
        ;;
    path)
        if find_project_dir; then
            echo "$PROJECT_DIR"
        else
            echo "错误: 未找到项目目录"
        fi
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        echo "未知选项: $1"
        show_help
        exit 1
        ;;
esac
EOF

# 设置执行权限
chmod +x "$MBOT_SCRIPT"

# 更新PATH环境变量（如果需要）
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
    echo 'export PATH="/usr/local/bin:$PATH"' >> /etc/profile
fi

echo "'mbot' 命令已全局注册 (修正版)"
echo "您现在可以在任何地方使用以下命令:"
echo "  mbot          - 进入管理菜单"
echo "  mbot update   - 更新到最新版本"
echo "  mbot status   - 查看运行状态"
echo "  mbot logs     - 查看日志"
echo "  mbot cd       - 显示切换到项目目录的命令"
echo "  mbot help     - 显示帮助信息"

# 最后提醒用户关于配置的重要性
echo "\n重要提示："
echo "1. 请确保您已正确设置了 Telegram Bot Token 和配置文件"
echo "2. 如需更改配置，请编辑 config.json 文件，然后重新启动服务"
echo "3. Token可以从Telegram的@BotFather获取"
echo "4. 使用 'mbot update' 可以自动更新项目到最新版本"
echo "5. Webhook 功能已启用，端口为: $callback_port"

echo "\n感谢使用 Komari Telegram Bot (修正版)！"

# ========== 管理菜单（systemd 和 非 systemd 两种模式） ==========
# 如果存在 systemd 单元，则使用 systemctl 管理；否则提供后台进程管理。
service_menu() {
  while true; do
    echo
    echo "===== Komari Telegram Bot 服务管理 ====="
    echo "1) 启动服务"
    echo "2) 停止服务"
    echo "3) 重启服务"
    echo "4) 查看状态"
    echo "5) 查看日志 (按 Ctrl+C 退出)"
    echo "6) 退出菜单"
    read -r -p "请选择 [1-6]: " svc_choice
    case "$svc_choice" in
      1)
        systemctl start komari-tgbot && echo "已启动"
        ;;
      2)
        systemctl stop komari-tgbot && echo "已停止"
        ;;
      3)
        systemctl restart komari-tgbot && echo "已重启"
        ;;
      4)
        systemctl status komari-tgbot --no-pager || true
        ;;
      5)
        echo "正在查看日志，按 Ctrl+C 退出..."
        journalctl -u komari-tgbot -f
        ;;
      6)
        echo "已退出菜单"
        break
        ;;
      *)
        echo "无效选择，请重试"
        ;;
    esac
  done
}

bg_menu() {
  BASE_DIR="$(pwd)"
  BIN="$BASE_DIR/target/release/komari-tgbot"
  LOG="$BASE_DIR/komari-bot.log"
  PIDFILE="$BASE_DIR/komari-bot.pid"
  while true; do
    echo
    echo "===== Komari Telegram Bot 后台管理 ====="
    echo "1) 启动后台"
    echo "2) 停止后台"
    echo "3) 重启后台"
    echo "4) 查看状态"
    echo "5) 查看日志 (按 Ctrl+C 退出)"
    echo "6) 退出菜单"
    read -r -p "请选择 [1-6]: " bg_choice
    case "$bg_choice" in
      1)
        if [ -x "$BIN" ]; then
          if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
            echo "后台已在运行，PID: $(cat "$PIDFILE")"
          else
            echo "正在后台启动..."
            nohup "$BIN" > "$LOG" 2>&1 &
            echo $! > "$PIDFILE"
            echo "已启动，PID: $(cat "$PIDFILE")"
            echo "查看日志: tail -f $LOG"
          fi
        else
          echo "未找到可执行文件: $BIN，请先编译 (cargo build --release)"
        fi
        ;;
      2)
        if [ -f "$PIDFILE" ]; then
          PID=$(cat "$PIDFILE")
          if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" && echo "已停止 (PID: $PID)" || echo "停止失败"
          else
            echo "记录的 PID ($PID) 未在运行"
          fi
          rm -f "$PIDFILE"
        else
          PIDS=$(pgrep -f "$BIN" || true)
          if [ -n "$PIDS" ]; then
            echo "发现进程: $PIDS，正在停止..."
            for p in $PIDS; do kill "$p" || true; done
            echo "已尝试停止所有匹配进程"
          else
            echo "未发现后台进程"
          fi
        fi
        ;;
      3)
        # 重启 = 停止 + 启动
        if [ -f "$PIDFILE" ]; then
          PID=$(cat "$PIDFILE")
          kill "$PID" 2>/dev/null || true
          rm -f "$PIDFILE"
        else
          for p in $(pgrep -f "$BIN" || true); do kill "$p" 2>/dev/null || true; done
        fi
        if [ -x "$BIN" ]; then
          echo "正在后台启动..."
          nohup "$BIN" > "$LOG" 2>&1 &
          echo $! > "$PIDFILE"
          echo "已重启，PID: $(cat "$PIDFILE")"
          echo "查看日志: tail -f $LOG"
        else
          echo "未找到可执行文件: $BIN，请先编译 (cargo build --release)"
        fi
        ;;
      4)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
          echo "后台运行中，PID: $(cat "$PIDFILE")"
        else
          PIDS=$(pgrep -f "$BIN" || true)
          if [ -n "$PIDS" ]; then
            echo "后台可能运行中，进程: $PIDS (未使用PID文件)"
          else
            echo "后台未运行"
          fi
        fi
        ;;
      5)
        if [ -f "$LOG" ]; then
          echo "正在查看日志，按 Ctrl+C 退出..."
          tail -f "$LOG"
        else
          echo "暂无日志文件: $LOG"
        fi
        ;;
      6)
        echo "已退出菜单"
        break
        ;;
      *)
        echo "无效选择，请重试"
        ;;
    esac
  done
}

# 根据是否存在 systemd 单元，选择对应的管理菜单
if [ -f "/etc/systemd/system/komari-tgbot.service" ]; then
  echo "\n检测到已安装 systemd 服务，进入服务管理菜单..."
  service_menu
else
  echo "\n未检测到 systemd 服务，进入后台管理菜单..."
  bg_menu
fi