#!/bin/bash

declare -a NODE_IDS=()

# Функція для введення нод
read_node_ids() {
    echo "Введіть ID нод по одному в рядок. Для завершення введення натисніть Enter на порожньому рядку."
    while true; do
        read -rp "ID ноди: " id
        [[ -z "$id" ]] && break
        if [[ "$id" =~ ^[0-9]+$ ]]; then
            NODE_IDS+=("$id")
        else
            echo "Помилка: ID має бути числом."
        fi
    done
    if [ ${#NODE_IDS[@]} -eq 0 ]; then
        echo "Нема введених нод. Завершення."
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
    echo "Для якої ноди показати логи?"
    read -rp "Введіть ID ноди: " id
    if [[ " ${NODE_IDS[*]} " == *" $id "* ]]; then
        echo "Виводимо логи nexus_node@${id}.service (Ctrl+C для виходу)..."
        sudo journalctl -u nexus_node@"$id".service -f
    else
        echo "Помилка: Ноди з таким ID немає в списку."
    fi
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

# Запускаємо
read_node_ids
main_menu
