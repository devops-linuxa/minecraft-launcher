#!/bin/bash

MINECRAFT_VERSION=${1:-"1.21.1"}
MINECRAFT_DIR="${HOME}/.minecraft"
MOJANG_MANIFEST_JSON_URL='https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
THREADS=$(nproc)
JSON_FILE="${MINECRAFT_DIR}/versions/${MINECRAFT_VERSION}/${MINECRAFT_VERSION}.json"
JAR_FILE="${MINECRAFT_DIR}/versions/${MINECRAFT_VERSION}/client.jar"

set -e

cd ${MINECRAFT_DIR}
mkdir -p ${MINECRAFT_DIR}/versions/${MINECRAFT_VERSION}
mkdir -p ${MINECRAFT_DIR}/assets/indexes

### START:
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

if [[ ! -f $JSON_FILE ]];then
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
fi

if [[ ! -f $JAR_FILE ]];then
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
fi

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
