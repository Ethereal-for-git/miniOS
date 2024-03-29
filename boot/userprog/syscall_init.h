#ifndef __USERPROG_SYSCALL_INIT_H
#define __USERPROG_SYSCALL_INIT_H
#include "stdint.h"

//函数声明
//返回当前任务的pid
uint32_t sys_getpid(void);
/*打印字符串str（未实现文件系统前的版本）*/
uint32_t sys_write(char* str);
//初始化系统调用
void syscall_init(void);



#endif