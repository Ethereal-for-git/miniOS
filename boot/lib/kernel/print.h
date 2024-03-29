#ifndef __LIB_KERNEL_PRINT_H    //防止头文件被重复包含
#define __LIB_KERNEL_PRINT_H    //以print.h所在路径定义了这个宏，以该宏来判断是否重复包含
#include "stdint.h"

void put_char(uint8_t char_asci);
void put_str(char* message);
void put_int(uint32_t num);     //以16进制打印
void set_cursor(uint32_t cursor_pos);

#endif