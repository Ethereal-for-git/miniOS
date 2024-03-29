[bits 32]
%define ERROR_CODE nop          ;若在相关的异常中CPU已经自动压入了错误码，为保持栈中格式同一，这里不做操作
%define ZERO push 0             ;若在相关异常中CPU没有压入错误码，为了格式统一，就手工压入一个0

extern put_str                  ;声明外部函数
extern idt_table

section .data                   ;代码段开始
global intr_entry_table         ;intr_entry_table位于data段，链接时会和宏中的data段放在一起
intr_entry_table:               ;构造intr_entry_table数组，只是构造数组，并不调用中断，中断由硬件触发，目前由时钟触发
;宏开始
%macro VECTOR 2                 ;定义了一个叫VECTOR的宏，接收两个参数。一个参数是中断向量号，第二个参数也是个宏
section .text 
intr%1entry:                    ;%1表示第一个参数，不是英文L。中断处理程序的起始地址；每个中队处理程序都要压入中断向量号，所以一个中断类型一个向量号。自己知道自己的向量号是多少
    %2                          ;压入错误码，中断若有错误码会压入到eip后
    
    ;保存上下文环境，保存ds,es,fs,gs和8个32位通用寄存器
    push ds
    push es 
    push fs 
    push gs 
    pushad 

    ;发送EOI信号的目的是告知硬件中断控制器8259A，当前中断已经处理完成，可以继续处理其他中断请求。
    ;如果是从片中进入的中断，除了往从片上发送EOI外，还要往主片上发送EOI
    mov al,0x20                 ;中断结束命令EOI。OCW2的第5位是EOI位，其余都是0，所以是0x20。我们要向8259A发送结束标志，不然手动结束的8259A不知道中断结束了。
    out 0xa0,al                 ;向主片发送
    out 0x20,al                 ;向从片发送

    ;处理中断，即调用中断处理函数
    push %1                     ;不管idt_table中的目标程序是否需要参数，都一律压入中断向量号
    call [idt_table + %1*4]

    ;中断结束，返回原进程
    jmp intr_exit
 
section .data                   ;表示上一个代码段结束
    dd intr%1entry              ;dd用来定义数组元素的宽度，元素值为intr%lentry；存储各个中断入口程序的地址，形成intr_entry_table数组。这样每个宏调用都会在数组中产生新的地址元素
%endmacro
;宏结束

section .text 
global intr_exit
intr_exit:
    ;跳过中断号
    add esp,4                   
    ;恢复上下文环境
    popad 
    pop gs 
    pop fs
    pop es 
    pop ds 
    ;跳过error_code
    add esp,4                   
    ;返回主程序，iretd用于从中断服务例程（ISR）返回到被中断的程序。
    iretd                        

;;;;;;;;;;;;;; 0x80号中断  ;;;;;;;;;;;;;;;;;;
[bits 32]
extern syscall_table
section .text
global syscall_handler
syscall_handler:    
    ;1.保护上下文环境
    push 0      ;压入0，使栈中格式统一
    push ds
    push es
    push fs
    push gs
    pushad      ;pushad指令压入32位寄存器，其入栈顺序为eax,ecx,edx,ebx,esp,ebp,esi,edi
    push 0x80   ;此位置压入0x80也是为了保持统一的栈格式

    ;2.为系统调用子功能传入参数
    push edx    ;系统调用中第3个参数
    push ecx    ;系统调用中第2个参数
    push ebx    ;系统调用中第1个参数

    ;3.调用子功能处理函数
    call [syscall_table + eax*4]
    add esp,12  ;跨过上面三个参数

    ;4.将call调用后的返回值存入当前内核栈中eax的位置
    mov [esp + 8*4],eax     ;根据ABI约定，寄存器eax用来存储返回值。于是我们将eax中的返回值写入到pushad中的eax中，防止被篡改。8*4 = (0x80 + 7个寄存器)*4
    jmp intr_exit   ;返回，恢复上下文

