#!/bin/bash
set -e

echo "========================================================="
echo "🧬 1. APLICANDO INYECCIÓN BIÓNICA EN INSTANCIA VULKAN"
echo "========================================================="
sed -i 's/#if defined(HAVE_MEMFD_CREATE) \&\& !defined __TERMUX__/#if defined(HAVE_MEMFD_CREATE)/' src/util/anon_file.c

mkdir -p src/gallium/auxiliary/util
echo "static void util_run_tests(void) {}" > src/gallium/auxiliary/util/u_tests.c

TARGET_INSTANCE="src/panfrost/vulkan/panvk_instance.c"
if [ -f "$TARGET_INSTANCE" ]; then
    echo "-> Soldando bypass molecular en inodo real: $TARGET_INSTANCE"
    sed -i '1i #include <stdlib.h>' "$TARGET_INSTANCE"
    sed -i '2i __attribute__((constructor)) static void panvk_instance_mali_init() {' "$TARGET_INSTANCE"
    sed -i '3i     setenv("PAN_MESA_DEBUG", "kbase", 1);' "$TARGET_INSTANCE"
    sed -i '4i     setenv("PAN_EXPERIMENTAL_KBASE_GL", "1", 1);' "$TARGET_INSTANCE"
    sed -i '5i     setenv("MESA_LOADER_DRIVER_OVERRIDE", "panfrost", 1);' "$TARGET_INSTANCE"
    sed -i '6i }' "$TARGET_INSTANCE"
    echo "-> Parches de elusión inyectados de fábrica en la raíz de Vulkan."
fi

echo "========================================================="
echo "🔧 2. TRADUCIENDO CONFIGURACIÓN CRUZADA Y MESON SETUP"
echo "========================================================="
export ANDROID_NDK_HOME="$ANDROID_NDK_LATEST_HOME"
export MESON_WORKING_DIR="$GITHUB_WORKSPACE"
export PKG_CONFIG="/usr/bin/pkg-config"
export PKG_CONFIG_FOR_BUILD="/usr/bin/pkg-config"
export PKG_CONFIG_PATH_FOR_BUILD="/usr/lib/x86_64-linux-gnu/pkgconfig"
export PKG_CONFIG_PATH="$ANDROID_NDK_LATEST_HOME/prebuilt/linux-x86_64/lib/pkgconfig"

envsubst < android.toml > android-cross.txt

meson setup build --cross-file android-cross.txt --wrap-mode=forcefallback \
    -Ddefault_library=both \
    -Dbuildtype=debugoptimized \
    -Dstrip=false \
    -Db_lto=false \
    -Dplatforms=x11 \
    -Dplatform-sdk-version=30 \
    -Dglx=disabled \
    -Dgbm=disabled \
    -Degl=disabled \
    -Dopengl=true \
    -Dgles1=disabled \
    -Dgles2=disabled \
    -Dglvnd=disabled \
    -Dvalgrind=disabled \
    -Dgallium-drivers=panfrost \
    -Dshared-glapi=enabled \
    -Dzstd=disabled \
    -Dgallium-rusticl=false \
    -Dmesa-clc=system \
    -Dprecomp-compiler=system \
    -Dvulkan-drivers=panfrost \
    -Dllvm=disabled \
    -Dpanfrost-kmds=kbase,panthor

echo "========================================================="
echo "🚀 3. COMPILANDO CONTROLADOR Y SUBPROYECTOS CON NINJA"
echo "========================================================="
meson compile -C build

echo "========================================================="
echo "📦 4. EL BISTURÍ DE TONELAJE (RECORTE DE PESO MUERTO)"
echo "========================================================="
# Localizamos la herramienta oficial de recorte del NDK de Android del Host
STRIP_TOOL=$(find "$ANDROID_NDK_LATEST_HOME" -name "aarch64-linux-android-strip" -o -name "llvm-strip" | head -n 1)
echo "-> Herramientas de precision detectada en: $STRIP_TOOL"

# Aplicamos el recorte quirurgico sobre el binario gigante antes de moverlo
# Esto succiona los 100MB de texto parásito y deja el archivo en sus 17.6 MiB reales limpios de produccion
"$STRIP_TOOL" ./build/src/panfrost/vulkan/libvulkan_panfrost.so
echo "-> Recorte de peso muerto finalizado con éxito."

# Tus dos mangueras de copiado originales intactas y planas
mkdir -p ./pack_flat
mkdir -p ./pack_usr/usr/lib
mkdir -p ./pack_usr/usr/share/vulkan/icd.d

find build/subprojects/ -name "*adrenotools*.so*" -exec cp -fv {} ./pack_flat/libadrenotools.so \; -exec cp -fv {} ./pack_usr/usr/lib/libadrenotools.so \; || true

cp -fv ./build/src/panfrost/vulkan/libvulkan_panfrost.so ./pack_flat/libvulkan_wrapper.so
cp -fv ./build/src/panfrost/vulkan/libvulkan_panfrost.so ./pack_usr/usr/lib/libvulkan_wrapper.so
find build/ -name "libGL.so*" -exec cp -fv {} ./pack_flat/libGL.so.1 \; -exec cp -fv {} ./pack_usr/usr/lib/libGL.so.1 \;
find build/ -name "libglapi.so*" -exec cp -fv {} ./pack_flat/libglapi.so.0 \; -exec cp -fv {} ./pack_usr/usr/lib/libglapi.so.0 \;

cat << 'EOF' > ./pack_flat/meta.json
{
  "schemaVersion": 1,
  "name": "Mesa PanVK Driver for Mali G52",
  "description": "Custom PanVK Hibrido Saneado de Alto Rendimiento",
  "author": "Mesa & Over-cmd Community",
  "packageVersion": "26.3",
  "vendor": "Mesa",
  "driverVersion": "1",
  "libraryName": "libvulkan_wrapper.so"
}
EOF

cat << 'EOF' > ./pack_usr/usr/share/vulkan/icd.d/wrapper_icd.aarch64.json
{
  "file_format_version": "1.0.0",
  "ICD": {
    "library_path": "libvulkan_wrapper.so",
    "api_version": "1.3.289"
  }
}
EOF

chmod 755 ./pack_flat/*.so* ./pack_usr/usr/lib/*.so*
chmod 644 ./pack_flat/meta.json ./pack_usr/usr/share/vulkan/icd.d/*.json

echo "========================================================="
echo "🔍 VERIFICACIÓN DE MEGABYTES SANEADOS (DEBE MEDIR ~17.6 MiB)"
echo "========================================================="
ls -lh ./pack_flat/libvulkan_wrapper.so
echo "========================================================="

cd pack_flat
zip -r ../panvk-bannerlator-driver.zip ./*
cd ..

cd pack_usr
tar -I 'zstd -v -19' -cf ../wrapper.tar.zst usr/
cd ..

echo ">>> ARSENAL DUAL PURIFICADO COMPLETADO CON ÉXITO <<<"
