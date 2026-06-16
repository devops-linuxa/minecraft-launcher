#!/bin/bash

set -e

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${THIS_DIR}"

MINECRAFT_CORE=$(
    whiptail \
        --title "Minecraft Bash Launcher" \
        --menu "Выберите тип ядра:" \
        15 65 3 \
        "Fabric"  "Оптимизация и современные моды" \
        "Vanilla" "Чистая официальная версия игры" \
        "Forge"   "Классическая база для тяжелых модов" \
    3>&1 1>&2 2>&3
)

# Lower Case:
MINECRAFT_CORE="${MINECRAFT_CORE,,}"

if [[ "$MINECRAFT_CORE" == "vanilla" ]]; then
    MINECRAFT_VERSION=$(
        whiptail \
            --title "Minecraft Bash Launcher [Vanilla]" \
            --menu "Выберите версию игры:" \
            20 70 11 \
            "26.1.2"  "Экспериментальная ваниль          [Требует Java 25/26]" \
            "1.21.11" "Актуальный финал (Tricky Trials)  [Требует Java 21]" \
            "1.20.1" "Актуальный финал (Tricky Trials)   [Требует Java 17]" \
            "1.20.6"  "Стабильный финал прошлых лет      [Требует Java 21]" \
            "1.19.4"  "Идеал для средних ПК (Trails)     [Требует Java 17]" \
        3>&1 1>&2 2>&3
    )
elif [[ "$MINECRAFT_CORE" == "fabric" ]]; then
    MINECRAFT_VERSION=$(
        whiptail \
            --title "Minecraft Bash Launcher [Fabric]" \
            --menu "Выберите версию с поддержкой Fabric:" \
            20 70 11 \
            "26.1.2"  "Экспериментальная ваниль + моды  [Требует Java 25/26]" \
            "1.21.11" "Актуальный финал + моды          [Требует Java 21]" \
            "1.20.1" "Актуальный финал (Tricky Trials)  [Требует Java 17]" \
            "1.20.6"  "Стабильный финал прошлых лет     [Требует Java 21]" \
            "1.19.4"  "Идеал для средних ПК (Trails)    [Требует Java 17]" \
        3>&1 1>&2 2>&3
    )
elif [[ "$MINECRAFT_CORE" == "forge" ]]; then
    MINECRAFT_VERSION=$(
        whiptail \
            --title "Minecraft Bash Launcher [Forge]" \
            --menu "Выберите версию с поддержкой Forge:" \
            20 70 11 \
            "1.20.1"  "Стабильный финал прошлых лет     [Требует Java 17]" \
        3>&1 1>&2 2>&3
    )
fi

case "$MINECRAFT_VERSION" in
    "26.1.2")
        JAVA_VERSION="25"
        ;;
    "1.21.11" | "1.20.6")
        JAVA_VERSION="21"
        ;;
    "1.19.4" | "1.20.1")
        JAVA_VERSION="17"
        ;;
    *)
        echo "Неизвестная версия Minecraft. Не удалось определить Java."
        exit 1
        ;;
esac

JAVA="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk/bin/java"
export MINECRAFT_DIR="${HOME}/.minecraft"
MOJANG_MANIFEST_JSON_URL='https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
MOJANG_MANIFEST_JSON_FILE="${MINECRAFT_DIR}/version_manifest_v2.json"
THREADS=$(nproc)
VERSION="${MINECRAFT_VERSION}-${MINECRAFT_CORE}"
JSON_FILE_VANILLA="${MINECRAFT_DIR}/versions/${VERSION}/${MINECRAFT_VERSION}.json"
JAR_FILE_VANILLA="${MINECRAFT_DIR}/versions/${VERSION}/client.jar"
FABRIC_VERSION_JSON_FILE="${MINECRAFT_DIR}/versions/${VERSION}/fabric_loader_version.json"

# Параметры игрока (оффлайн)
PLAYER_NAME="Marginal"
TOKEN="0"

UUID_STEVE="00000000-0000-0000-0000-000000000006"   # Стив из Волк из волкстрита
UUID_ALEX="00000000-0000-0000-0000-000000000000"    # Девка Светлая
UUID_ARI="00000000-0000-0000-0000-000000000001"     # Девка Вторая Рыжая
UUID_KAI="00000000-0000-0000-0000-000000000003"     # Бландин на стиле (Ведьмак)
UUID_NOOR="00000000-0000-0000-0000-000000000005"    # Стиляга Индус
UUID_SUNNY="00000000-0000-0000-0000-000000000007"   # Саша Фермер
UUID_ZURI="00000000-0000-0000-0000-000000000008"    # Студент по обмену
UUID_EFE="00000000-0000-0000-0000-000000000002"     # Артемий Синяя Галава
UUID_MAKENA="00000000-0000-0000-0000-000000000004"  # Девка Тёмная

UUID=$UUID_ZURI

cd ${MINECRAFT_DIR}

mkdir -p ${MINECRAFT_DIR}/versions/${VERSION}/
mkdir -p ${MINECRAFT_DIR}/assets/indexes

if [[ "${MINECRAFT_CORE}" == "vanilla" ]];then
    source ${MINECRAFT_DIR}/launcher-cores/vanilla.sh
fi

if [[ "${MINECRAFT_CORE}" == "fabric" ]];then
    source ${MINECRAFT_DIR}/launcher-cores/fabric.sh
fi

if [[ "${MINECRAFT_CORE}" == "forge" ]];then
    source ${MINECRAFT_DIR}/launcher-cores/forge.sh
fi
