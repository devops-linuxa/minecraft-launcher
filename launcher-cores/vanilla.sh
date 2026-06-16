#!/bin/bash

echo 'Получаем главный Манифест MOJANG:'
if [ ! -s "${MOJANG_MANIFEST_JSON_FILE}" ]; then
    curl -s $MOJANG_MANIFEST_JSON_URL | jq > "${MOJANG_MANIFEST_JSON_FILE}"
fi

MOJANG_MANIFEST_JSON=$(cat "${MOJANG_MANIFEST_JSON_FILE}")
if [[ ! $MOJANG_MANIFEST_JSON ]];then
    echo 'FAILED' && exit 1
fi

echo "Получаем данные версии Vanilla ${MINECRAFT_VERSION}:"
minecraft_version_json_data=$(
    echo ${MOJANG_MANIFEST_JSON} |\
        jq --arg ver "$MINECRAFT_VERSION" \
        '.versions[] | select(.id == $ver)'
    )
if [[ ! ${minecraft_version_json_data} ]];then
    echo 'FAILED' && exit 1
fi

echo "Получаем ссылку для json файла:"
json_manifest_url=$(
    echo "$minecraft_version_json_data" | jq -r .url
)
if [[ ! $json_manifest_url ]];then
    echo 'FAILED' && exit 1
fi

echo "Скачиваем json файл:"
if [ ! -s "${JSON_FILE_VANILLA}" ]; then
    curl -f --progress-bar -o ${JSON_FILE_VANILLA} $json_manifest_url
else
    echo "Файл ${JSON_FILE_VANILLA} уже существует, пропускаем..."
fi
if ! file ${JSON_FILE_VANILLA} | grep 'JSON text data' --color >/dev/null 2>&1;then
    echo 'FAILED'
    rm ${JSON_FILE_VANILLA}
    exit 1
fi

echo "Получаем ссылку для jar:"
jar_client_url=$(
    cat ${JSON_FILE_VANILLA} |\
        jq '.downloads.client' |\
        jq -r '.url'
)
if [[ ! $jar_client_url ]];then
    echo 'FAILED' && exit 1
fi

echo "Скачиваем jar файл (Игровой клиент):"
if [ ! -f "${JAR_FILE_VANILLA}" ]; then
    curl -f --progress-bar -o ${JAR_FILE_VANILLA} $jar_client_url
else
    echo "Файл ${JAR_FILE_VANILLA} уже существует, пропускаем..."
fi
if ! file ${JAR_FILE_VANILLA} | grep '(JAR)' >/dev/null 2>&1;then
    echo 'FAILED'
    exit 1
fi

echo 'Вытаскиваем список библиотек:'
libs_list=$(
    jq '.libraries[].downloads.artifact | select(.path | contains("linux") or (contains("natives") | not)) | .path' ${JSON_FILE_VANILLA}
)
if [[ ! $libs_list ]];then
    echo 'FAILED'
    exit 1
fi

echo 'Качаем все библиотеки и генерируем нужные директории:'

if ! jq -r '.libraries[].downloads.artifact | select(.path | contains("linux") or (contains("natives") | not)) | "\(.url)\n\(.path)"' \
        "${JSON_FILE_VANILLA}" |\
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

echo "Получаем ссылку на assetIndex:"
asset_index_url=$(
    jq -r '.assetIndex.url' ${JSON_FILE_VANILLA}
)
if [[ ! $asset_index_url ]];then
    echo 'FAILED'
    exit 1
else
    asset_index_file=$(basename $asset_index_url)
    asset_index=$(echo $asset_index_file | awk -F"." '{print $1}')
    echo "asset_index: $asset_index"
fi

echo 'Скачиваем манифест assets indexes:'
if [ ! -f "assets/indexes/$asset_index_file" ]; then
    if ! curl -fL --progress-bar -o assets/indexes/$asset_index_file $asset_index_url;then
        echo 'FAILED'
        exit 1
    fi
else
    echo "Манифест ассетов уже существует, пропускаем..."
fi

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

echo 'Проверяем и скачиваем natives библиотеки для Linux...'
jq -r '.libraries[] | select(.downloads.classifiers."natives-linux" != null) | .downloads.classifiers."natives-linux" | "\(.url)\n\(.path)"' \
    "${JSON_FILE_VANILLA}" |\
    xargs -P "$THREADS" -n 2 bash -c '
    url="$1"
    path="libraries/$2"
    if [ -n "$url" ] && [ ! -f "$path" ]; then
        mkdir -p "$(dirname "$path")"
        curl -fL --progress-bar -o "$path" "$url"
    fi
' _

echo 'Извлекаем .so файлы в директорию natives...'
jq -r '.libraries[] | select(.downloads.classifiers."natives-linux" != null) | .downloads.classifiers."natives-linux".path' "${JSON_FILE_VANILLA}" |\
    while read -r native_jar; do
        if [ -f "libraries/$native_jar" ]; then
            unzip -o \
                -q "libraries/$native_jar" "*.so" \
                -d "${MINECRAFT_DIR}/versions/${VERSION}/natives" 2>/dev/null || true
        fi
    done

echo 'Читаем JSON-файл запущенной версии и собираем пути только к её родным библиотекам'
LIBS_PATHS=$(
    jq -r '.libraries[].downloads.artifact | select(.path | contains("linux") or (contains("natives") | not)) | .path' \
    "$JSON_FILE_VANILLA" \
)

CLASSPATH=""
while read -r lib_path; do
    if [ -n "$lib_path" ]; then
        CLASSPATH="${CLASSPATH}${MINECRAFT_DIR}/libraries/${lib_path}:"
    fi
done <<< "$LIBS_PATHS"
CLASSPATH="${CLASSPATH}${JAR_FILE_VANILLA}"

MAIN_CLASS="net.minecraft.client.main.Main"


${JAVA} -Xmx4G -XX:+UseG1GC \
    -Djava.library.path="$MINECRAFT_DIR/versions/$VERSION/natives" \
    -Dorg.lwjgl.util.NoChecks=false \
    -Dorg.lwjgl.glfw.build=wayland \
    -cp "$CLASSPATH" \
    "$MAIN_CLASS" \
    --username "$PLAYER_NAME" \
    --version "$MINECRAFT_VERSION" \
    --gameDir "$MINECRAFT_DIR" \
    --assetsDir "$MINECRAFT_DIR/assets" \
    --assetIndex "$asset_index" \
    --uuid "$UUID" \
    --accessToken "$TOKEN" \
    --userType offline \
    --versionType "${MINECRAFT_CORE}"
