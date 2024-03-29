#ifndef __DEVICE_KEYBOARD_H
#define __DEVICE_KEYBOARD_H
#include "stdint.h"

extern struct ioqueue kbd_buf;
//函数声明
/*键盘初始化*/
void keyboard_init(void);
#endif