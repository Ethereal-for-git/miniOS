#include "interrupt.h"
#include "stdint.h"
#include "global.h"
#include "io.h"
#include "print.h"

#define IDT_DESC_CNT 0x81           //目前共支持的中断数，33
#define PIC_M_CTRL 0x20             //主片的控制端口是0x20
#define PIC_M_DATA 0x21             //主片的数据端口是0x21
#define PIC_S_CTRL 0xa0             //从片的控制端口是0xa0
#define PIC_S_DATA 0xa1             //从片的数据端口是0xa1
#define EFLAGS_IF 0x00000200	    //eflags寄存器中的if=1
#define GET_FLAGS(EFLAG_VAR) asm volatile("pushfl;popl %0" : "=g"(EFLAG_VAR))
//"=g" 指示编译器将结果放在任意通用寄存器中，并将其赋值给 EFLAG_VAR。
//pushfl 指令将标志寄存器 EFLAGS 的值入栈，然后 popl %0 指令将栈顶的值弹出到指定的操作数 %0 中。
//当调用 GET_FLAGS(EFLAG_VAR) 宏时，它将 EFLAGS 寄存器的值存储到 EFLAG_VAR 变量中。

/*中断门描述符结构体*/
struct gate_desc{
    uint16_t func_offset_low_word;  //低32位——0~15位：中断处理程序在目标代码段内的偏移量的第15~0位
    uint16_t selector;              //低32位——16~31位：目标CS段选择子
    uint8_t dcount;                 //高32位——0~7位：此项为双字计数字段，是门描述符中的第4字节，为固定值
    uint8_t attribute;              //高32位——8~15位：P+DPL+S+TYPE
    uint16_t func_offset_high_word; //高32位——16~31位：中断处理程序在目标代码段内的偏移量的第16~31位
};

//静态函数声明，非必须
static void make_idt_desc(struct gate_desc* p_gdesc,uint8_t attr,intr_handler function);
static struct gate_desc idt[IDT_DESC_CNT];  //IDT是中描述符表，实际上是中断门描述符数组

extern uint32_t syscall_handler(void);
extern intr_handler intr_entry_table[IDT_DESC_CNT]; //指针格式应该与数组类型一致，这里intr_entry_table中的元素类型就是function，就是.text的地址。所以用intr_handle来引用。声明引用定义在kernel.S中的中断处理函数入口数组
char* intr_name[IDT_DESC_CNT];      //用于保存异常的名字
/*定义中断处理函数：在kernel.S中定义的intrXXentry只是中断处理程序的入口，最终调用的是ide_table中的处理程序*/
intr_handler idt_table[IDT_DESC_CNT];   //idt_table为函数数组，里面保持了中断处理函数的指针

/*创建中断门描述符*/
static void make_idt_desc(struct gate_desc* p_gdesc,uint8_t attr,intr_handler function){ //intr_handler是个空指针类型，仅用来表示地址 
    //中断门描述符的指针、中断描述符内的属性、中断描述符内对应的中断处理函数
    p_gdesc->func_offset_low_word = (uint32_t)function & 0x0000ffff;
    p_gdesc->selector = SELECTOR_K_CODE;
    p_gdesc->dcount = 0;
    p_gdesc->attribute = attr;
    p_gdesc->func_offset_high_word = ((uint32_t)function & 0xffff0000) >> 16;
}

/*初始化中断描述符表*/
static void idt_desc_init(void){
    int i,lastindex = IDT_DESC_CNT - 1;
    for(i = 0;i < IDT_DESC_CNT;i++){
        make_idt_desc(&idt[i],IDT_DESC_ATTR_DPL0,intr_entry_table[i]);
    }
    /*单独处理系统调用，系统调用对应的中断门dpl为3，中断处理程序为单独的syscall_handler*/
    make_idt_desc(&idt[lastindex],IDT_DESC_ATTR_DPL3,syscall_handler);
    put_str("   idt_desc_init done\n");
}

/*初始化可编程中断控制器8259A*/
static void pic_init(void){
    /*初始化主片*/
    outb(PIC_M_CTRL,0x11);          //ICW1：边沿触发，级联8259，需要ICW4
    outb(PIC_M_DATA,0x20);          //ICW2：起始中断向量号为0x20，也就是IR[0-7]为0x20~0x27
    outb(PIC_M_DATA,0x04);          //ICW3：IR2接从片
    outb(PIC_M_DATA,0x01);          //ICW4：8086模式，正常EOI
    /*初始化从片*/
    outb(PIC_S_CTRL,0x11);          //ICW1：边沿触发，级联8259，需要ICW4
    outb(PIC_S_DATA,0x28);          //ICW2：起始中断向量号为0x28，也就是IR[8-15]为0x28~0x2F
    outb(PIC_S_DATA,0x02);          //ICW3：设置从片连接到主片的IR2引脚
    outb(PIC_S_DATA,0x01);          //ICW4：8086模式，正常EOI
    /*打开主片上IR0，打开时钟产生的中断*/
    outb(PIC_M_DATA,0xfe);
    outb(PIC_S_DATA,0xff);
    // /*测试键盘，打开键盘中断*/
    // outb(PIC_M_DATA,0xfd);
    // outb(PIC_S_DATA,0xff);
    /*打开时钟中断和键盘中断*/
    // outb(PIC_M_DATA,0xfc);
    // outb(PIC_S_DATA,0xff);
    put_str("   pic_init done\n");
}

