#!/bin/bash
# ============================================
# Nexus CLI Node Installer & Multi-Node Setup
# Автор: NodeUA | https://t.me/nodesua
# Оновлено: 2026-01-08
# ============================================

THREADS=2  # Потоки на ноду
UPDATE_SCRIPT="/root/nexus_autoupdate.sh"
LOG_FILE="/root/nexus_update.log"

echo "🚀 Починаємо установку Nexus CLI та налаштування нод..."

# ===========================
# 1️⃣ Видалення старих нод та файлів
# ===========================
echo "[1/5] Видаляємо старі установки та файли..."
sudo systemctl stop nexus_node@* 2>/dev/null
sudo systemctl disable nexus_node@* 2>/dev/null
sudo rm -rf /root/.nexus
sudo rm -f /etc/systemd/system/nexus_node@*.service

# ===========================
# 2️⃣ Оновлення системи та залежностей
# ===========================
echo "[2/5] Оновлення системи та встановлення залежностей..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential pkg-config libssl-dev git screen curl

# ===========================
# 3️⃣ Встановлення Nexus CLI
# ===========================
echo "[3/5] Встановлення Nexus CLI..."
curl https://cli.nexus.xyz/ | sh
source ~/.bashrc

# ===========================
# 4️⃣ Введення Node ID(ів)
# ===========================
echo "[4/5] Введіть Node ID для кожної ноди. Через пробіл для кількох."
read -p "🔹 Node ID(и): " NODE_IDS

if [ -z "$NODE_IDS" ]; then
    echo "❌ Не введено жодного Node ID. Вихід."
    exit 1
fi

# ===========================
# 5️⃣ Створення systemd-сервісів для кожної ноди
# ===========================
echo "[5/5] Створення systemd-сервісів для нод..."
for NODE_ID in $NODE_IDS; do
    SERVICE_FILE="/etc/systemd/system/nexus_node@${NODE_ID}.service"
    sudo bash -c "cat > $SERVICE_FILE" << EOF
[Unit]
Description=Nexus Node ${NODE_ID}
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/.nexus
ExecStart=/root/.nexus/bin/nexus-network start --max-threads $THREADS --node-id ${NODE_ID} --headless
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable nexus_node@${NODE_ID}
    sudo systemctl start nexus_node@${NODE_ID}
    echo "✅ Нода ${NODE_ID} запущена та додана до автозавантаження."
done

# ===========================
# 6️⃣ Створення скрипта автооновлення CLI
# ===========================
echo "[6/6] Налаштування автооновлення Nexus CLI..."
cat > $UPDATE_SCRIPT << 'EOF'
#!/bin/bash
LOG_FILE="/root/nexus_update.log"
echo "[$(date)] Перевірка оновлень Nexus CLI..." >> $LOG_FILE

OLD_VERSION=$(/root/.nexus/bin/nexus-network version | grep "Version" | awk '{print $2}')
curl https://cli.nexus.xyz/ | sh >> /tmp/nexus_update.log 2>&1
source ~/.bashrc
NEW_VERSION=$(/root/.nexus/bin/nexus-network version | grep "Version" | awk '{print $2}')

if [ "$OLD_VERSION" != "$NEW_VERSION" ]; then
    echo "[$(date)] Оновлення з $OLD_VERSION до $NEW_VERSION, перезапуск усіх нод..." >> $LOG_FILE
    systemctl restart nexus_node@* 
    echo "[$(date)] Усі ноди перезапущені." >> $LOG_FILE
else
    echo "[$(date)] Нових оновлень немає." >> $LOG_FILE
fi
EOF

chmod +x $UPDATE_SCRIPT

# Додаємо автооновлення у crontab (щодня о 04:00)
(crontab -l 2>/dev/null; echo "0 4 * * * $UPDATE_SCRIPT") | crontab -

echo ""
echo "🎉 Встановлення завершено!"
echo "ℹ️ Підключення до ноди: journalctl -u nexus_node@<NodeID> -f"
echo "🌐 Статистика нод: https://app.nexus.xyz/nodes"
echo "📊 Логи автооновлення: $LOG_FILE"
echo "🕓 Автооновлення налаштовано на 04:00 щодня."
