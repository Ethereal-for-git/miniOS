#include "thread.h"
#include "stdint.h"
#include "../string.h"
#include "global.h"
#include "memory.h"
#include "interrupt.h"
#include "list.h"
#include "debug.h"
#include "print.h"
#include "process.h"
#include "sync.h"

#define PG_SIZE 4096

// struct task_struct* main_thread;        //主线程PCB
// struct list thread_ready_list;          //就绪队列
// struct list thread_all_list;            //所有任务队列
static struct list_elem* thread_tag;    //用于保存队列中的线程结点
struct lock pid_lock;

extern void switch_to(struct task_struct* cur,struct task_struct* next);

/*获取当前线程的pcb指针*/
struct task_struct* running_thread(void){
    uint32_t esp;
    asm("mov %%esp,%0" : "=g"(esp));      //将当前的栈指针（ESP）的值存储到变量esp中。
    return (struct task_struct*)(esp & 0xfffff000);     //取esp整数部分，即pcb起始地址
}

/*由kernel_thread去执行function(func_arg)*/
static void kernel_thread(thread_func* funcion,void* func_arg){
    intr_enable();      //开中断，避免后面的时钟中断被屏蔽，而无法调度其他线程
    funcion(func_arg);
}

/*分配pid*/
static pid_t allocate_pid(void){
    static pid_t next_pid = 0;
    lock_acquire(&pid_lock);
    next_pid++;
    lock_release(&pid_lock);
    return next_pid;
}

/*初始化线程栈thread_stack，将待执行的函数和参数放到thread_stack中相应的位置*/
void thread_create(struct task_struct* pthread,thread_func function,void* func_arg){
    /*先预留中断使用栈的空间*/
    pthread->self_kstack -= sizeof(struct intr_stack);

    /*再预留出线程栈空间*/
    pthread->self_kstack -= sizeof(struct thread_stack);
    
    struct thread_stack* kthread_stack = (struct thread_stack*)pthread->self_kstack;    //线程栈指针
    kthread_stack->eip = kernel_thread;
    kthread_stack->function = function;
    kthread_stack->func_arg = func_arg;
    kthread_stack->ebp = kthread_stack->ebx = kthread_stack->edi = kthread_stack->esi = 0;  //寄存器初始化为0
}

/*线程初始化*/
void init_thread(struct task_struct* pthread,char* name,int prio){
    memset(pthread,0,sizeof(*pthread));
    pthread->pid = allocate_pid();
    strcpy(pthread->name,name);
    if(pthread == main_thread)
        pthread->status = TASK_RUNNING;
    else
        pthread->status = TASK_READY;

    /*self_kstack是线程自己在内核态下使用的栈顶地址*/
    pthread->self_kstack = (uint32_t*)((uint32_t)pthread + PG_SIZE);
    pthread->priority = prio;
    pthread->ticks = prio;
    pthread->elapsed_ticks = 0;
    pthread->pgdir = NULL;
    pthread->stack_magic = 0x19870916;
}

/*创建一优先级为prio，线程名为name，线程所执行函数为function(func_arg)的线程*/
struct task_struct* thread_start(char* name,int prio,thread_func function,void* func_arg){
    /*pcb都位于内核空间，包括用户进程的pcb也在内核空间*/
    struct task_struct* thread = get_kernel_pages(1);
    init_thread(thread,name,prio);
    thread_create(thread,function,func_arg);
    //确保之前不在就绪队列中
    ASSERT(!elem_find(&thread_ready_list,&thread->general_tag));
    //加入就绪队列
    list_append(&thread_ready_list,&thread->general_tag);
    //确保之前不在队列中
    ASSERT(!elem_find(&thread_all_list,&thread->all_list_tag));
    //加入全部线程队列
    list_append(&thread_all_list,&thread->all_list_tag);
    return thread;
}

/*将kernel中的main函数完善为主线程*/
static void make_main_thread(void){
    /*因为main线程早已在运行，咱们在loader.S中进入内核时的mov esp,0xc009f000，就是为其预留pcb的。
    因为pcb的地址为0xc009e000，不需要通过get_kernel_page另外分配一页*/
    main_thread = running_thread();
    init_thread(main_thread,"main",31);

    /*main函数是当前线程，当前线程不在thread_ready_list中，所以只将其加在thread_all_list中*/
    ASSERT(!elem_find(&thread_all_list,&main_thread->all_list_tag));
    list_append(&thread_all_list,&main_thread->all_list_tag);
}

/*实现任务调度*/
void schedule(){
    ASSERT(intr_get_status() == INTR_OFF);
    struct task_struct* cur = running_thread();
    if(cur->status == TASK_RUNNING){
        //若此线程只是cpu时间片到了，将其加入就绪队列队尾
        ASSERT(!elem_find(&thread_ready_list,&cur->general_tag));
        list_append(&thread_ready_list,&cur->general_tag);
        cur->ticks = cur->priority;
        cur->status = TASK_READY;
    }else{
        //若此线程需要某事件发生后才能继续上cpu运行，不需要将其放入队列中，因为当前线程不在就绪队列中
    }

    ASSERT(!list_empty(&thread_ready_list));
    thread_tag = NULL;
    thread_tag = list_pop(&thread_ready_list);
    struct task_struct* next = elem2entry(struct task_struct,general_tag,thread_tag);   //将thread_tag转化为线程（链表）
    next->status = TASK_RUNNING;
    /*激活任务页表等*/
    process_activate(next);
    switch_to(cur,next);
}

/*初始化线程环境*/
void thread_init(void){
    put_str("thread_init start\n");
    list_init(&thread_ready_list);
    list_init(&thread_all_list);
    lock_init(&pid_lock);
    /*将当前main函数创建为线程*/
    make_main_thread();
    put_str("thread_init done\n");
}

/*当前线程将自己阻塞，标志其状态为stat*/
void thread_block(enum task_status stat){
    /*stat取值为TASK_BLOCKED,TASK_WAITING,TASK_HANGING，只有这三种状态才不会被调度*/
    ASSERT(((stat == TASK_BLOCKED) || (stat == TASK_WAITING) || (stat == TASK_HANGING)));
    enum intr_status old_status = intr_disable();
    struct task_struct* cur_thread = running_thread();
    cur_thread->status = stat;
    schedule();     //将当前线程换下CPU
    intr_set_status(old_status);    //待当前线程被解除阻塞后才能继续运行intr_set_status
}

/*将线程pthread接触阻塞*/
void thread_unblock(struct task_struct* pthread){
    enum intr_status old_status = intr_disable();
    ASSERT(((pthread->status == TASK_BLOCKED) || (pthread->status == TASK_WAITING) || (pthread->status == TASK_HANGING)));
    if(pthread->status != TASK_READY){
        ASSERT(!elem_find(&thread_ready_list,&pthread->general_tag));
        if(elem_find(&thread_ready_list,&pthread->general_tag)){
            PANIC("thread_unblock:blocked thread in ready_list\n");
        }
        list_push(&thread_ready_list,&pthread->general_tag);
        pthread->status = TASK_READY;
    }
    intr_set_status(old_status);
}