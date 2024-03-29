#include "thread.h"
#include "process.h"
#include "tss.h"
#include "console.h"
#include "../kernel/memory.h"
#include "global.h"
#include "bitmap.h"
#include "interrupt.h"
#include "debug.h"
#include "../string.h"
#include "print.h"

extern void intr_exit(void);

/*构建用户进程filename_的初始上下文信息，即struct intr_stack*/
void start_process(void* filename_){    //filename_表示用户进程的名称，因为用户进程是从文件系统中加载到内存的
    void* function = filename_;
    struct task_struct* cur = running_thread();
    cur->self_kstack += sizeof(struct thread_stack);
    struct intr_stack* proc_stack = (struct intr_stack*)cur->self_kstack;
    proc_stack->edi = proc_stack->esi = proc_stack->ebp = proc_stack->esp_dummy = 0;
    proc_stack->ebx = proc_stack->edx = proc_stack->ecx = proc_stack->eax = 0;
    proc_stack->gs = 0;
    proc_stack->ds = proc_stack->es = proc_stack->fs = SELECTOR_U_DATA;
    proc_stack->eip = function;         //cs:eip是程序入口地址
    proc_stack->cs = SELECTOR_U_CODE;   //cs寄存器赋值为用户级代码段
    proc_stack->eflags = (EFLAGS_IOPL_0 | EFLAGS_MBS | EFLAGS_IF_1);
    proc_stack->esp = (void*)((uint32_t)get_a_page(PF_USER,USER_STACK3_VADDR) + PG_SIZE);   //3特权级下的栈
    proc_stack->ss = SELECTOR_U_DATA;
    asm volatile("movl %0,%%esp;jmp intr_exit" : : "g"(proc_stack) : "memory");     //通过假装从中断返回的方式，使filename_运行
}

/*激活页表*/
void page_dir_activate(struct task_struct* p_thread){
    /*执行此函数时，当前任务可能是线程。
    *因为线程是内核级，所以线程用的是内核的页表。每个用户进程用的是独立的页表。
    *之所以对线程也要重新安装页表，原因是上一次被调度的可能是进程，否则不恢复页表的话，线程就会使用进程的页表了
    */
    uint32_t pagedir_phy_addr = 0x100000;   /*若为内核线程，需要重新填充页表为内核页表：00x10_0000*/
    //默认为内核的页目录物理地址，也就是内核线程所用的页目录表
    if(p_thread->pgdir != NULL){
        pagedir_phy_addr = addr_v2p((uint32_t)p_thread->pgdir);     //判断是线程/进程的方法：进程的pcb中pgdir指向页表的虚拟地址，而线程中无页表所以pgdir = NULL
    }
    /*更新页目录表寄存器cr3，使新页表生效*/
    asm volatile("movl %0,%%cr3" : : "r"(pagedir_phy_addr):"memory");   //将进程/线程的页表/内核页表加载到cr3寄存器中
    //每个进程都有独立的虚拟地址空间，本质上是各个进程都有自己单独的页表。
    //页表是存储在页表寄存器cr3中的，cr3只有一个。在不同进程执行前，我们要在cr3寄存器中为其换上配套的页表，从而实现虚拟地址空间的隔离。
}

/*激活线程/进程的页表，更新tss中的esp0为进程的特权级0的栈*/
void process_activate(struct task_struct* p_thread){
    ASSERT(p_thread != NULL);
    /*激活该进程/线程的页表*/
    page_dir_activate(p_thread);
    /*内核线程特权级本身是0，CPU进入中断时并不会从tss中获取0特权级栈地址，故不需要更新esp0*/
    if(p_thread->pgdir){
        /*更新该进程的esp0，用于此进程被中断时保留上下文*/
        update_tss_esp(p_thread);   //更新tss中的esp0为进程的特权级0栈
        //时钟中断进行进程调度，中断需要用到0特权级的栈
    }
}

/*创建页目录表，将当前页表的表示内核空间的pde复制，成功则返回页目录表的虚拟地址，否则返回-1*/
uint32_t* create_page_dir(void){
    /*用户进程的页表不能让用户直接访问到，所以在内核空间中申请*/
    uint32_t* page_dir_vaddr = get_kernel_pages(1);
    if(page_dir_vaddr == NULL){
        console_put_str("create_page_dir:get_kernel_page failed!");
        return NULL;
    }

    /* 1 先复制页表,将内核的页目录项复制到用户进程使用的页目录表中*/
    /*page_dir_vaddr + 0x300*4是内核页目录的第768项 [0x300是十六进制的768，4是页目录项的大小]*/
    memcpy((uint32_t*)((uint32_t)page_dir_vaddr + 0x300*4),(uint32_t*)(0xfffff000 + 0x300*4),1024);     //dst src size
    //0xfffff000 + 0x300*4表示内核页目录表中第768个页目录项的地址，1024/4=256个页目录项的大小，相当于低端1GB的内容
    /*********************************************/

    /* 2 更新页目录地址*/
    uint32_t new_page_dir_phy_addr = addr_v2p((uint32_t)page_dir_vaddr);
    /*页目录地址是存入在页目录的最后一项，更新页目录地址为新页目录的物理地址*/
    page_dir_vaddr[1023] = new_page_dir_phy_addr | PG_US_U | PG_RW_W | PG_P_1;
    /*****************************************************************/

    return page_dir_vaddr;
}

/*创建用户进程虚拟地址位图*/
void create_user_vaddr_bitmap(struct task_struct* user_prog){
    user_prog->userprog_vaddr.vaddr_start = USER_VADDR_START;
    uint32_t bitmap_pg_cnt = DIV_ROUND_UP((0xc0000000 - USER_VADDR_START) / PG_SIZE / 8 ,PG_SIZE);
    user_prog->userprog_vaddr.vaddr_bitmap.bits = get_kernel_pages(bitmap_pg_cnt);
    user_prog->userprog_vaddr.vaddr_bitmap.btmp_bytes_len = (0xc0000000 - USER_VADDR_START) / PG_SIZE / 8;
    bitmap_init(&user_prog->userprog_vaddr.vaddr_bitmap);
}

/*创建用户进程并加入到就绪队列中*/
void process_execute(void* filename,char* name){
    /*PCB内核的数据结构，由内核来维护进程信息，因此要在内核内存池中申请*/
    struct task_struct* thread = get_kernel_pages(1);
    init_thread(thread,name,default_prio);
    create_user_vaddr_bitmap(thread);
    thread_create(thread,start_process,filename);
    thread->pgdir = create_page_dir();
    block_desc_init(thread->u_block_desc);

    enum intr_status old_status = intr_disable();
    ASSERT(!elem_find(&thread_ready_list,&thread->general_tag));
    list_append(&thread_ready_list,&thread->general_tag);

    ASSERT(!elem_find(&thread_all_list,&thread->all_list_tag));
    list_append(&thread_all_list,&thread->all_list_tag);

    intr_set_status(old_status);
}


