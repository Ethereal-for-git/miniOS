#include "init.h"
#include "print.h"
#include "interrupt.h"
#include "../device/timer.h"
#include "memory.h"
#include "../thread/thread.h"
#include "../device/console.h"
#include "../device/keyboard.h"
#include "../userprog/tss.h"
#include "syscall_init.h"

/*负责初始化所有模块*/
void init_all(){
    put_str("init_all\n");
    idt_init();     //初始化中断
    mem_init();
    thread_init();
    timer_init();   //初始化PIT   
    console_init(); //控制台初始化最好放在开中断之前
    keyboard_init();
    tss_init();
    syscall_init();
}
