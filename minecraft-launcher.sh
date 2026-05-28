#!/bin/bash

set -e

MINECRAFT_VERSION=${1:-"1.21.1"}
JAVA_VERSION='26'
JAVA="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk/bin/java"
MINECRAFT_DIR="${HOME}/.minecraft"
MOJANG_MANIFEST_JSON_URL='https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
THREADS=$(nproc)
JSON_FILE="${MINECRAFT_DIR}/versions/${MINECRAFT_VERSION}/${MINECRAFT_VERSION}.json"
JAR_FILE="${MINECRAFT_DIR}/versions/${MINECRAFT_VERSION}/client.jar"
VERSION="$MINECRAFT_VERSION"

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

UUID=$UUID_SUNNY

cd ${MINECRAFT_DIR}

is_version_installed(){
    ls -1 versions/ |\
        grep -x $MINECRAFT_VERSION >/dev/null \
        && true || false 
}

mkdir -p ${MINECRAFT_DIR}/versions/${MINECRAFT_VERSION}
mkdir -p ${MINECRAFT_DIR}/assets/indexes

echo 'Получаем главный Манифест MOJANG:'
MOJANG_MANIFEST_JSON=$(
    curl -s $MOJANG_MANIFEST_JSON_URL | jq
)
if [[ ! $MOJANG_MANIFEST_JSON ]];then
    echo 'FAILED' && exit 1
fi
echo 'OK'

echo "Получаем данные версии ${MINECRAFT_VERSION}:"
minecraft_version_json_data=$(
    echo ${MOJANG_MANIFEST_JSON} |\
        jq --arg ver "$MINECRAFT_VERSION" \
        '.versions[] | select(.id == $ver)'
    )
if [[ ! ${minecraft_version_json_data} ]];then
    echo 'FAILED' && exit 1
fi
echo 'OK'

if ! is_version_installed;then
    echo "Получаем ссылку для json файла:"
    json_manifest_url=$(
        echo "$minecraft_version_json_data" | jq -r .url
    )
    if [[ ! $json_manifest_url ]];then
        echo 'FAILED' && exit 1
    fi
    echo 'OK'


    echo "Скачиваем json файл:"
    curl -f --progress-bar -o ${JSON_FILE} $json_manifest_url
    if ! file ${JSON_FILE} | grep 'JSON text data' --color >/dev/null 2>&1;then
        echo 'FAILED'
        rm ${JSON_FILE}
        exit 1
    fi
    echo 'OK'

    echo "Получаем ссылку для jar:"
    jar_client_url=$(
        cat ${JSON_FILE} |\
            jq '.downloads.client' |\
            jq -r '.url'
    )
    if [[ ! $jar_client_url ]];then
        echo 'FAILED' && exit 1
    fi
    echo 'OK'

    echo "Скачиваем jar файл (Игровой клиент):"
    curl -f --progress-bar -o ${JAR_FILE} $jar_client_url
    if ! file ${JAR_FILE} | grep '(JAR)' >/dev/null 2>&1;then
        echo 'FAILED'
        exit 1
    fi
    echo 'OK'

    echo 'Вытаскиваем список библиотек:'
    libs_list=$(
        jq '.libraries[].downloads.artifact | select(.path | contains("linux") or (contains("natives") | not)) | .path' ${JSON_FILE}
    )
    if [[ ! $libs_list ]];then
        echo 'FAILED'
        exit 1
    fi
    echo 'OK'

    echo 'Качаем все библиотеки и генерируем нужные директории:'
    cd ${MINECRAFT_DIR}/
    if ! jq -r '.libraries[].downloads.artifact | select(.path | contains("linux") or (contains("natives") | not)) | "\(.url)\n\(.path)"' \
            "${JSON_FILE}" |\
            xargs -P "$THREADS" -n 2 bash -c '
        url="$1"
        path="libraries/$2"
        if [ -n "$url" ] && [ ! -f "$path" ]; then
            mkdir -p "$(dirname "$path")"
            curl -fL --progress-bar -o "$path" "$url"
        fi
    ' _ ;
    then
        echo 'FAILED'
        exit 1
    fi
    echo 'OK'
fi

echo "Получаем ссылку на assetIndex:"
asset_index_url=$(
    jq -r '.assetIndex.url' ${JSON_FILE}
)
if [[ ! $asset_index_url ]];then
    echo 'FAILED'
    exit 1
else
    asset_index_file=$(basename $asset_index_url)
    asset_index=$(echo $asset_index_file | awk -F"." '{print $1}')
    echo "asset_index: $asset_index"
    echo 'OK'
fi

echo 'Скачиваем манифест assets indexes:'
if ! curl -fL --progress-bar -o assets/indexes/$asset_index_file $asset_index_url;then
    echo 'FAILED'
    exit 1
fi
echo 'OK'

echo 'Выкачиваем все ассеты (самый долгий пункт):'
if ! jq -r '.objects[].hash' assets/indexes/$(basename $asset_index_url) |\
        xargs -P "$THREADS" -I {} bash -c '
        hash="{}"
        first2="${hash:0:2}"
        url="https://resources.download.minecraft.net/${first2}/${hash}"
        path="assets/objects/${first2}/${hash}"
        if [ ! -f "$path" ]; then
            mkdir -p "assets/objects/${first2}"
            curl -fL --progress-bar -o "$path" "$url"
        fi
    ';
then
    echo 'FAILED'
    exit 1
fi
echo 'OK'

# Читаем JSON-файл запущенной версии и собираем пути только к её родным библиотекам
LIBS_PATHS=$(
    jq -r '.libraries[].downloads.artifact | select(.path | contains("linux") or (contains("natives") | not)) | .path' \
    "$JSON_FILE" \
)

CLASSPATH=""
while read -r lib_path; do
    if [ -n "$lib_path" ]; then
        CLASSPATH="${CLASSPATH}${MINECRAFT_DIR}/libraries/${lib_path}:"
    fi
done <<< "$LIBS_PATHS"

# Добавляем сам игровой клиент (client.jar)
CLASSPATH="${CLASSPATH}${JAR_FILE}"



# Запуск игры
${JAVA} -Xmx4G -XX:+UseG1GC \
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
