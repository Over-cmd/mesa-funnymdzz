#!/bin/bash
set -e

BUILD_DIR="build"
rm -rf pkg && mkdir -p pkg/usr/lib pkg/usr/share/vulkan/icd.d pkg/usr/share/vulkan/settings.d

echo "-> Liberando los permisos del volumen de Docker..."
sudo chmod -R 777 "$BUILD_DIR" 2>/dev/null || true

echo "-> Buscando el binario generado por Docker..."
# Captura tanto libvulkan_wrapper.so como libvulkan_panfrost.so en cualquier subcarpeta interna
TARGET_SO=$(find "$BUILD_DIR" -type f -name "libvulkan_wrapper.so" -o -name "libvulkan_panfrost.so" | head -n 1)

if [ -n "$TARGET_SO" ] && [ -f "$TARGET_SO" ]; then
  echo "-> ¡Librería localizada con éxito en: $TARGET_SO!"
  echo "-> Realizando mutación y empaquetado para Winlator..."
  cp -v "$TARGET_SO" pkg/usr/lib/libvulkan_wrapper.so
  
  echo "-> Modificando la cabecera SONAME interna mediante patchelf..."
  patchelf --set-soname libvulkan_wrapper.so pkg/usr/lib/libvulkan_wrapper.so
  strip --strip-unneeded pkg/usr/lib/libvulkan_wrapper.so
else
  echo "🚨 ERROR CRÍTICO: No se encontró ningún binario gráfico parcial en el directorio de construcción."
  echo "-> Listando árbol completo de la carpeta src para diagnóstico profundo:"
  find "$BUILD_DIR" -name "*.so" 2>/dev/null || true
  ls -R "$BUILD_DIR/src" 2>/dev/null | head -n 40
  exit 1
fi

echo '{"ICD":{"api_version":"1.4.352","library_arch":"64","library_path":"libvulkan_wrapper.so"},"file_format_version":"1.0.1"}' > pkg/usr/share/vulkan/icd.d/wrapper_icd.aarch64.json
echo '{"ICD":{"api_version":"1.4.352","library_arch":"32","library_path":"libvulkan_wrapper.so"},"file_format_version":"1.0.1"}' > pkg/usr/share/vulkan/icd.d/wrapper_icd.arm.json
echo '{"env":{"PAN_I_WANT_A_BROKEN_VULKAN_DRIVER":"1","MESA_VK_IGNORE_CONFORMANCE_WARNING":"1","PANVK_DEBUG":"sync","MESA_VK_FORCE_BLIT":"1","MESA_LOADER_DRIVER_OVERRIDE":"panfrost","GALLIUM_DRIVER":"panfrost"}}' > pkg/usr/share/vulkan/settings.d/wrapper_settings.json

echo "msf:315508" > pkg/usr/version.txt
chmod -R 755 pkg/ && chmod 644 pkg/usr/lib/libvulkan_wrapper.so pkg/usr/share/vulkan/icd.d/*.json pkg/usr/share/vulkan/settings.d/*.json pkg/usr/version.txt

echo "-> Comprimiendo el contenedor final en wrapper.tzst..."
tar -I 'zstd -19 -T0' -cf wrapper.tzst -C pkg usr
echo "-> ¡MUTACIÓN Y EMPAQUETADO COMPLETADOS CON ÉXITO TOTAL!"
