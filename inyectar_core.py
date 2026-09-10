#!/usr/bin/env python3
import os

target_file = "src/vulkan/runtime/vk_instance.c"

if os.path.exists(target_file):
    print("-> [Python] Limpiando el buffer y restaurando el core original...")
    os.system(f"git checkout -- {target_file}")
    
    with open(target_file, "r") as f:
        code = f.read()

    # Definimos el bloque inmutable exacto de tus variables para la GPU Mali G52 sin Root
    payload = """setenv("PAN_MESA_DEBUG", "kbase,sync", 1);
    setenv("PAN_EXPERIMENTAL_KBASE_GL", "1", 1);
    setenv("MESA_LOADER_DRIVER_OVERRIDE", "panfrost", 1);
    setenv("MESA_VK_IGNORE_CONFORMANCE_WARNING", "1", 1);
    setenv("MESA_VK_WSI_PRESENT_MODE", "immediate", 1);
    setenv("MESA_VK_WSI_DEBUG", "always", 1);"""

    # Localizamos la cabecera oficial de la función e insertamos el bloque de forma 100% legal en C
    target_str = "vk_instance_init(struct vk_instance *instance,\n                 const struct vk_init_struct *init)\n{"
    
    if target_str in code:
        patched = code.replace(target_str, target_str + "\n    " + payload)
        with open(target_file, "w") as f:
            f.write(patched)
        print("-> [Python] CIRUGÍA MOLECULAR COMPLETADA CON ÉXITO AL 100%.")
    else:
        # Fallback de seguridad por si varían levemente los espacios del formateador de Mesa
        fallback_str = "vk_instance_init("
        patched = code.replace(fallback_str, payload + "\n//\nvk_instance_init(")
        with open(target_file, "w") as f:
            f.write(patched)
        print("-> [Python] Inyección de contingencia aplicada en la cabecera.")
else:
    print("-> [Python] ERROR CRÍTICO: No se encontró el archivo vk_instance.c")
