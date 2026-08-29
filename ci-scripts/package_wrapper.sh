#!/bin/bash
set -e

BUILD_DIR="build"
rm -rf pkg && mkdir -p pkg/usr/lib pkg/usr/share/vulkan/icd.d pkg/usr/share/vulkan/settings.d

echo "-> Liberando los permisos del volumen de Docker..."
sudo chmod -R 777 "$BUILD_DIR" 2>/dev/null || true

echo "-> Buscando el binario original libvulkan_panfrost.so generado por Docker..."
# Capturamos el archivo físico original de Mesa Panfrost
TARGET_SO=$(find "$BUILD_DIR" -type f -name "libvulkan_panfrost.so" | head -n 1)

if [ -n "$TARGET_SO" ] && [ -f "$TARGET_SO" ]; then
  echo "-> ¡Librería original localizada con éxito en: $TARGET_SO!"
  echo "-> Realizando mutación externa a libvulkan_wrapper.so..."
  # Lo copiamos a la estructura final cambiando el nombre al formato wrapper
  cp -v "$TARGET_SO" pkg/usr/lib/libvulkan_wrapper.so
  
  echo "-> Modificando la cabecera SONAME interna mediante patchelf para Winlator..."
  # 🟢 ESTE ES EL TRUCO: Cambiamos la identidad interna del binario para que no se rompa al cargar
  patchelf --set-soname libvulkan_wrapper.so pkg/usr/lib/libvulkan_wrapper.so
  
  echo "-> Limpiando símbolos de depuración redundantes..."
  strip --strip-unneeded pkg/usr/lib/libvulkan_wrapper.so
else
  echo "🚨 ERROR CRÍTICO: No se encontró el binario 'libvulkan_panfrost.so' en el directorio de construcción."
  echo "-> Estructura actual de la carpeta para diagnóstico:"
  ls -R "$BUILD_DIR" | head -n 40
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
