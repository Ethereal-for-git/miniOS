#ifndef __USERPROG_PROCESS_H
#define __USERPROG_PROCESS_H
#include "stdint.h"

#define USER_STACK3_VADDR (0xc0000000 - 0x1000)
#define USER_VADDR_START 0x8048000  //Linux用户程序的入口地址
#define default_prio 31 // 默认优先级
#define NULL ((void*)0)

//函数声明
/*构建用户进程filename_的初始上下文信息，即struct intr_stack*/
void start_process(void* filename_);

/*激活页表*/
void page_dir_activate(struct task_struct* p_thread);

/*激活线程/进程的页表，更新tss中的esp0为进程的特权级0的栈*/
void process_activate(struct task_struct* p_thread);

/*创建页目录表，将当前页表的表示内核空间的pde复制，成功则返回页目录表的虚拟地址，否则返回-1*/
uint32_t* create_page_dir(void);

/*创建用户进程虚拟地址位图*/
void create_user_vaddr_bitmap(struct task_struct* user_prog);

/*创建用户进程并加入到就绪队列中*/
void process_execute(void* filename,char* name);
#endif