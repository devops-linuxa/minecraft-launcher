#!/bin/bash

set -e

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${THIS_DIR}"

MINECRAFT_CORE=$(
    whiptail \
        --title "Minecraft Bash Launcher" \
        --menu "Выберите тип ядра:" \
        15 65 3 \
        "Forge"   "Классическая база для тяжелых модов" \
        "Fabric"  "Оптимизация и современные моды" \
        "Vanilla" "Чистая официальная версия игры" \
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
MINECRAFT_DIR="${HOME}/.minecraft"
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

# if [[ "$MINECRAFT_CORE" == "forge" ]]; then
#    F_URL_VER='47.4.20'
#    VANILLA_VERSION="1.20.1"
#    FORGE_INSTALLER_VERSION="forge-$F_URL_VER"
#    FORGE_VERSION=${VANILLA_VERSION}-${FORGE_INSTALLER_VERSION}
#    FORGE_INSTALLER_PATH="${MINECRAFT_DIR}/versions/${FORGE_VERSION}/forge-installer.jar"
#    FORGE_INSTALLER_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${VANILLA_VERSION}-${F_URL_VER}/forge-${VANILLA_VERSION}-${F_URL_VER}-installer.jar"
#    if [ ! -s "$FORGE_INSTALLER_PATH" ]; then
#        echo "Скачиваем установщик Forge..."
#        mkdir -p "${MINECRAFT_DIR}/versions/${FORGE_VERSION}/natives"
#        curl -fL --progress-bar -o "$FORGE_INSTALLER_PATH" "$FORGE_INSTALLER_URL"
#    fi
#    echo "Запускаем установку Forge..."
#    touch "${MINECRAFT_DIR}/launcher_profiles.json"
#    cd "${MINECRAFT_DIR}"
#    if ! ${JAVA} -jar "${MINECRAFT_DIR}/versions/${FORGE_VERSION}/forge-installer.jar" --installClient; then
#        echo "Ошибка при установке Forge."
#        cd "${THIS_DIR}"
#        exit 1
#    fi
#    cd "${THIS_DIR}"
#    echo "Установка Forge завершена."
# fi


ASM_LIBS_PATH="${MINECRAFT_DIR}/libraries/org/ow2/asm"
SECJARHANDLER_LIBS_PATH="${MINECRAFT_DIR}/libraries/cpw/mods/securejarhandler"
CP_FILES=$(find "${MINECRAFT_DIR}/libraries" -name "*.jar" | tr '\n' ':')

if [[ "$MINECRAFT_CORE" == "forge" ]];then
    ${JAVA} \
      -Xmx5024M \
      -XX:+UnlockExperimentalVMOptions \
      -XX:+UseG1GC \
      -XX:G1NewSizePercent=20 \
      -XX:G1ReservePercent=20 \
      -XX:MaxGCPauseMillis=50 \
      -XX:G1HeapRegionSize=32M \
      -Dfml.ignoreInvalidMinecraftCertificates=true \
      -Dfml.ignorePatchDiscrepancies=true \
      -Djava.net.preferIPv4Stack=true \
      -Xss1M \
      -Djava.library.path="${MINECRAFT_DIR}/versions/Forge-1.20.1/natives" \
      -Djna.tmpdir="${MINECRAFT_DIR}/versions/Forge-1.20.1/natives" \
      -Dorg.lwjgl.system.SharedLibraryExtractPath="${MINECRAFT_DIR}/versions/Forge-1.20.1/natives" \
      -Dio.netty.native.workdir="${MINECRAFT_DIR}/versions/Forge-1.20.1/natives" \
      -Dminecraft.launcher.brand=minecraft-launcher \
      -Dminecraft.launcher.version=2.3.173 \
      -DignoreList=bootstraplauncher,securejarhandler,asm-commons,asm-util,asm-analysis,asm-tree,asm,JarJarFileSystems,client-extra,fmlcore,javafmllanguage,lowcodelanguage,mclanguage,forge-,"Forge-1.20.1.jar" \
      -DmergeModules=jna-5.12.1.jar,jna-platform-5.12.1.jar \
      -DlibraryDirectory="${MINECRAFT_DIR}/libraries" \
      -Dminecraft.applet.TargetDirectory="${MINECRAFT_DIR}" \
      -Dcountry="RU" \
      -Dlog4j.configurationFile="${MINECRAFT_DIR}/assets/log_configs/client-1.12.xml" \
      -cp "${SECJARHANDLER_LIBS_PATH}/2.1.10/securejarhandler-2.1.10.jar:${ASM_LIBS_PATH}/asm/9.9.1/asm-9.9.1.jar:${ASM_LIBS_PATH}/asm-commons/9.9.1/asm-commons-9.9.1.jar:${ASM_LIBS_PATH}/asm-tree/9.9.1/asm-tree-9.9.1.jar:${ASM_LIBS_PATH}/asm-util/9.9.1/asm-util-9.9.1.jar:${ASM_LIBS_PATH}/asm-analysis/9.9.1/asm-analysis-9.9.1.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/accesstransformers/8.0.4/accesstransformers-8.0.4.jar:${MINECRAFT_DIR}/libraries/org/antlr/antlr4-runtime/4.9.1/antlr4-runtime-4.9.1.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/eventbus/6.2.33/eventbus-6.2.33.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/forgespi/7.0.1/forgespi-7.0.1.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/coremods/5.2.4/coremods-5.2.4.jar:${MINECRAFT_DIR}/libraries/cpw/mods/modlauncher/10.0.9/modlauncher-10.0.9.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/unsafe/0.2.0/unsafe-0.2.0.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/mergetool/1.1.5/mergetool-1.1.5-api.jar:${MINECRAFT_DIR}/libraries/com/electronwill/night-config/core/3.6.4/core-3.6.4.jar:${MINECRAFT_DIR}/libraries/com/electronwill/night-config/toml/3.6.4/toml-3.6.4.jar:${MINECRAFT_DIR}/libraries/org/apache/maven/maven-artifact/3.8.5/maven-artifact-3.8.5.jar:${MINECRAFT_DIR}/libraries/net/jodah/typetools/0.6.3/typetools-0.6.3.jar:${MINECRAFT_DIR}/libraries/net/minecrell/terminalconsoleappender/1.2.0/terminalconsoleappender-1.2.0.jar:${MINECRAFT_DIR}/libraries/org/jline/jline-reader/3.12.1/jline-reader-3.12.1.jar:${MINECRAFT_DIR}/libraries/org/jline/jline-terminal/3.12.1/jline-terminal-3.12.1.jar:${MINECRAFT_DIR}/libraries/org/spongepowered/mixin/0.8.5/mixin-0.8.5.jar:${MINECRAFT_DIR}/libraries/org/openjdk/nashorn/nashorn-core/15.4/nashorn-core-15.4.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/JarJarSelector/0.3.19/JarJarSelector-0.3.19.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/JarJarMetadata/0.3.19/JarJarMetadata-0.3.19.jar:${MINECRAFT_DIR}/libraries/cpw/mods/bootstraplauncher/1.1.2/bootstraplauncher-1.1.2.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/JarJarFileSystems/0.3.19/JarJarFileSystems-0.3.19.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/fmlloader/1.20.1-47.4.20/fmlloader-1.20.1-47.4.20.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/fmlearlydisplay/1.20.1-47.4.20/fmlearlydisplay-1.20.1-47.4.20.jar:${MINECRAFT_DIR}/libraries/com/github/oshi/oshi-core/6.2.2/oshi-core-6.2.2.jar:${MINECRAFT_DIR}/libraries/com/google/code/gson/gson/2.10/gson-2.10.jar:${MINECRAFT_DIR}/libraries/com/google/guava/failureaccess/1.0.1/failureaccess-1.0.1.jar:${MINECRAFT_DIR}/libraries/com/google/guava/guava/31.1-jre/guava-31.1-jre.jar:${MINECRAFT_DIR}/libraries/com/ibm/icu/icu4j/71.1/icu4j-71.1.jar:${MINECRAFT_DIR}/libraries/org/tlauncher/authlib/4.0.43.1/authlib-4.0.43.1.jar:${MINECRAFT_DIR}/libraries/com/mojang/blocklist/1.0.10/blocklist-1.0.10.jar:${MINECRAFT_DIR}/libraries/com/mojang/brigadier/1.1.8/brigadier-1.1.8.jar:${MINECRAFT_DIR}/libraries/com/mojang/datafixerupper/6.0.8/datafixerupper-6.0.8.jar:${MINECRAFT_DIR}/libraries/com/mojang/logging/1.1.1/logging-1.1.1.jar:${MINECRAFT_DIR}/libraries/org/tlauncher/patchy/2.2.101/patchy-2.2.101.jar:${MINECRAFT_DIR}/libraries/com/mojang/text2speech/1.17.9/text2speech-1.17.9.jar:${MINECRAFT_DIR}/libraries/commons-codec/commons-codec/1.15/commons-codec-1.15.jar:${MINECRAFT_DIR}/libraries/commons-io/commons-io/2.11.0/commons-io-2.11.0.jar:${MINECRAFT_DIR}/libraries/commons-logging/commons-logging/1.2/commons-logging-1.2.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-buffer/4.1.82.Final/netty-buffer-4.1.82.Final.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-codec/4.1.82.Final/netty-codec-4.1.82.Final.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-common/4.1.82.Final/netty-common-4.1.82.Final.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-handler/4.1.82.Final/netty-handler-4.1.82.Final.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-resolver/4.1.82.Final/netty-resolver-4.1.82.Final.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-transport-classes-epoll/4.1.82.Final/netty-transport-classes-epoll-4.1.82.Final.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-transport-native-epoll/4.1.82.Final/netty-transport-native-epoll-4.1.82.Final-linux-aarch_64.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-transport-native-epoll/4.1.82.Final/netty-transport-native-epoll-4.1.82.Final-linux-x86_64.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-transport-native-unix-common/4.1.82.Final/netty-transport-native-unix-common-4.1.82.Final.jar:${MINECRAFT_DIR}/libraries/io/netty/netty-transport/4.1.82.Final/netty-transport-4.1.82.Final.jar:${MINECRAFT_DIR}/libraries/it/unimi/dsi/fastutil/8.5.9/fastutil-8.5.9.jar:${MINECRAFT_DIR}/libraries/net/java/dev/jna/jna-platform/5.12.1/jna-platform-5.12.1.jar:${MINECRAFT_DIR}/libraries/net/java/dev/jna/jna/5.12.1/jna-5.12.1.jar:${MINECRAFT_DIR}/libraries/net/sf/jopt-simple/jopt-simple/5.0.4/jopt-simple-5.0.4.jar:${MINECRAFT_DIR}/libraries/org/apache/commons/commons-compress/1.21/commons-compress-1.21.jar:${MINECRAFT_DIR}/libraries/org/apache/commons/commons-lang3/3.12.0/commons-lang3-3.12.0.jar:${MINECRAFT_DIR}/libraries/org/apache/httpcomponents/httpclient/4.5.13/httpclient-4.5.13.jar:${MINECRAFT_DIR}/libraries/org/apache/httpcomponents/httpcore/4.4.15/httpcore-4.4.15.jar:${MINECRAFT_DIR}/libraries/org/apache/logging/log4j/log4j-api/2.19.0/log4j-api-2.19.0.jar:${MINECRAFT_DIR}/libraries/org/apache/logging/log4j/log4j-core/2.19.0/log4j-core-2.19.0.jar:${MINECRAFT_DIR}/libraries/org/apache/logging/log4j/log4j-slf4j2-impl/2.19.0/log4j-slf4j2-impl-2.19.0.jar:${MINECRAFT_DIR}/libraries/org/joml/joml/1.10.5/joml-1.10.5.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-glfw/3.3.1/lwjgl-glfw-3.3.1.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-glfw/3.3.1/lwjgl-glfw-3.3.1-natives-linux.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-jemalloc/3.3.1/lwjgl-jemalloc-3.3.1.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-jemalloc/3.3.1/lwjgl-jemalloc-3.3.1-natives-linux.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-openal/3.3.1/lwjgl-openal-3.3.1.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-openal/3.3.1/lwjgl-openal-3.3.1-natives-linux.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-opengl/3.3.1/lwjgl-opengl-3.3.1.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-opengl/3.3.1/lwjgl-opengl-3.3.1-natives-linux.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-stb/3.3.1/lwjgl-stb-3.3.1.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-stb/3.3.1/lwjgl-stb-3.3.1-natives-linux.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-tinyfd/3.3.1/lwjgl-tinyfd-3.3.1.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl-tinyfd/3.3.1/lwjgl-tinyfd-3.3.1-natives-linux.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar:${MINECRAFT_DIR}/libraries/org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1-natives-linux.jar:${MINECRAFT_DIR}/libraries/org/slf4j/slf4j-api/2.0.1/slf4j-api-2.0.1.jar:${MINECRAFT_DIR}/versions/Forge-1.20.1/Forge-1.20.1.jar" \
      -p ${MINECRAFT_DIR}/libraries/cpw/mods/bootstraplauncher/1.1.2/bootstraplauncher-1.1.2.jar:${SECJARHANDLER_LIBS_PATH}/2.1.10/securejarhandler-2.1.10.jar:${ASM_LIBS_PATH}/asm-commons/9.9.1/asm-commons-9.9.1.jar:${ASM_LIBS_PATH}/asm-util/9.9.1/asm-util-9.9.1.jar:${ASM_LIBS_PATH}/asm-analysis/9.9.1/asm-analysis-9.9.1.jar:${ASM_LIBS_PATH}/asm-tree/9.9.1/asm-tree-9.9.1.jar:${ASM_LIBS_PATH}/asm/9.9.1/asm-9.9.1.jar:${MINECRAFT_DIR}/libraries/net/minecraftforge/JarJarFileSystems/0.3.19/JarJarFileSystems-0.3.19.jar \
      --add-modules ALL-MODULE-PATH \
      --add-opens java.base/java.util.jar=cpw.mods.securejarhandler \
      --add-opens java.base/java.lang.invoke=cpw.mods.securejarhandler \
      --add-exports java.base/sun.security.util=cpw.mods.securejarhandler \
      --add-exports jdk.naming.dns/com.sun.jndi.dns=java.naming cpw.mods.bootstraplauncher.BootstrapLauncher \
      --username Marginal \
      --version "Forge 1.20.1" \
      --gameDir "${MINECRAFT_DIR}" \
      --assetsDir "${MINECRAFT_DIR}/assets" \
      --assetIndex 5 \
      --uuid 7494d793d1c24a39b040e1d5769583e1 \
      --accessToken null \
      --clientId null \
      --xuid null \
      --userType mojang \
      --versionType modified \
      --width 925 --height 530 \
      --launchTarget forgeclient \
      --fml.forgeVersion 47.4.20 \
      --fml.mcVersion 1.20.1 \
      --fml.forgeGroup net.minecraftforge \
      --fml.mcpVersion 20230612.114412 \
      --fullscreen
fi

exit 0
