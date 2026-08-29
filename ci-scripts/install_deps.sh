#!/bin/bash
set -e

echo "-> Instalando empaquetadores y herramientas base..."
sudo apt-get update
sudo apt-get install -y zstd patchelf

echo "-> Estructurando el arbol de dependencias logicas locales..."
mkdir -p shutils/system shutils/lib shutils/log shutils/hardware shutils/sync

echo "-> Copiando las carpetas de cabeceras de cutils..."
if [ -d "tmp_libcutils/include/cutils" ]; then
  cp -r tmp_libcutils/include/cutils shutils/
elif [ -d "tmp_libcutils/include_vndk/cutils" ]; then
  cp -r tmp_libcutils/include_vndk/cutils shutils/
fi

echo "-> Copiando cabeceras HAL de LineageOS al entorno global de Shims..."
cp -rf tmp_libhardware/include/hardware/* shutils/hardware/ 2>/dev/null || true
cp -rf tmp_libhardware/include_all/hardware/* shutils/hardware/ 2>/dev/null || true

# Inyección de las macros de registro
cat << 'EOF' > shutils/log/log.h
#ifndef ANDROID_LOG_H
#define ANDROID_LOG_H
#include <stdarg.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef enum android_LogPriority {
    ANDROID_LOG_UNKNOWN = 0, ANDROID_LOG_DEFAULT, ANDROID_LOG_VERBOSE,
    ANDROID_LOG_DEBUG, ANDROID_LOG_INFO, ANDROID_LOG_WARN,
    ANDROID_LOG_ERROR, ANDROID_LOG_FATAL, ANDROID_LOG_SILENT
} android_LogPriority;
int __android_log_print(int prio, const char* tag, const char* fmt, ...) __attribute__((format(printf, 3, 4)));
int __android_log_vprint(int prio, const char* tag, const char* fmt, va_list ap);
void __android_log_assert(const char* cond, const char* tag, const char* fmt, ...) __attribute__((noreturn, format(printf, 3, 4)));
#define ALOGD(...) ((void)0)
#define ALOGI(...) ((void)0)
#define ALOGW(...) ((void)0)
#define ALOGE(...) ((void)0)
#define ALOGV(...) ((void)0)
#define ALOGE_IF(...) ((void)0)
#ifdef __cplusplus
}
#endif
#endif
EOF

# Inyección de las firmas de sincronización
cat << 'EOF' > shutils/sync/sync.h
#ifndef ANDROID_SYNC_H
#define ANDROID_SYNC_H
#ifdef __cplusplus
extern "C" {
#endif
int sync_wait(int fd, int timeout);
int sync_merge(const char *name, int fd1, int fd2);
#ifdef __cplusplus
}
#endif
#endif
EOF

cat << 'EOF' > shutils/system/graphics.h
#ifndef SYSTEM_GRAPHICS_H_
#define SYSTEM_GRAPHICS_H_
#include <stdint.h>
#endif
EOF

echo "-> Compilando native_handle.cpp original de Android..."
g++ -c -fPIC tmp_libcutils/native_handle.cpp -o tmp_libcutils/native_handle.o -Ishutils
ar rcs shutils/lib/libcutils.a tmp_libcutils/native_handle.o

echo "-> Creando cabecera de inyeccion forzada para hardware.c..."
cat << 'EOF' > shutils/force_includes.h
#ifndef FORCE_INCLUDES_H
#define FORCE_INCLUDES_H
#define _GNU_SOURCE
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <limits.h>
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif
#endif
EOF

echo "-> Compilando hardware.c nativo de LineageOS con auto-inclusion..."
gcc -c -fPIC -std=c11 -include shutils/force_includes.h tmp_libhardware/hardware.c -o tmp_libhardware/hardware.o -Ishutils -Itmp_libhardware/include -I.
ar rcs shutils/lib/libhardware.a tmp_libhardware/hardware.o

echo "-> Compilando stub real de liblog.a..."
cat << 'EOF' > shutils/stub_log.c
#include "log/log.h"
int __android_log_print(int prio, const char* tag, const char* fmt, ...) { return 0; }
int __android_log_vprint(int prio, const char* tag, const char* fmt, va_list ap) { return 0; }
void __android_log_assert(const char* cond, const char* tag, const char* fmt, ...) { while(1); }
EOF
gcc -c -fPIC shutils/stub_log.c -o shutils/stub_log.o -Ishutils
ar rcs shutils/lib/liblog.a shutils/stub_log.o

echo "-> Compilando stub real de libsync.a..."
cat << 'EOF' > shutils/stub_sync.c
#include "sync/sync.h"
int sync_wait(int fd, int timeout) { return 0; }
int sync_merge(const char *name, int fd1, int fd2) { return -1; }
EOF
gcc -c -fPIC shutils/stub_sync.c -o shutils/stub_sync.o -Ishutils
ar rcs shutils/lib/libsync.a shutils/stub_sync.o

# Generamos manifiestos de pkg-config
cat << 'EOF' > shutils/cutils.pc
Name: cutils
Description: Standalone Android cutils library for Mesa
Version: 1.0.0
Cflags: -I/workspace/shutils
Libs: -L/workspace/shutils/lib -lcutils
EOF

cat << 'EOF' > shutils/hardware.pc
Name: hardware
Description: LineageOS Android hardware HAL library for Mesa
Version: 1.0.0
Cflags: -I/workspace/shutils
Libs: -L/workspace/shutils/lib -lhardware
EOF

cat << 'EOF' > shutils/log.pc
Name: log
Description: Original Android logging library for Mesa
Version: 1.0.0
Cflags: -I/workspace/shutils
Libs: -L/workspace/shutils/lib -llog
EOF

cat << 'EOF' > shutils/sync.pc
Name: sync
Description: Android sync fences library for Mesa compilation
Version: 1.0.0
Cflags: -I/workspace/shutils
Libs: -L/workspace/shutils/lib -lsync
EOF

echo "-> Verificando entorno unificado completo de Shims de Android:"
ls -R shutils/
rm -rf tmp_libcutils tmp_libhardware
