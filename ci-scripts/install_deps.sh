#!/bin/bash
set -e
echo "-> Dependencias de Android anuladas en caliente mediante bypass en el workflow."
echo "-> Preparando el entorno para el contenedor Docker..."
sudo apt-get update
sudo apt-get install -y zstd patchelf
