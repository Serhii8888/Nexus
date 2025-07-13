#!/bin/bash

NODE_IDS=()

create_systemd_template() {
    local SERVICE_PATH="/etc/systemd/system/nexus_node@.service"
    local USER_NAME=$(whoami)
    local WORKDIR="$HOME/rpc/nexus-cli/clients/cli"
    local EXEC="$HOME/rpc/nexus-cli/target/release/nexus-network"

    if [ ! -f "$SERVICE_PATH" ]; then
        echo "Створюю systemd шаблон nexus_node@.service..."
        sudo bash -c "cat > $SERVICE_PATH" <<EOF
[Unit]
Description=Nexus Node %i
After=network.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$WORKDIR
ExecStart=$EXEC start --node-id %i
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        echo "Шаблон systemd створено за адресою $SERVICE_PATH."
    else
        echo "Шаблон systemd вже існує, пропускаю створення."
    fi
}

read_node_ids() {
    echo "Введіть список ID нод одразу (через пробіли або кожен з нового рядка)."
    echo "Для завершення введення натисніть Enter на порожньому рядку."

    input=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        input+="$line "
    done

    read -r -a NODE_IDS <<< "$input"

    # Фільтрація валідних числових ID
    local valid_ids=()
    for id in "${NODE_IDS[@]}"; do
        if [[ "$id" =~ ^[0-9]+$ ]]; then
            valid_ids+=("$id")
        else
            echo "Попередження: '$id' не є валідним числом і буде пропущено."
        fi
    done
    NODE_IDS=("${valid_ids[@]}")

    if [ ${#NODE_IDS[@]} -eq 0 ]; then
        echo "Не введено жодного валідного ID. Повертаємось у меню."
        return 1
    fi

    return 0
}

start_nodes() {
    if [ ${#NODE_IDS[@]} -eq 0 ]; then
        echo "Список нод порожній. Спершу введіть ID нод (пункт меню 1)."
        return
    fi
    echo "Запускаємо ноди..."
    for id in "${NODE_IDS[@]}"; do
        echo "Увімкнення автозапуску nexus_node@${id}.service"
        sudo systemctl enable nexus_node@"$id".service
        echo "Запуск nexus_node@${id}.service"
        sudo systemctl start nexus_node@"$id".service
    done
    echo "Усі ноди запущено."
}

restart_nodes() {
    if [ ${#NODE_IDS[@]} -eq 0 ]; then
        echo "Список нод порожній. Спершу введіть ID нод (пункт меню 1)."
        return
    fi
    echo "Перезапускаємо ноди..."
    for id in "${NODE_IDS[@]}"; do
        echo "Перезапуск nexus_node@${id}.service"
        sudo systemctl restart nexus_node@"$id".service
    done
    echo "Усі ноди перезапущено."
}

show_logs() {
    if [ ${#NODE_IDS[@]} -eq 0 ]; then
        echo "Список нод порожній. Спершу введіть ID нод (пункт меню 1)."
        return
    fi
    echo "Оберіть ID ноди для перегляду логів:"
    select id in "${NODE_IDS[@]}"; do
        if [[ " ${NODE_IDS[*]} " == *" $id "* ]]; then
            echo "Виводимо логи nexus_node@${id}.service (Ctrl+C для виходу)..."
            sudo journalctl -u nexus_node@"$id".service -f
            break
        else
            echo "Невірний вибір, спробуйте ще раз."
        fi
    done
}

stop_disable_nodes() {
    if [ ${#NODE_IDS[@]} -eq 0 ]; then
        echo "Список нод порожній. Спершу введіть ID нод (пункт меню 1)."
        return
    fi
    echo "Зупиняємо та вимикаємо автозапуск усіх нод..."
    for id in "${NODE_IDS[@]}"; do
        echo "Зупинка nexus_node@${id}.service"
        sudo systemctl stop nexus_node@"$id".service
        echo "Відключення автозапуску nexus_node@${id}.service"
        sudo systemctl disable nexus_node@"$id".service
    done
    echo "Усі ноди зупинено та вимкнено."
}

main_menu() {
    create_systemd_template
    while true; do
        echo
        echo "Оберіть дію:"
        echo "1) Ввести список ID нод"
        echo "2) Запустити ноди"
        echo "3) Перезапустити ноди"
        echo "4) Подивитись логи ноди"
        echo "5) Видалити (зупинити і відключити автозапуск) усі ноди"
        echo "6) Вийти"
        read -rp "Ваш вибір: " choice

        case $choice in
            1)
                if ! read_node_ids; then
                    echo "Список нод не оновлено."
                else
                    echo "Список нод оновлено."
                fi
                ;;
            2) start_nodes ;;
            3) restart_nodes ;;
            4) show_logs ;;
            5) stop_disable_nodes ;;
            6) echo "Вихід."; exit 0 ;;
            *) echo "Невірний вибір, спробуйте ще раз." ;;
        esac
    done
}

main_menu
