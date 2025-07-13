#!/bin/bash

read_node_ids() {
    echo "Введіть список ID нод одразу (через пробіли або кожен з нового рядка)."
    echo "Для завершення введення натисніть Enter на порожньому рядку."

    # Зчитуємо всі рядки до порожнього рядка у змінну input
    input=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        input+="$line "
    done

    # Перетворюємо рядок у масив, розбиваючи по пробілах
    read -r -a NODE_IDS <<< "$input"

    # Перевірка валідності ID (тільки числа)
    for id in "${NODE_IDS[@]}"; do
        if ! [[ "$id" =~ ^[0-9]+$ ]]; then
            echo "Попередження: '$id' не є валідним числовим ID і буде пропущено."
            # Видаляємо невалідний ID
            NODE_IDS=("${NODE_IDS[@]/$id}")
        fi
    done

    if [ ${#NODE_IDS[@]} -eq 0 ]; then
        echo "Не введено жодного валідного ID. Вихід."
        exit 1
    fi
}

start_nodes() {
    echo "Запускаємо ноди..."
    for id in "${NODE_IDS[@]}"; do
        echo "Запуск nexus_node@${id}.service"
        sudo systemctl start nexus_node@"$id".service
    done
    echo "Усі ноди запущено."
}

restart_nodes() {
    echo "Перезапускаємо ноди..."
    for id in "${NODE_IDS[@]}"; do
        echo "Перезапуск nexus_node@${id}.service"
        sudo systemctl restart nexus_node@"$id".service
    done
    echo "Усі ноди перезапущено."
}

show_logs() {
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
    while true; do
        echo
        echo "Оберіть дію:"
        echo "1) Встановити (запустити) ноди"
        echo "2) Перезапустити ноди"
        echo "3) Подивитись логи ноди"
        echo "4) Видалити (зупинити і відключити автозапуск) усі ноди"
        echo "5) Вийти"
        read -rp "Ваш вибір: " choice

        case $choice in
            1) start_nodes ;;
            2) restart_nodes ;;
            3) show_logs ;;
            4) stop_disable_nodes ;;
            5) echo "Вихід."; exit 0 ;;
            *) echo "Невірний вибір, спробуйте ще раз." ;;
        esac
    done
}

# Починаємо зі зчитування нод
read_node_ids

# Запускаємо меню
main_menu
