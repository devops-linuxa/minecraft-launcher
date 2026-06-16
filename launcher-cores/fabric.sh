#!/bin/bash

echo "Получаем данные о Fabric Loader для версии ${MINECRAFT_VERSION}:"
if [ ! -s "${FABRIC_VERSION_JSON_FILE}" ]; then
    if [[ "$MINECRAFT_VERSION" == "26.1.2" ]]; then
        FABRIC_API_URL="https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}?includeSnapshots=true"
    else
        FABRIC_API_URL="https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}"
    fi
    curl -s "$FABRIC_API_URL" | jq '.[0]' > "${FABRIC_VERSION_JSON_FILE}"
fi

FABRIC_DATA=$(cat "${FABRIC_VERSION_JSON_FILE}")
if [[ "$FABRIC_DATA" == "null" || -z "$FABRIC_DATA" ]]; then
    echo "Ошибка: Не удалось найти Fabric Loader для версии ${MINECRAFT_VERSION}."
    rm -f "${FABRIC_VERSION_JSON_FILE}"
    exit 1
fi

FABRIC_LOADER_VERSION=$(echo "$FABRIC_DATA" | jq -r '.loader.version')
JAR_FILE_FABRIC="${MINECRAFT_DIR}/versions/${VERSION}/fabric-loader-${FABRIC_LOADER_VERSION}.jar"
FABRIC_JAR_URL="https://maven.fabricmc.net/net/fabricmc/fabric-loader/${FABRIC_LOADER_VERSION}/fabric-loader-${FABRIC_LOADER_VERSION}.jar"

echo "Скачиваем Fabric Loader JAR (${FABRIC_LOADER_VERSION}):"
if [ ! -s "${JAR_FILE_FABRIC}" ]; then
    curl -f --progress-bar -o "${JAR_FILE_FABRIC}" "$FABRIC_JAR_URL"
fi

if [ ! -s "${JAR_FILE_FABRIC}" ]; then
    echo 'FAILED (Fabric JAR пустой или не скачался)'
    exit 1
fi

echo "Запрашиваем официальный профиль зависимостей Fabric..."
FABRIC_PROFILE_JSON_FILE="${MINECRAFT_DIR}/versions/${VERSION}/fabric_profile.json"
if [ ! -s "${FABRIC_PROFILE_JSON_FILE}" ]; then
    PROFILE_URL="https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_LOADER_VERSION}/profile/json"
    curl -s "$PROFILE_URL" > "${FABRIC_PROFILE_JSON_FILE}"
fi

PROFILE_JSON=$(cat "${FABRIC_PROFILE_JSON_FILE}")
if [[ -z "$PROFILE_JSON" || "$PROFILE_JSON" == "null" ]]; then
    echo "Ошибка получения профиля зависимостей."
    rm -f "${FABRIC_PROFILE_JSON_FILE}"
    exit 1
fi

echo "Скачиваем обязательные библиотеки (ASM, Mixin, Intermediary)..."
CLASSPATH_FABRIC_LIBS=""
while read -r name && read -r url; do
    if [[ -n "$name" && "$name" != "null" ]]; then
        IFS=':' read -r group artifact version <<< "$name"
        group_path=$(echo "$group" | tr '.' '/')
        rel_path="${group_path}/${artifact}/${version}/${artifact}-${version}.jar"
        full_path="${MINECRAFT_DIR}/libraries/${rel_path}"
        if [[ -z "$url" || "$url" == "null" ]]; then
            download_url="https://maven.fabricmc.net/${rel_path}"
        else
            [[ "$url" != */ ]] && url="${url}/"
            download_url="${url}${rel_path}"
        fi
        if [ ! -f "$full_path" ]; then
            mkdir -p "$(dirname "$full_path")"
            curl -fL --progress-bar -o "$full_path" "$download_url"
        fi
        if [[ "$artifact" == "fabric-loader" ]]; then
            continue
        fi
        CLASSPATH_FABRIC_LIBS="${CLASSPATH_FABRIC_LIBS}${full_path}:"
    fi
done <<< "$(echo "$PROFILE_JSON" | jq -r '.libraries[] | "\(.name)\n\(.url)"')"

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

# Добавляем в общий CLASSPATH ванильный клиент
CLASSPATH="${CLASSPATH}${JAR_FILE_VANILLA}"

# Если выбран Fabric — перестраиваем класс запуска и дописываем его либы в CLASSPATH
MAIN_CLASS="net.fabricmc.loader.impl.launch.knot.KnotClient"
# Добавляем джарник лоадера и его зависимости в самое начало CLASSPATH
CLASSPATH="${JAR_FILE_FABRIC}:${CLASSPATH_FABRIC_LIBS}${CLASSPATH}"

# Пинаем джаву на запуск
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
