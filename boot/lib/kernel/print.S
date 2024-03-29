TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

section .data 
put_int_buffer dq 0             ;定义8字节缓冲区用于数字到字符的转换

[bits 32]
section .text
;------------------------------------------
;put_str通过put_char来打印以0字符结尾的字符串
;------------------------------------------
;输入：栈中参数为打印的字符串
;输出：无

global put_str 
put_str:
;由于函数只用到了ebx和ecx两个寄存器，所以只备份这两个
    push ebx 
    push ecx 
    xor ecx,ecx                 ;准备用ecx存储参数，清空
    mov ebx,[esp+12]            ;从栈中得到待打印的字符串地址(传入的参数)
.goon:
    mov cl,[ebx]                
    cmp cl,0                    ;如果处理到了字符串尾，则跳到结束时返回
    jz .str_over 
    push ecx                    ;为put_char传递参数,把ecx的值入栈
    call put_char               ;call时会把返回地址入栈4
    add esp,4                   ;回收参数的栈空间
    inc ebx                     ;使ebx指向下一个字符
    jmp .goon
.str_over:
    pop ecx 
    pop ebx 
    ret 

;-----------put_char---------------
;功能描述：把栈中的1个字符写入光标所在处
;----------------------------------
global put_char                 ;将put_char导出为全局符号
put_char:
    pushad                      ;备份32位寄存器环境,push all double，将8个32位寄存器都备份了。它们入栈的顺序为：EAX->ECX->EDX->EBX->ESP->EBP->ESI->EDI
    mov ax,SELECTOR_VIDEO       ;需要保证gs中为正确的视频段选择子，为保险起见，每次打印都为gs赋值
    mov gs,ax                   ;不能直接把立即数送入段寄存器
    ;;;;;获取当前光标的位置;;;;;
    ;先获取高8位
    mov dx,0x03d4               ;索引寄存器，03d4为Address Register，用于索引寄存器。
    mov al,0x0e                 ;用于提供光标位置的高8位
    out dx,al
    mov dx,0x03d5               ;03d5是Data Register；可以写数据和读数据。通过读写数据端口0x3d5来获取/设置光标的位置
    in al,dx                    ;得到光标位置的高8位
    mov ah,al                   ;将得到的光标高8位放入ah中

    ;再获取低8位
    mov dx,0x03d4
    mov al,0x0f                 ;用于提供光标位置的低8位
    out dx,al 
    mov dx,0x03d5 
    in al,dx 

    ;将光标位置存入bx，bx寄存器习惯性作为基址寻址。此时bx是下一个字符的输出位置。
    mov bx,ax 
    ;获取栈中压入字符的ASCII码
    mov ecx,[esp + 36]          ;pushad压入8*32b=32字节，加上主调函数4B的返回地址。故栈顶偏移36字节。
    ;判断字符是什么类型
    cmp cl,0xd                  ;CR是0x0d，回车键
    jz .is_carriage_return 
    cmp cl,0xa                  ;LF是0x0a，换行符
    jz .is_line_feed 

    cmp cl,0x8                  ;BS是0x08，退格键
    jz .is_backspace 
    jmp .put_other 

.is_backspace:                  ;理论上将光标移到该字符前即可，但怕下个字符为回车等，原字符还留着当地，所以用空格/空字符0替代原字符
    dec bx                      ;bx值-1，光标指向前一个字符
    shl bx,1                    ;左移一位等于乘2，表示光标对应显存中的偏移字节
    mov byte [gs:bx],0x20       ;0x20表示空格
    inc bx                      ;bx+1
    mov byte [gs:bx],0x07       ;0x07表示黑屏白字，这是显卡默认的前景色和背景色，不加也行。
    shr bx,1                    ;右移一位表示除以2取整，bx由显存的相对地址恢复到光标位置
    jmp .set_cursor             ;设置光标位置

