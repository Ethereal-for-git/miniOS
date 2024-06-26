; 主引导程序
;-------------------------------------------------------
%include "boot.inc"

section MBR vstart=0x7c00

    ; 初始化段寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00 ;这个时候 ds = es = ss = 0 栈指针指向MBR开始位置
    mov ax, 0xb800
    mov gs, ax     ; 将gs设置为0xb800,之后操作显存 
    ; 初始化段寄存器结束


    ; 清屏 利用0x06号功能，上卷全部行，则可清屏。
    ; -----------------------------------------------------------
    ;INT 0x10   功能号:0x06	   功能描述:上卷窗口
    ;------------------------------------------------------
    ;输入：
    ;AH 功能号= 0x06
    ;AL = 上卷的行数(如果为0,表示全部)
    ;BH = 上卷行属性
    ;(CL,CH) = 窗口左上角的(X,Y)位置
    ;(DL,DH) = 窗口右下角的(X,Y)位置
    ;无返回值：
    mov ax, 0x600 ; 设置AH为06， 即功能号= 0x06, 上卷全部行数
    mov bx, 0x700
    mov cx, 0     ; 窗口左上角的(0,0)位置
    mov dx, 0x184f ;窗口右下角的(24,79)位置, 因为默认为80x25的VGA文本模式, 0x18=24, 0x4f=79
    int 0x10
    ; 清屏结束


    ; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
    mov byte [gs:0x00],'1'
    mov byte [gs:0x01],0xA4     ; A表示绿色背景闪烁，4表示前景色为红色

    mov byte [gs:0x02],' '
    mov byte [gs:0x03],0xA4

    mov byte [gs:0x04],'M'
    mov byte [gs:0x05],0xA4   

    mov byte [gs:0x06],'B'
    mov byte [gs:0x07],0xA4

    mov byte [gs:0x08],'R'
    mov byte [gs:0x09],0xA4

    mov eax, LOADER_START_SECTOR    ; 起始扇区LBA地址
    mov bx, LOADER_BASE_ADDR        ; 写入的地址
    mov cx, 4                       ; 待读入扇区数
    call rd_disk_m_16               ; 调用函数读取硬盘

    jmp LOADER_BASE_ADDR + 0x300           ; 移交控制权给loader


    ;-------------------------------------------------------------------------------
    ; 功能:读取硬盘n个扇区
    ; eax=LBA扇区号
	; ebx=将数据写入的内存地址
	; ecx=读入的扇区数  
    ; 1. 写入待操作磁盘数
    ; 2. 写入LBA 低24位寄存器 确认扇区
    ; 3. device 寄存器 第4位主次盘 第6位LBA模式 改为1
    ; 4. command 写指令
    ; 5. 读取status状态寄存器 判断是否完成工作
    ; 6. 完成工作 取出数据 
    ;-------------------------------------------------------------------------------
	rd_disk_m_16:

        mov esi, eax    ; 备份eax
        mov di, cx      ; 备份cx

        ;读写硬盘:
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;第1步：设置要读取的扇区数, 0x1f2端口
        mov dx, 0x1f2
        mov al, cl
        out dx, al      ; 读取扇区数
        mov eax, esi    ; 恢复 ax
        ; 第1步结束
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;第2步：将LBA地址存入0x1f3 ~ 0x1f6

        ;LBA地址7~0位写入端口0x1f3
        mov dx, 0x1f3
        out dx, al

        ;LBA地址15~8位写入端口0x1f4
        mov cl, 8
        shr eax, cl
        mov dx, 0x1f4   ; 右移8位，获取15-8位
        out dx, al

        ;LBA地址23~16位写入端口0x1f5
        shr eax, cl
        mov dx, 0x1f5
        out dx, al

        ; device 寄存器(0x1f6) 第4位主次盘(0主盘，1次盘） 
        ; 第6位LBA模式 改为1, 5、7位固定为7
        shr eax, cl     ; 把除了最后四位的其他位置设置成0
        and al, 0x0f    ;LBA第24~27位 0x0f=1111, 
        or al, 0xe0     ;0xe0=1110 0000, 把第7-4位设置成1110 转换为LBA模式
        mov dx, 0x1f6
        out dx, al
        ; 第2步结束
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;第3步：向0x1f7端口写入读命令，0x20 
        mov dx, 0x1f7
        mov al, 0x20
        out dx, al
        ; 第3步结束
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;第4步：检测硬盘状态
        ;设置不断读取重复 如果不为1则一直循环
        .not_ready:
            nop             ; 空跳转指令 在循环中达到延时目的(跳转过来之后等一下)
            in al, dx       ; 把寄存器中的信息返还出来
            and al, 0x88    ; 0x88=1000 1000, 保留第3和第7位 ,第3位为1表示硬盘控制器已经准备好数据， 第7位为1表示硬盘很忙
            cmp al, 0x08    ; 0x08=1000, 判断第3位是否为1, 不跳转结果为 al=0000 1000, 即硬盘已经准备好了
            jnz .not_ready  ; 若未准备好，继续等

        ; 第4步结束
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;第5步：从0x1f0端口读数据
        mov ax, di      ; 把 di 储存的cx 取出来 即读入的扇区数  
        mov dx, 256     ; di为要读取的扇区数，一个扇区有512字节，每次读入一个字，共需di*512/2次，所以di*256
        mul dx          ; 被乘数在ax, 即 ax*256, 得到结果高16位在dx, 低16位在ax
        mov cx, ax      ; 得到要执行的in指令次数
        mov dx, 0x1f0

        .go_on_read:
            in ax, dx           ;两字节dx 一次读2byte
            mov [bx], ax        ; ebx=将数据写入的内存地址
            add bx, 2           ; 一次读2byte，所以将地址加2
            loop .go_on_read    ; 循环读取

            ret                 ; 函数调用结束

        ; 第5步结束, 函数调用结束
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    times 510-($-$$) db 0
    db 0x55, 0xaa


