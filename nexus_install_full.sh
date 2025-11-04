#!/bin/bash
# ============================================
# Nexus CLI Node Installer & Auto-Updater
# Автор: NodeUA | https://t.me/nodesua
# Оновлено: 2025-11-04
# ============================================

LOG_FILE="/root/nexus_update.log"
UPDATE_SCRIPT="/root/nexus_autoupdate.sh"
SCREEN_SESSION="nexus"
THREADS=1

echo "🚀 Починаємо встановлення Nexus CLI-ноди..."

# === Оновлення системи та встановлення залежностей ===
echo "[1/5] Оновлення системи..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential pkg-config libssl-dev git-all screen curl

# === Встановлення Nexus CLI ===
echo "[2/5] Встановлення Nexus CLI..."
curl https://cli.nexus.xyz/ | sh
source ~/.bashrc

# === Запит Node ID ===
read -p "🔹 Введіть ваш Node ID (з сайту https://app.nexus.xyz/nodes): " NODE_ID
if [ -z "$NODE_ID" ]; then
  echo "❌ Не введено Node ID. Вихід."
  exit 1
fi

# === Кількість потоків ===
read -p "🔹 Вкажіть кількість потоків для запуску (рекомендовано 1–4): " THREADS
if [ -z "$THREADS" ]; then
  THREADS=1
fi

# === Запуск у screen ===
echo "[3/5] Запуск ноди у screen сесії \"$SCREEN_SESSION\"..."

# Закриваємо стару сесію, якщо існує
if screen -list | grep -q "\.$SCREEN_SESSION"; then
  screen -S $SCREEN_SESSION -X quit
  sleep 2
fi

# Створюємо нову сесію
screen -dmS $SCREEN_SESSION
screen -S $SCREEN_SESSION -X stuff "nexus-network start --max-threads $THREADS --node-id $NODE_ID$(printf '\r')"

echo "✅ Нода запущена у фоні."
echo "ℹ️ Підключення: screen -r $SCREEN_SESSION"
echo "ℹ️ Вихід (не зупиняючи ноду): Ctrl+A, потім D"

# === Створення автооновлення CLI ===
echo "[4/5] Налаштування автооновлення Nexus CLI..."

cat > $UPDATE_SCRIPT << EOF
#!/bin/bash
echo "[$(date)] Перевірка оновлень Nexus CLI..." >> $LOG_FILE

OLD_VERSION=\$(nexus-network version | grep "Version" | awk '{print \$2}')
curl https://cli.nexus.xyz/ | sh > /tmp/nexus_update.log 2>&1
source ~/.bashrc
NEW_VERSION=\$(nexus-network version | grep "Version" | awk '{print \$2}')

if [ "\$OLD_VERSION" != "\$NEW_VERSION" ]; then
  echo "[$(date)] Оновлення з \$OLD_VERSION до \$NEW_VERSION, перезапуск ноди..." >> $LOG_FILE
  screen -S $SCREEN_SESSION -X quit
  screen -dmS $SCREEN_SESSION
  screen -S $SCREEN_SESSION -X stuff "nexus-network start --max-threads $THREADS --node-id $NODE_ID$(printf '\r')"
  echo "[$(date)] Ноду перезапущено з новою версією." >> $LOG_FILE
else
  echo "[$(date)] Нових оновлень немає." >> $LOG_FILE
fi
EOF

chmod +x $UPDATE_SCRIPT

# Додаємо автооновлення у crontab (щодня о 4:00)
(crontab -l 2>/dev/null; echo "0 4 * * * $UPDATE_SCRIPT") | crontab -

echo ""
echo "🎉 Встановлення завершено!"
echo "🌐 Перевір статистику: https://app.nexus.xyz/nodes"
echo "🪪 Node ID: $NODE_ID"
echo "📊 Логи автооновлення: $LOG_FILE"
echo "🕓 Автооновлення налаштовано на 04:00 щодня."
