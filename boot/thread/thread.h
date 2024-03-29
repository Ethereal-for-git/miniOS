#ifndef __THREAD_THREAD_H
#define __THREAD_THREAD_H
#include "stdint.h"
#include "list.h"
#include "../kernel/memory.h"

/*自定义通用函数类型，它将在很多线程函数中作为形参类型*/
typedef void thread_func(void*);
typedef int16_t pid_t;

/*进程或线程的状态*/
enum task_status{
    TASK_RUNNING,
    TASK_READY,
    TASK_BLOCKED,
    TASK_WAITING,
    TASK_HANGING,
    TASK_DIED
};

/*中断栈intr_stack
用于中断发生时保护程序上下文环境：
进程/线程被外部中断/软中断打断时，会按照此结构压入上下文
寄存器，intr_exit中的出栈操作是此结构的逆操作
此栈在线程自己的内核栈中位置固定，所在页的最顶端
*/
struct intr_stack{
    uint32_t vec_no;    //kernel.S宏VECTOR中push %1压入的中断号
    uint32_t edi;
    uint32_t esi;
    uint32_t ebp;
    uint32_t esp_dummy; //虽然pushad把esp也压入了，但esp是不断变化的，所以会被popad忽略
    uint32_t ebx;
    uint32_t edx;
    uint32_t ecx;
    uint32_t eax;
    uint32_t gs;
    uint32_t fs;
    uint32_t es;
    uint32_t ds;

    /*下面由CPU从低特权级进入高特权级时压入*/
    uint32_t err_code;  //err_code会被压入在eip之后
    void (*eip) (void);
    uint32_t cs;
    uint32_t eflags;
    void* esp;
    uint32_t ss;
};

/*线程栈thread_stack
线程自己的栈，用于存储线程中待执行的函数
此结构在线程自己的内核栈中位置不固定
仅用在switch_to时保存线程环境
实际位置取决于实际情况。
*/
struct thread_stack{
    uint32_t ebp;
    uint32_t ebx;
    uint32_t edi;
    uint32_t esi;

    /*线程第一次执行时，eip指向待调用函数kernel_thread，
    其他时候，eip指向switch_to的返回地址*/
    void (*eip) (thread_func* func,void* func_arg);

    /*以下仅供第一次被调度上CPU时使用*/
    /*参数unused_ret只为占位置充数为返回地址*/
    void (*unused_retaddr);     //占位符，基线，表示返回地址
    thread_func* function;      //由kernel_thread所调用的函数名
    void* func_arg;             //由kernel_thread所调用的函数所需的参数
};

/*进程或线程的pcb，程序控制块*/
struct task_struct{
    uint32_t* self_kstack;      //各内核线程都用自己当前的内核栈的栈顶
    pid_t pid;
    enum task_status status;
    uint8_t priority;           //线程优先级
    char name[16];
    uint8_t ticks;              //每次在处理器上的嘀咕数
    uint32_t elapsed_ticks;     //此任务自上CPU运行至今用了多少CPU嘀咕数，也就是任务运行了多久
    struct list_elem general_tag;                   //用于线程在一般队列中的节点
    struct list_elem all_list_tag;                  //用于线程队列thread_all_list中的结点
    uint32_t* pgdir;            //进程自己页表的虚拟地址，如果是线程则为NULL
    struct virtual_addr userprog_vaddr;             //用户进程的虚拟地址
    struct mem_block_desc u_block_desc[DESC_CNT];   //用户进程的内存块描述符
    uint32_t stack_magic;       //栈的边界标记，用于检测栈的溢出
};

struct task_struct* main_thread;        //主线程PCB
struct list thread_ready_list;          //就绪队列
struct list thread_all_list;            //所有任务队列
// static struct list_elem* thread_tag;    //用于保存队列中的线程结点

/*获取当前线程的pcb指针*/
struct task_struct* running_thread(void);
/*初始化线程栈thread_stack，将待执行的函数和参数放到thread_stack中相应的位置*/
void thread_create(struct task_struct* pthread,thread_func function,void* func_arg);

/*线程初始化*/
void init_thread(struct task_struct* pthread,char* name,int prio);

/*创建一优先级为prio，线程名为name，线程所执行函数为function(func_arg)的线程*/
struct task_struct* thread_start(char* name,int prio,thread_func function,void* func_arg);

/*将kernel中的main函数完善为主线程*/
// static void make_main_thread(void);

/*实现任务调度*/
void schedule(void);

/*初始化线程环境*/
void thread_init(void);

/*当前线程将自己阻塞，标志其状态为stat*/
void thread_block(enum task_status stat);

/*将线程pthread接触阻塞*/
void thread_unblock(struct task_struct* pthread);
#endif