.put_other:                     ;处理可见字符
    shl bx,1                    ;光标左移1位等于乘2，表示光标位置
    mov [gs:bx],cl              ;将ASCII字符放入光标位置中
    inc bx                      ;bx+1
    mov byte [gs:bx],0x07       ;字符属性，黑底白字
    shr bx,1                    ;右移一位表示除以2取整，bx由显存的相对地址恢复到光标位置
    inc bx                      ;bx+1，下一个光标值
    cmp bx,2000                 ;看是否需要滚屏
    jl .set_cursor              ;"JL"是"jump if less"（如果小于则跳转）：若光标值<=2000，表示未写到。显存的最后，则去设置新的光标值，若超过屏幕字符数大小（2000），则换行（滚屏）。

.is_line_feed:                  ;是换行符LF(\n)
.is_carriage_return:            ;是回车键CR(\r),\n和\r在Linux中都是\n的意思。
    xor dx,dx                   ;dx是被除数的高16位，清零
    mov ax,bx                   ;ax是被被除数的低16位，bx是光标位置
    mov si,80                   ;si = 80为除数
    div si                      ;对80取模，(dx + ax)/si = ax(商) + dx(余数) 即bx/80=几行(ax) + 第几列(dx)
    ;如果除数是16位，被除数就是32位，位于dx和ax（高16位，低16位）中；结果的商放在ax中，余数放入dx中
    sub bx,dx                   ;bx-dx表示将bx放在行首，实现了回车的功能。

.is_carriage_return_end:        ;回车符处理结束，判断是否需要滚屏
    add bx,80 
    cmp bx,2000 
.is_line_feed_end:              ;若是LF，则光标移+80即可
    jl .set_cursor

.roll_screen:                   ;若超过屏幕大小，开始滚屏：屏幕范围是0~23，滚屏原理是把1~24->0~23，再将24行用空格填充
    cld 
    mov ecx,960                 ;2000-80=1920个字符，共1920*2=3840字节，一次搬运4字节，一共要搬运3840/4=960次        
    mov esi,0xc00b_80a0         ;第1行行首，源索引地址寄存器
    mov edi,0xc00b_8000         ;第0行行首，目的索引地址寄存器
    rep movsd                   ;repeat move string doubleword，以32b为单位进行移动，直到ecx=0
    ;将最后一行填充为空白
    mov ebx,3840                ;最后一行从3840开始
    mov ecx,80                  ;一行80字符，每次清空1字符（2B），一行要移动80次

.cls:
    mov word [gs:ebx],0x0720    ;0x0720是黑底白字的空格键,一次清空一个字符（2B）
    add ebx,2                   ;ebx移动到下一个字符处
    loop .cls                   ;循环.cls，直到ecx=0
    mov bx,1920                 ;bx存放下一个字符的光标位置，即3840/2=1920

.set_cursor:                    ;将光标设置为bx值
    ;先设置高8位
    mov dx,0x03d4               ;索引寄存器，通过0x3d4写入待操作寄存器的索引
    mov al,0x0e                 ;用于提供光标的高8位
    out dx,al 
    mov dx,0x03d5               ;通过数据端口0x3d5来设置光标位置
    mov al,bh                   ;将bx的光标位置的高8位放入al中，通过al输入到dx = 0x3d5端口
    out dx,al                   ;[0x3d5端口] = bx高8位 = bh
    ;再设置低8位
    mov dx,0x03d4 
    mov al,0x0f                 ;用于提供光标的低8位
    out dx,al 
    mov dx,0x03d5               ;通过数据端口0x3d5来设置光标位置 
    mov al,bl                   ;将bx的光标位置的低8位放入al中，通过al输入到dx = 0x3d5端口 
    out dx,al                   ;[0x3d5端口] = bx低8位 = bl
    .put_char_done:
        popad                   ;将之前入栈的8个32b的寄存器出栈
        ret                     

