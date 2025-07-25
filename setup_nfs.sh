#!/bin/bash

### Определение цветовых кодов ###
ESC=$(printf '\033') RESET="${ESC}[0m" MAGENTA="${ESC}[35m" RED="${ESC}[31m" GREEN="${ESC}[32m"

### Цветные функции ##
magentaprint() { echo; printf "${MAGENTA}%s${RESET}\n" "$1"; }
errorprint() { echo; printf "${RED}%s${RESET}\n" "$1"; }
greenprint() { echo; printf "${GREEN}%s${RESET}\n" "$1"; }

# Общие переменные
NFS_SHARE="/var/nfs_share"
NFS_CLIENT_MOUNT="/mnt/nfs_mount"
NFS_SERVER_IP="10.100.10.3"     # Укажите IP-адрес сервера NFS
SUBNET="10.100.10.0/24"         # Разрешённая подсеть


# ------------------------------------------------------------------------------------------


# Проверка запуска c sudo
if [ "$EUID" -ne 0 ]; then
    errorprint "Скрипт должен быть запущен через sudo!"
    exit 1
fi

# Функция: установка и настройка NFS-сервер
setup_nfs_server() {
    magentaprint "Устанавливаем NFS-сервер..."
    dnf install -y nfs-utils

    magentaprint "Создаём каталог для шаринга..."
    mkdir -p $NFS_SHARE
    chmod 777 $NFS_SHARE

    magentaprint "Настраиваем /etc/exports..."
    echo "$NFS_SHARE $SUBNET(rw,sync,no_root_squash)" > /etc/exports

    magentaprint "Запускаем NFS-сервис..."
    systemctl enable --now nfs-server
    systemctl status nfs-server --no-pager
    # Применяем настройки 
    exportfs -av /etc/exports
    
    magentaprint "Настраиваем файрвол..."
    firewall-cmd --permanent --add-service=nfs
    # firewall-cmd --permanent --add-service=rpc-bind
    # firewall-cmd --permanent --add-service=mountd
    firewall-cmd --reload
    firewall-cmd --list-all

    greenprint "NFS-сервер настроен!"
}


# Функция: установка и настройка NFS-клиента
setup_nfs_client() {
    magentaprint "Устанавливаем NFS-клиент..."
    dnf install -y nfs-utils

    magentaprint "Создаём точку монтирования..."
    mkdir -p $NFS_CLIENT_MOUNT
    ls -lah /mnt/

    # Проверка, не смонтирована ли уже директория
    if mountpoint -q "$NFS_CLIENT_MOUNT"; then
        greenprint "Директория $NFS_CLIENT_MOUNT уже смонтирована. Пропуск монтирования."
        df -hT $NFS_CLIENT_MOUNT
        return 0
    fi

    magentaprint "Монтируем NFS-директорию..."
    mount -t nfs $NFS_SERVER_IP:$NFS_SHARE $NFS_CLIENT_MOUNT

    magentaprint "Добавляем в /etc/fstab для автоматического монтирования..."
    echo "$NFS_SERVER_IP:$NFS_SHARE $NFS_CLIENT_MOUNT nfs defaults 0 0" >> /etc/fstab
    tail -n 1 /etc/fstab

    greenprint "NFS-клиент настроен!"
    greenprint "Директория находится:"
    df -hT $NFS_CLIENT_MOUNT
}


if [ "$1" == "server" ]; then
    setup_nfs_server
elif [ "$1" == "client" ]; then
    setup_nfs_client
else
    magentaprint "Использование: $0 {server|client}"
    exit 1
fi


