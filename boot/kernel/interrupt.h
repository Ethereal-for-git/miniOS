#ifndef __KERNEL_INTERRUPT_H
#define __KERNEL_INTERRUPT_H
#include "stdint.h"
typedef void* intr_handler;

/*定义中断的两种状态：
INTR_OFF值为0，表示关中断
INTR_ON 值为1，表示开中断*/
enum intr_status{
	INTR_OFF = 0,
	INTR_ON = 1
};
//枚举常量在 C 语言中被赋予默认的整数值，按照声明的顺序从 0 开始递增。因此，在这个例子中，INTR_OFF 的值为 0，INTR_ON 的值为 1。也可以显式地为枚举常量指定特定的值。

// enum intr_status intr_get_status(void);
// enum intr_status intr_set_status(enum intr_status);
// enum intr_status intr_enable(void);
// enum intr_status intr_disable(void);

/*完成所有有关中断的初始化工作*/
void idt_init(void);

/*开中断，并返回开中断前的状态*/
enum intr_status intr_enable(void);

/*关中断，并返回关中断前的状态*/
enum intr_status intr_disable(void);

/*将中断状态设置为status*/
enum intr_status intr_set_status(enum intr_status status);

/*获取当前中断状态*/
enum intr_status intr_get_status(void);

/*在中断处理程序数组第vector_no个元素中注册安装中断处理程序function*/
void register_handler(uint8_t vector_no,intr_handler function);
#endif