;------------将小端字节序的数字变成对应的ASCII码后，倒置--------------
;输入：栈中参数为待打印的数字
;输出：在屏幕上打印16进制数字，并不会打印前缀0x
;------------------------------------------------------------------
global put_int 
put_int:
    pushad                      
    mov ebp,esp 
    mov eax,[ebp+4*9]           ;将参数写入eax中，call返回地址占4B+pushad的8个4B
    mov edx,eax                 ;eax存储的是参数的备份，edx为每次参与位变换的参数，当转换为16进制数字后，eax将下一个参数给edx
    mov edi,7                   ;指定在put_int_buffer中初始的偏移量，表示指向缓冲区的最后一个字节
    mov ecx,8                   ;32位数字中，每4位表示一个16进制数字。所以32位可以表示8个16进制数字，位数为8。
    mov ebx,put_int_buffer      ;ebx为缓冲区的基址
;将32位数字按照16进制的形式从低到高逐个处理，共处理8个16进制数字
.16based_4bits:
    ;将32位数字按照16进制形式从低到高逐字处理
    and edx,0x0000000F          ;解析16进制数字的每一位，and后edx只有低4位有效（最低位的16进制数字）
    cmp edx,9                   ;数字0~9和a~f需要分别处理成对应的字符
    jg .is_A2F                  ;jg：Jump if Greater 若大于9，则跳转.is_A2F
    add edx,'0'                 ;如果是0~9，则加上'0'的ASCII码
    jmp .store 
.is_A2F:
    sub edx,10                  ;A~F减去10所得的差，10的ASCII码为1
    add edx,'A'                 ;加上10的ASCII码得到字符的ASCII码
;将每个数字转换成对应的字符后，按照类似大端的顺序存储到缓冲区put_int_buffer中。
;高位字符放在低地址，低位字符放在高地址，这样和大端字符序类似。
.store:
    ;此时dl中应该是对应数字的ASCII码
    mov [ebx+edi],dl 
    dec edi 
    shr eax,4                   ;右移4位，去掉最低4位
    mov edx,eax
    loop .16based_4bits
;现在把put_int_buffer中已全是字符，打印之前把高位连续的字符去掉。
;例如：000123 -> 123
.ready_to_print:
    inc edi                     ;此时edi为-1(0xffff_ffff)，加1使其为0
.skip_prefix_0:
    cmp edi,8                   ;若以及比较到第9个字符，表示待打印的字符都是0
    je .full0                   ;Jump if Equal 
;找出连续的0字符，edi作为非0的最高位字符的偏移
.go_on_skip:
    mov cl,[put_int_buffer+edi] 
    inc edi 
    cmp cl,'0'                  ;判断下一位字符是否为0 
    je .skip_prefix_0           
    dec edi                     ;若当前字符不为'0'，则使edi减1恢复当前字符            
    jmp .put_each_num           ;若下一位不为0，则从这一位开始遍历
.full0:
    mov cl,'0'                  ;当输入字符都是0时，只打印0
.put_each_num:
    push ecx                    ;此时ecx中为可打印字符，作为参数传递入put_char中
    call put_char
    add esp,4                   ;覆盖掉ecx，清理栈参数，相当于pop ecx
    inc edi                     ;使edi指向下个字符
    mov cl,[put_int_buffer+edi] ;将下个字符放入cl中
    cmp edi,8
    jl .put_each_num
    popad 
    ret
    
; 对应函数 void set_cursor(uint32_t cursor_pos);
global set_cursor
set_cursor:
    pushad
    mov bx, [esp + 36]

    ; 1. 先设置高8位
    mov dx, 0x03d4          ; 索引寄存器
    mov al, 0x0e            ; 光标高8位
    out dx, al

    mov dx, 0x03d5          ; 通过读写数据端口0x3d5来获得或设置光标位置 
    mov al, bh
    out dx, al

    ; 2. 再设置低8位
    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al

    mov dx, 0x03d5 
    mov al, bl
    out dx, al

    popad
    ret

