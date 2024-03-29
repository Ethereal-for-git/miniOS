#ifndef __LIB_STRING_H
#define __LIB_STRING_H
#include "stdint.h"
// #define NULL 0
#define NULL ((void*)0)

void memset(void* dst_,uint8_t value,uint32_t size);
void memcpy(void* dst_,const void* src_,uint32_t size);
int memcmp(const char* a_,const char* b_,uint32_t size);
//[做了修改]
char* strcpy(char* dst_,const char* src_);
//[做了修改]
uint32_t strlen(const char* str);
int8_t strcmp(const char* a,const char* b);
char* strchr(const char* str,const uint8_t ch);
char* strtchr(const char* str,const uint8_t ch);
char* strcat(char* dst_,const char* src_);
uint32_t strchrs(const char* str,uint8_t ch);

#endif