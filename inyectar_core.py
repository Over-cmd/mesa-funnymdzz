#!/usr/bin/env python3
import os

target_file = "src/vulkan/runtime/vk_instance.c"

if os.path.exists(target_file):
    print("-> [Python] Limpiando el buffer y restaurando el core original de Mesa...")
    os.system(f"git checkout -- {target_file}")
    
    with open(target_file, "r") as f:
        code = f.read()

    # Definimos el bloque limpio de tus variables de entorno oficiales para tu GPU Mali G52
    payload = """
    setenv("PAN_MESA_DEBUG", "kbase,sync", 1);
    setenv("PAN_EXPERIMENTAL_KBASE_GL", "1", 1);
    setenv("MESA_LOADER_DRIVER_OVERRIDE", "panfrost", 1);
    setenv("MESA_VK_IGNORE_CONFORMANCE_WARNING", "1", 1);
    setenv("MESA_VK_WSI_PRESENT_MODE", "immediate", 1);
    setenv("MESA_VK_WSI_DEBUG", "always", 1);
"""

    # Punto de anclaje universal exacto en el arranque de la creacion de la instancia
    target_str = "vk_instance_create(const struct vk_instance_definition *vulkan_definition,\n                   const struct vk_init_struct *init,\n                   const VkAllocationCallbacks *alloc,\n                   struct vk_instance **instance_out)"

    if target_str in code:
        # Buscamos la firma exacta y le metemos el payload justo al inicio del cuerpo de la funcion
        # de forma que el archivo conserve el 100% de sus llaves de fabrica intactas
        old_block = target_str + "\n{"
        new_block = target_str + "\n{" + payload
        
        patched_code = code.replace(old_block, new_block)
        
        with open(target_file, "w") as f:
            f.write(patched_code)
        print("-> [Python] CIRUGÍA MOLECULAR SINROTURA COMPLETADA AL 100%.")
    else:
        # Fallback de emergencia si el formateador del repositorio difiere en saltos de linea
        print("-> [Python] Buscando firma simplificada...")
        if "vk_instance_create(" in code:
            parts = code.split("vk_instance_create(", 1)
            # Buscamos la primera llave de apertura de la funcion de forma segura
            sub_parts = parts[1].split("{", 1)
            patched_code = parts[0] + "vk_instance_create(" + sub_parts[0] + "{\n" + payload + sub_parts[1]
            with open(target_file, "w") as f:
                f.write(patched_code)
            print("-> [Python] Inyección de contingencia estructurada aplicada con éxito.")
        else:
            print("-> [Python] ERROR CRÍTICO: No se localizo la funcion en el runtime.")
else:
    print("-> [Python] ERROR: El archivo vk_instance.c no existe en la ruta.")
