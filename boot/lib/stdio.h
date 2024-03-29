#ifndef __LIB_STDIO_H
#define __LIB_STDIO_H
#include "stdint.h"

#define NULL ((void*)0)
// #define NULL 0
typedef char* va_list;
//函数声明

/*将参数ap按照格式format输出到字符串str，并返回替换后str长度*/
uint32_t vsprintf(char* str,const char* format,va_list ap);
/*格式化输出字符串format*/
uint32_t printf(const char* format,...);
/*同printf，不同的地方是字符串不是写到终端，而是写到buf中*/
uint32_t sprintf(char* buf,const char* format,...);

#endif