/*通用的中断处理函数，一般用在异常出现时的处理*/
static void general_intr_handler(uint8_t vec_nr){
    if(vec_nr == 0x27 || vec_nr == 0x2f){   //IRQ7和IRQ5会产生伪中断，无需处理;0x2f是从片8259A的最后一个IRQ引脚，保留项
        return;
    }
    //将光标置零，从屏幕左上角清出一片打印异常信息的区域，方便阅读
    set_cursor(0);
    int cursor_pos = 0;
    while (cursor_pos < 320)
    {
        put_char(' ');
        cursor_pos++;
    }
    set_cursor(0);      //重置光标为屏幕左上角
    put_str("!!!!!!! excetion message begin !!!!!!!\n");
    set_cursor(88);     //从第2行第8个字符开始打印
    put_str(intr_name[vec_nr]);
    if(vec_nr == 14){   //若为PageFault，将缺失的地址打印出来并悬停
        int page_fault_vaddr = 0;
        asm("movl %%cr2,%0" : "=r"(page_fault_vaddr));     //将cr2的值转存到page_fault中。cr2是存放造成page_fault的地址
        put_str("\npage fault addr is ");
        put_int(page_fault_vaddr);
    }
    put_str("!!!!!!! excetion message end !!!!!!!\n");
    //能进入中断处理程序就表示已经处在关中断情况下
    //不会出现调度进程的情况，故下面的死循环不会再被打断
    while (1);
}

/*初始化idt_table*/
static void exception_init(void){
    //将idt_table的元素都指向通用的中断处理函数，名称为unknown
    int i;
    for(i = 0;i < IDT_DESC_CNT;i++){
        idt_table[i] = general_intr_handler;    //默认为general_intr_handler，以后会由register_handler来注册具体函数
        intr_name[i] = "unknown";
    }
    intr_name[0] = "#DE Divide Error";
    intr_name[1] = "#DB Debug Exception";
    intr_name[2] = "NMI Interrupt";
    intr_name[3] = "BP Breakpoint Exception";
    intr_name[4] = "#OF Overflow Exception";
    intr_name[5] = "#BR BOUND Range Exceeded Exception";
    intr_name[6] = "#UD Invalid Opcode Exception";
    intr_name[7] = "#NM Device Not Available Exception";
    intr_name[8] = "#DF Double Fault Exception";
    intr_name[9] = "Coprocessor Segment Overrun";
    intr_name[10] = "#TS Invalid TSS Exception";
    intr_name[11] = "#NP Segment Not Present";
    intr_name[12] = "#SS Stack Fault Exception";
    intr_name[13] = "#GP General Protection Exception";
    intr_name[14] = "#PF Page-Fault Exception";
    //intr_name[15]是intel保留项，未使用
    intr_name[16] = "#MF x87 FPU Floating-Point Error";
    intr_name[17] = "#AC Alignment Check Exception";
    intr_name[18] = "#MC Machine-Check Exception";
    intr_name[19] = "#XF SIMD Floating-Point Exception";
}

/*完成所有有关中断的初始化工作*/
void idt_init(){
    put_str("idt_init start\n");
    idt_desc_init();                //初始化中断描述符表
    exception_init();
    pic_init();                     //初始化8259A
    /*加载idt*/
    // uint64_t idt_operand = ((sizeof(idt)-1) | (uint64_t)((uint32_t)idt << 16)); //书上是错的
    uint64_t idt_operand = ((sizeof(idt)-1) | ((uint64_t)(uint32_t)idt << 16)); //低16位是idt的大小，高48位是IDT的基址。因为idt是32位，左移16位后会丢失高16位，所以先转换为64位再左移
    asm volatile("lidt %0" : : "m" (idt_operand));   //加载IDT，IDT的0~15位是表界限，16~47位是表基址
    put_str("idt_init done\n");
}

/*开中断，并返回开中断前的状态*/
enum intr_status intr_enable(){
	enum intr_status old_status;
	if(INTR_ON == intr_get_status()){
		old_status = INTR_ON;
		return old_status;
	}else{
		old_status = INTR_OFF;
		asm volatile("sti");	//开中断
		return old_status;
	}
}

/*关中断，并返回关中断前的状态*/
enum intr_status intr_disable(){
	enum intr_status old_status;
	if(INTR_ON == intr_get_status()){
		old_status = INTR_ON;
		asm volatile("cli" : : : "memory");	//关中断，cli指令将IF位置0
		return old_status;
	}else{
		old_status = INTR_OFF;
		return old_status;
	}
}

/*将中断状态设置为status*/
enum intr_status intr_set_status(enum intr_status status){
	return status & INTR_ON ? intr_enable() : intr_disable();
}

/*获取当前中断状态*/
enum intr_status intr_get_status(){
	uint32_t eflags = 0;
	GET_FLAGS(eflags);
	return (EFLAGS_IF & eflags) ? INTR_ON : INTR_OFF;
}

/*在中断处理程序数组第vector_no个元素中注册安装中断处理程序function*/
void register_handler(uint8_t vector_no,intr_handler function){
    idt_table[vector_no] = function;    //idt_table数组中的函数是在进入中断后根据中断向量号调用的
}