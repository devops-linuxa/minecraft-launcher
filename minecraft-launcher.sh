#!/bin/bash

source ./minecraft-installer.sh

MINECRAFT_DIR="$HOME/.minecraft"
VERSION="$MINECRAFT_VERSION"
CLIENT_JAR=${JAR_FILE}


# Параметры игрока (оффлайн)
PLAYER_NAME="Marginal"

UUID_STEVE="00000000-0000-0000-0000-000000000006"   # Стив из Волк из волкстрита
UUID_ALEX="00000000-0000-0000-0000-000000000000"    # Девка Светлая
UUID_ARI="00000000-0000-0000-0000-000000000001"     # Девка Вторая Рыжая
UUID_KAI="00000000-0000-0000-0000-000000000003"     # Бландин на стиле (Ведьмак)
UUID_NOOR="00000000-0000-0000-0000-000000000005"    # Стиляга Индус
UUID_SUNNY="00000000-0000-0000-0000-000000000007"   # Саша Фермер
UUID_ZURI="00000000-0000-0000-0000-000000000008"    # Студент по обмену
UUID_EFE="00000000-0000-0000-0000-000000000002"     # Артемий Синяя Галава
UUID_MAKENA="00000000-0000-0000-0000-000000000004"  # Девка Тёмная

UUID=$UUID_SUNNY

TOKEN="0"

# Автоматический сбор всех библиотек в одну classpath-строку
LIBS=$(find "$MINECRAFT_DIR/libraries" -name "*.jar" \
    | grep -v "natives-windows" \
    | grep -v "natives-macos" \
    | grep -v "windows-arm64" \
    | grep -v "windows-x86" \
    | grep -v "macos-arm64" \
    | tr '\n' ':')

CLASSPATH="${LIBS}${CLIENT_JAR}"


# Запуск игры
java -Xmx4G -XX:+UseG1GC \
    -Djava.library.path="$MINECRAFT_DIR/versions/$VERSION/natives" \
    -cp "$CLASSPATH" \
    net.minecraft.client.main.Main \
    --username "$PLAYER_NAME" \
    --version "$VERSION" \
    --gameDir "$MINECRAFT_DIR" \
    --assetsDir "$MINECRAFT_DIR/assets" \
    --assetIndex "$asset_index" \
    --uuid "$UUID" \
    --accessToken "$TOKEN" \
    --userType offline \
    --versionType release
