#!/usr/bin/env python3
import os

target_file = "src/vulkan/runtime/vk_instance.c"

if os.path.exists(target_file):
    print("-> [Python] Limpiando el buffer y restaurando el core original de Mesa...")
    os.system(f"git checkout -- {target_file}")
    
    with open(target_file, "r") as f:
        code = f.read()

    # Definimos el bloque con las 6 variables oficiales para tu GPU Mali G52 sin Root
    payload = """    setenv("PAN_MESA_DEBUG", "kbase,sync", 1);
    setenv("PAN_EXPERIMENTAL_KBASE_GL", "1", 1);
    setenv("MESA_LOADER_DRIVER_OVERRIDE", "panfrost", 1);
    setenv("MESA_VK_IGNORE_CONFORMANCE_WARNING", "1", 1);
    setenv("MESA_VK_WSI_PRESENT_MODE", "immediate", 1);
    setenv("MESA_VK_WSI_DEBUG", "always", 1);"""

    # Punto de anclaje universal indestructible en Mesa: la creacion de la instancia de Vulkan
    target_str = "vk_instance_create(const struct vk_instance_definition *vulkan_definition,"
    
    if target_str in code:
        # Buscamos la apertura de la funcion e inyectamos tu arsenal bionico de forma legal en C
        parts = code.split(target_str, 1)
        sub_parts = parts[1].split("{", 1)
        
        patched_code = parts[0] + target_str + sub_parts[0] + "{\n" + payload + "\n" + sub_parts[1]
        
        with open(target_file, "w") as f:
            f.write(patched_code)
        print("-> [Python] CIRUGÍA MOLECULAR EN VK_INSTANCE_CREATE COMPLETADA AL 100%.")
    else:
        print("-> [Python] ERROR: No se localizo el punto de anclaje universal en el runtime.")
else:
    print("-> [Python] ERROR CRÍTICO: El archivo vk_instance.c no existe en el arbol.")
