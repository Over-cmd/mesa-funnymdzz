#!/bin/bash
set -e

BUILD_DIR="build"
rm -rf pkg && mkdir -p pkg/usr/lib pkg/usr/share/vulkan/icd.d pkg/usr/share/vulkan/settings.d

echo "-> Cambiando permisos globales del directorio build para permitir el rescate..."
sudo chmod -R 777 "$BUILD_DIR" 2>/dev/null || true

echo "-> Buscando de forma ultra-agresiva la librería binaria generada..."
# 🟢 BÚSQUEDA ABSOLUTA: Escanea extensiones parciales y comodines en cualquier subcarpeta
TARGET_SO=$(find "$BUILD_DIR" -type f -name "libvulkan_*.so*" | head -n 1)

if [ -n "$TARGET_SO" ] && [ -f "$TARGET_SO" ]; then
  echo "-> ¡ÉXITO TOTAL! Librería localizada físicamente en: $TARGET_SO"
  echo "-> Extrayendo y renombrando para el ecosistema Winlator..."
  cp -v "$TARGET_SO" pkg/usr/lib/libvulkan_wrapper.so
  
  echo "-> Inyectando SONAME interno prioritario mediante patchelf..."
  patchelf --set-soname libvulkan_wrapper.so pkg/usr/lib/libvulkan_wrapper.so
  strip --strip-unneeded pkg/usr/lib/libvulkan_wrapper.so
else
  echo "🚨 ERROR CRÍTICO: No se localizó ningún binario Vulkan parcial en '$BUILD_DIR'."
  echo "-> Listando contenido de la carpeta de salida para diagnóstico de emergencia:"
  ls -R "$BUILD_DIR/src/panfrost/" 2>/dev/null || ls -R "$BUILD_DIR" | head -n 30
  exit 1
fi

echo '{"ICD":{"api_version":"1.4.352","library_arch":"64","library_path":"libvulkan_wrapper.so"},"file_format_version":"1.0.1"}' > pkg/usr/share/vulkan/icd.d/wrapper_icd.aarch64.json
echo '{"ICD":{"api_version":"1.4.352","library_arch":"32","library_path":"libvulkan_wrapper.so"},"file_format_version":"1.0.1"}' > pkg/usr/share/vulkan/icd.d/wrapper_icd.arm.json
echo '{"env":{"PAN_I_WANT_A_BROKEN_VULKAN_DRIVER":"1","MESA_VK_IGNORE_CONFORMANCE_WARNING":"1","PANVK_DEBUG":"sync","MESA_VK_FORCE_BLIT":"1","MESA_LOADER_DRIVER_OVERRIDE":"panfrost","GALLIUM_DRIVER":"panfrost"}}' > pkg/usr/share/vulkan/settings.d/wrapper_settings.json

echo "msf:315508" > pkg/usr/version.txt
chmod -R 755 pkg/ && chmod 644 pkg/usr/lib/libvulkan_wrapper.so pkg/usr/share/vulkan/icd.d/*.json pkg/usr/share/vulkan/settings.d/*.json pkg/usr/version.txt

echo "-> Comprimiendo el contenedor final en wrapper.tzst..."
tar -I 'zstd -19 -T0' -cf wrapper.tzst -C pkg usr
echo "-> ¡PROCESO COMPLETADO CON ÉXITO ABSOLUTO!"
