#!/bin/bash

# === Запит NodeID якщо не передано як аргумент ===
NODE_ID="$1"
if [ -z "$NODE_ID" ]; then
  read -p "🔹 Введіть ваш NodeID для Nexus CLI: " NODE_ID
  if [ -z "$NODE_ID" ]; then
    echo "❌ NodeID не введено. Вихід."
    exit 1
  fi
fi

# === Налаштування ===
CONTAINER_NAME="nexus"
IMAGE_NAME="nexusxyz/nexus-cli:latest"
LOG_FILE="/root/nexus_update.log"
UPDATE_SCRIPT="/root/nexus_autoupdate.sh"

echo "[INFO] Починаємо встановлення Nexus CLI-ноди..."

# --- Встановлення Docker, якщо немає ---
if ! command -v docker &> /dev/null
then
    echo "[INFO] Встановлення Docker..."
    wget --no-cache -q -O docker_main.sh https://raw.githubusercontent.com/noxuspace/cryptofortochka/main/docker/docker_main.sh
    chmod +x docker_main.sh
    ./docker_main.sh
else
    echo "[INFO] Docker вже встановлений, пропускаємо."
fi

# --- Встановлення screen (опційно) ---
echo "[INFO] Оновлення apt та встановлення screen..."
sudo apt update
sudo apt install -y screen

# --- Завантаження образу Nexus CLI ---
echo "[INFO] Завантаження образу Nexus CLI..."
docker pull $IMAGE_NAME

# --- Створення скрипту автооновлення ---
echo "[INFO] Створення скрипту автооновлення..."

cat > $UPDATE_SCRIPT << EOF
#!/bin/bash

echo "[$(date)] Початок перевірки та оновлення Nexus CLI" >> $LOG_FILE

docker pull $IMAGE_NAME | tee /tmp/nexus_pull.log

if grep -q "Downloaded newer image" /tmp/nexus_pull.log; then
    echo "[$(date)] Знайдено новий образ, перезапускаємо контейнер" >> $LOG_FILE
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
    docker run -d --init --restart unless-stopped --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID
    echo "[$(date)] Контейнер перезапущено з оновленим образом" >> $LOG_FILE
else
    echo "[$(date)] Нових оновлень немає" >> $LOG_FILE
    if [ "\$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
        echo "[$(date)] Контейнер не працює, запускаємо заново" >> $LOG_FILE
        docker rm $CONTAINER_NAME || true
        docker run -d --init --restart unless-stopped --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID
        echo "[$(date)] Контейнер запущено заново" >> $LOG_FILE
    else
        echo "[$(date)] Контейнер працює стабільно" >> $LOG_FILE
    fi
fi

echo "[$(date)] Оновлення завершено" >> $LOG_FILE
EOF

chmod +x $UPDATE_SCRIPT

# --- Додаємо автооновлення у crontab (щодня о 4:00) ---
echo "[INFO] Додаємо автооновлення у crontab..."
(crontab -l 2>/dev/null; echo "0 4 * * * $UPDATE_SCRIPT") | crontab -

# --- Запуск контейнера ---
echo "[INFO] Запуск ноди Nexus CLI..."
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true
docker run -d --init --restart unless-stopped --name $CONTAINER_NAME $IMAGE_NAME start --node-id $NODE_ID

echo "✅ Установка завершена."
echo "ℹ️ Для перегляду логів ноди використовуйте:"
echo "docker logs -f $CONTAINER_NAME"
echo "ℹ️ Логи автооновлення: $LOG_FILE"
