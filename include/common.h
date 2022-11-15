#ifndef COMMON_H
#define COMMON_H

typedef signed char s8;
typedef signed short s16;
typedef signed int s32;
typedef signed long long s64;
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;

extern void* malloc(s32 length, s32 pool);

extern u32 osMemSize;

extern void* D_80078F70[3];
extern void* D_80078F80;
extern void* D_80078F84;
extern void* D_80078F88;

#endif

