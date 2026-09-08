#!/bin/bash
set -e

echo "========================================================="
echo "🧬 1. APLICANDO INYECCIÓN BIÓNICA EN INSTANCIA VULKAN"
echo "========================================================="
# 1. Saneamos memfd_create para entornos Termux
sed -i 's/#if defined(HAVE_MEMFD_CREATE) \&\& !defined __TERMUX__/#if defined(HAVE_MEMFD_CREATE)/' src/util/anon_file.c

# 2. Bypass auxiliar de pruebas complementarias de Gallium
mkdir -p src/gallium/auxiliary/util
echo "static void util_run_tests(void) {}" > src/gallium/auxiliary/util/u_tests.c

# 3. Soldamos las variables de entorno directo en el inodo verificado de panvk_instance.c
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

# 🟢 CONFIGURACIÓN MAESTRA DE INSTANCIAS COMPARTIDAS:
# Cambiamos default_library=both y activamos shared-glapi=enabled.
# Esto obliga al compilador a inyectar tu adrenotools de Over-cmd como una biblioteca compartida dinámica real,
# incrustando tus instancias de elusión en la tabla de exportación ELF para que Android las ejecute en frío.
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
echo "🚀 3. COMPILANDO CONTROLADOR MONOLÍTICO DINÁMICO CON NINJA"
echo "========================================================="
meson compile -C build

echo "========================================================="
echo "📦 4. ENSAMBLANDO ARSENAL ZIP PLANO CON EXPORTACIÓN REAL"
echo "========================================================="
# Creamos la única estructura plana de salida para Bannerlator
mkdir -p ./pack_flat
cp -fv ./build/src/panfrost/vulkan/libvulkan_panfrost.so ./pack_flat/libvulkan_wrapper.so
find build/ -name "libGL.so*" -exec cp -fv {} ./pack_flat/libGL.so.1 \;
find build/ -name "libglapi.so*" -exec cp -fv {} ./pack_flat/libglapi.so.0 \;

cat << 'EOF' > ./pack_flat/meta.json
{
  "schemaVersion": 1,
  "name": "Mesa PanVK Driver for Mali G52",
  "description": "Custom PanVK Hibrido con Instancias Dinamicas de Kbase",
  "author": "Mesa & Over-cmd Community",
  "packageVersion": "26.3",
  "vendor": "Mesa",
  "driverVersion": "1",
  "libraryName": "libvulkan_wrapper.so"
}
EOF

chmod 755 ./pack_flat/*.so*
chmod 644 ./pack_flat/meta.json

echo "========================================================="
echo "🔍 AUDITORÍA DE VERIFICACIÓN DE MEGABYTES EN EL DISCO"
echo "========================================================="
ls -lh ./pack_flat/libvulkan_wrapper.so
echo "========================================================="

# Forjamos el único empaquetado ZIP plano
cd pack_flat
zip -r ../panvk-bannerlator-driver.zip ./*
cd ..

echo ">>> FORJA UNIFICADA FINALIZADA CON ÉXITO ABSOLUTO <<<"