VECTOR 0x0 ,ZERO
VECTOR 0X1 ,ZERO
VECTOR 0X2 ,ZERO
VECTOR 0x3 ,ZERO
VECTOR 0X4 ,ZERO
VECTOR 0X5 ,ZERO
VECTOR 0x6 ,ZERO
VECTOR 0X7 ,ZERO
VECTOR 0X8 ,ERROR_CODE
VECTOR 0x9 ,ZERO
VECTOR 0XA ,ERROR_CODE
VECTOR 0XB ,ERROR_CODE
VECTOR 0XC ,ERROR_CODE
VECTOR 0XD ,ERROR_CODE
VECTOR 0XE ,ERROR_CODE
VECTOR 0XF ,ZERO
VECTOR 0X10 ,ZERO
VECTOR 0X11 ,ERROR_CODE
VECTOR 0x12 ,ZERO
VECTOR 0X13 ,ZERO
VECTOR 0X14 ,ZERO
VECTOR 0x15 ,ZERO
VECTOR 0X16 ,ZERO
VECTOR 0X17 ,ZERO
VECTOR 0X18 ,ZERO
VECTOR 0X19 ,ZERO
VECTOR 0X1A ,ZERO
VECTOR 0X1B ,ZERO
VECTOR 0X1C ,ZERO
VECTOR 0X1D ,ZERO
VECTOR 0X1E ,ERROR_CODE                               ;处理器自动推错误码
VECTOR 0X1F ,ZERO					
VECTOR 0X20 ,ZERO					;时钟中断
VECTOR 0X21 ,ZERO					;键盘中断
VECTOR 0X22 ,ZERO					;级联
VECTOR 0X23 ,ZERO					;串口2
VECTOR 0X24 ,ZERO					;串口1
VECTOR 0X25 ,ZERO					;并口2
VECTOR 0X26 ,ZERO					;软盘
VECTOR 0X27 ,ZERO					;并口1
VECTOR 0X28 ,ZERO					;实时时钟
VECTOR 0X29 ,ZERO					;重定向
VECTOR 0X2A ,ZERO					;保留
VECTOR 0x2B ,ZERO					;保留
VECTOR 0x2C ,ZERO					;ps/2 鼠标
VECTOR 0x2D ,ZERO					;fpu 浮点单元异常
VECTOR 0x2E ,ZERO					;硬盘
VECTOR 0x2F ,ZERO					;保留
VECTOR 0x30 ,ZERO
VECTOR 0x31 ,ZERO
VECTOR 0x32 ,ZERO
VECTOR 0x33 ,ZERO
VECTOR 0x34 ,ZERO
VECTOR 0x35 ,ZERO
VECTOR 0x36 ,ZERO
VECTOR 0x37 ,ZERO
VECTOR 0x38 ,ZERO
VECTOR 0x39 ,ZERO
VECTOR 0x3A ,ZERO
VECTOR 0x3B ,ZERO
VECTOR 0x3C ,ZERO
VECTOR 0x3D ,ZERO
VECTOR 0x3E ,ZERO
VECTOR 0x3F ,ZERO
VECTOR 0x40 ,ZERO
VECTOR 0x41 ,ZERO
VECTOR 0x42 ,ZERO
VECTOR 0x43 ,ZERO
VECTOR 0x44 ,ZERO
VECTOR 0x45 ,ZERO
VECTOR 0x46 ,ZERO
VECTOR 0x47 ,ZERO
VECTOR 0x48 ,ZERO
VECTOR 0x49 ,ZERO
VECTOR 0x4A ,ZERO
VECTOR 0x4B ,ZERO
VECTOR 0x4C ,ZERO
VECTOR 0x4D ,ZERO
VECTOR 0x4E ,ZERO
VECTOR 0x4F ,ZERO
VECTOR 0x50 ,ZERO
VECTOR 0x51 ,ZERO
VECTOR 0x52 ,ZERO
VECTOR 0x53 ,ZERO
VECTOR 0x54 ,ZERO
VECTOR 0x55 ,ZERO
VECTOR 0x56 ,ZERO
VECTOR 0x57 ,ZERO
VECTOR 0x58 ,ZERO
VECTOR 0x59 ,ZERO
VECTOR 0x5A ,ZERO
VECTOR 0x5B ,ZERO
VECTOR 0x5C ,ZERO
VECTOR 0x5D ,ZERO
VECTOR 0x5E ,ZERO
VECTOR 0x5F ,ZERO
VECTOR 0x61 ,ZERO
VECTOR 0x62 ,ZERO
VECTOR 0x63 ,ZERO
VECTOR 0x64 ,ZERO
VECTOR 0x65 ,ZERO
VECTOR 0x66 ,ZERO
VECTOR 0x67 ,ZERO
VECTOR 0x68 ,ZERO
VECTOR 0x69 ,ZERO
VECTOR 0x6A ,ZERO
VECTOR 0x6B ,ZERO
VECTOR 0x6C ,ZERO
VECTOR 0x6D ,ZERO
VECTOR 0x6E ,ZERO
VECTOR 0x6F ,ZERO
VECTOR 0x70 ,ZERO
VECTOR 0x71 ,ZERO
VECTOR 0x72 ,ZERO
VECTOR 0x73 ,ZERO
VECTOR 0x74 ,ZERO
VECTOR 0x75 ,ZERO
VECTOR 0x76 ,ZERO
VECTOR 0x77 ,ZERO
VECTOR 0x78 ,ZERO
VECTOR 0x79 ,ZERO
VECTOR 0x7A ,ZERO
VECTOR 0x7B ,ZERO
VECTOR 0x7C ,ZERO
VECTOR 0x7D ,ZERO
VECTOR 0x7E ,ZERO
VECTOR 0x7F ,ZERO
VECTOR 0x80 ,ZERO
