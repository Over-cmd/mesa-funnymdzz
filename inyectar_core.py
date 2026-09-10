#!/usr/bin/env python3
import os

target_file = "src/vulkan/runtime/vk_instance.c"

if os.path.exists(target_file):
    print("-> [Python] Limpiando buffer y restaurando el core original de Mesa...")
    os.system(f"git checkout -- {target_file}")
    
    with open(target_file, "r") as f:
        code = f.read()

    # Definimos el bloque con triples comillas simples para que Python escriba las comillas de C exactas
    payload = """    setenv("PAN_MESA_DEBUG", "kbase,sync", 1);
    setenv("PAN_EXPERIMENTAL_KBASE_GL", "1", 1);
    setenv("MESA_LOADER_DRIVER_OVERRIDE", "panfrost", 1);
    setenv("MESA_VK_IGNORE_CONFORMANCE_WARNING", "1", 1);
    setenv("MESA_VK_WSI_PRESENT_MODE", "immediate", 1);
    setenv("MESA_VK_WSI_DEBUG", "always", 1);"""

    # Buscamos el punto de entrada exacto de la funcion vk_instance_init en Mesa Puro
    target_str = "vk_instance_init(struct vk_instance *instance,\n                 const struct vk_init_struct *init)\n{"
    
    if target_str in code:
        patched = code.replace(target_str, target_str + "\n" + payload)
        with open(target_file, "w") as f:
            f.write(patched)
        print("-> [Python] CIRUGÍA COMPLETADA CON ÉXITO ABSOLUTO AL 100%.")
    else:
        # Fallback por si el formateador de tu rama de Mesa tiene espacios sutilmente diferentes
        parts = code.split("vk_instance_init(", 1)
        if len(parts) > 1:
            patched = parts[0] + "vk_instance_init(\n" + payload + "\n" + parts[1]
            with open(target_file, "w") as f:
                f.write(patched)
            print("-> [Python] Inyección de contingencia aplicada en la cabecera.")
        else:
            print("-> [Python] ERROR: No se pudo localizar la funcion de destino.")
else:
    print("-> [Python] ERROR CRÍTICO: El archivo vk_instance.c no existe en la ruta.")
