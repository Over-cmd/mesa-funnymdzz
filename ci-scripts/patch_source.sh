#!/bin/bash
set -e

echo "-> Buscando panvk_device.c..."
PANVK_DEVICE=$(find src/ -name "*device.c" | head -n 1)
if [ -n "$PANVK_DEVICE" ] && [ -f "$PANVK_DEVICE" ]; then
  echo "-> Aplicando bypass de inicialización de instancia en código C..."
  sed -i 's/\r$//' "$PANVK_DEVICE"
  sed -i 's/instance->vk.enabled_extensions.KHR_get_physical_device_properties2/true/g' "$PANVK_DEVICE" 2>/dev/null || true
  sed -i 's/return vk_error(instance, VK_ERROR_INCOMPATIBLE_DRIVER);/return VK_SUCCESS;/g' "$PANVK_DEVICE" 2>/dev/null || true
  echo "-> Parche de vkCreateInstance completado con éxito."
else
  echo "ADVERTENCIA: No se encontró panvk_device.c para parchear."
fi
