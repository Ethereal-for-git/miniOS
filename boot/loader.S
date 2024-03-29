%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR

    LOADER_STACK_TOP equ LOADER_BASE_ADDR           ; loader在保护模式下的栈指针地址，esp

    ; 构建GDT及其内部描述符, 每个描述符8个字节, 拆分为高低各4字节(32位)
    GDT_BASE:   dd 0x00000000                       ; 第0个描述符,不可用
                dd 0x00000000

    CODE_DESC:  dd 0x0000ffff                       ; 低32位31~16位为段基址15~0位, 15~0位为段界限15~0位
                dd DESC_CODE_HIGH4

    DATA_STACK_DESC:    dd 0x0000ffff               ; 数据段(栈段)描述符
                        dd DESC_DATA_HIGH4

    VIDEO_DESC: dd 0x80000007                       ; 0xB8000 到0xBFFFF为文字模式显示内存 段界限:limit=(0xbffff-0xb8000) / 4k=0x7
                dd DESC_VIDEO_HIGH4                 ; 0xB

    GDT_SIZE:   equ $ - GDT_BASE                    ; 当前位置减去GDT_BASE的地址 等于GDT的大小
    GDT_LIMIT:  equ GDT_SIZE - 1                    ; SIZE - 1即为最大偏移量

    times 60 dq 0                                   ; 预留60个 四字型 描述符空位, 用于后续扩展
                                                    
    SELECTOR_CODE  equ (0x0001<<3) + TI_GDT + RPL0  ; 段选择子: 低3位为TI RPL状态, 其余为描述符索引值
    SELECTOR_DATA  equ (0x0002<<3) + TI_GDT + RPL0  
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

    ; total_mem_bytes用于保存内存容量,以字节为单位,此位置比较好记。
    ; 当前偏移loader.bin文件头0x200字节,loader.bin的加载地址是0x900,
    ; 故total_mem_bytes内存中的地址是0xb00.将来在内核中咱们会引用此地址
    total_mem_bytes dd 0

    ; gdt指针, 前2字节为gdt界限, 后4字节为gdt起始地址(共48位)
    gdt_ptr dw GDT_LIMIT
            dd GDT_BASE

    ; 人工对齐:total_mem_bytes 4字节 + gdt_ptr 6字节 + ards_buf 244字节 + ards_nr 2字节 , 共256字节
    ards_buf times 244 db 0             ; 记录内存大小的缓冲区
    ards_nr dw 0                        ; 记录 ARDS 结构体数量


    loader_start:

        ; -------  int 15h eax = 0000E820h ,edx = 534D4150h ('SMAP') 获取内存布局  -------
        xor ebx, ebx                    ; 第一次调用将eb置0
        mov edx, 0x534d4150             ; edx只赋值一次，循环体中不会改变
        mov di,  ards_buf               ; di指向ARDS缓冲区

        .e820_mem_get_loop:             ; 循环获取每个ARDS内存范围描述结构
            mov eax, 0x0000e820         ; 执行int 0x15后,eax值变为0x534d4150, 所以每次执行int前都要更新为子功能号
            mov ecx, 20                 ; ARDS地址范围描述符结构大小是20字节
            int 0x15
            jc  .e820_failed_so_try_e801    ; 若cf位为1则有错误发生，尝试0xe801子功能
            add di, cx                  ; 使di增加20字节指向缓冲区中新的ARDS结构位置
            inc word [ards_nr]          ; ARDS数量加1
            cmp ebx, 0                  ; 若 ebx 为 0 且 cf 不为 1, 这说明 ards 全部返回，当前已是最后一个
            jnz .e820_mem_get_loop      ; 不为0则循环获取

            ; 在所有ards结构中，找出(base_add_low + length_low)的最大值，即内存的容量
            mov cx, [ards_nr]           ; 遍历每一个ARDS结构体,循环次数是ARDS的数量
            mov ebx, ards_buf
            xor edx, edx                ; 用edx记录最大值, 在这里先清零

        .find_max_mem_area:             ; 无须判断type是否为1,最大的内存块一定是可被使用
            mov eax, [ebx]              ; base_add_low
            add eax, [ebx+8]            ; base_add_low + length_low = 这块ADRS容量
            add ebx, 20                 ; 指向下一块ARDS
            cmp edx, eax                ; 找出最大,edx寄存器始终是最大的内存容量
            jge .next_ards              ; 如果edx>=eax, 继续遍历下一块
            mov edx, eax                ; 如果edx<=eax, 更新edx
        .next_ards:
            loop .find_max_mem_area
            jmp .mem_get_ok             ; 获取内存容量结束


        ; ------  int 15h ax = E801h 获取内存大小,最大支持4G  ------
        ; 返回后, ax cx 值一样,以KB为单位,bx dx值一样,以64KB为单位
        ; 在ax和cx寄存器中为低16M,在bx和dx寄存器中为16MB到4G
        .e820_failed_so_try_e801:
            mov ax, 0xe801
            int 15
            jc .e801_failed_so_try88    ; 若当前e801方法失败,就尝试0x88方法

            ; 1 先算出低15M的内存, ax和cx中是以KB为单位的内存数量,将其转换为以byte为单位
            ; 乘数在eax, 即内存数量, 积高16位在edx, 低16位在eax
            mov cx, 0x400               ; 0x400 = 1024
            mul cx
            shl edx, 16                 ; 左移16位, 将低16位放到edx高16位
            and eax, 0x0000FFFF         ; 0x0000FFFF = 1111 1111 1111 1111, 高16位置0
            or  edx, eax                ; 获得完整的32位积
            add edx, 0x100000           ; edx比实际少1M, 故要加1MB
            mov esi, edx                ; 先把低15MB的内存容量存入esi寄存器备份

            ; 2 再将16MB以上的内存转换为byte为单位,寄存器bx和dx中是以64KB为单位的内存数量
            xor eax, eax
            mov ax, bx
            mov ecx, 0x10000            ; 0x10000十进制为64KB
            mul ecx                     ; 32位乘法,默认的被乘数是eax, 积为64位, 高32位存入edx, 低32位存入eax
            add esi, eax                ; 由于此方法只能测出4G以内的内存, 故32位eax足够了, edx肯定为0, 只加eax便可
            mov edx, esi                ; edx为总内存大小
            jmp .mem_get_ok


        ; -----------------  int 15h ah = 0x88 获取内存大小,只能获取64M之内  ----------
        .e801_failed_so_try88:
            ; int 15后，ax存入的是以kb为单位的内存容量
            mov  ah, 0x88
            int  0x15
            jc   .error_hlt
            and  eax, 0x0000FFFF

            ; 16位乘法，被乘数是ax,积为32位, 积的高16位在dx中，积的低16位在ax中
            mov cx, 0x400               ; 0x400等于1024, 将ax中的内存容量换为以byte为单位
            mul cx
            shl edx, 16
            or  edx, eax                ; 把积的低16位组合到edx,为32位的积
            add edx, 0x100000           ; 0x88子功能只会返回1MB以上的内存, 故实际内存大小要加上1MB


        .mem_get_ok:
            mov [total_mem_bytes], edx  ; 将内存换为byte单位后存入total_mem_bytes处


        ; --------------------------------- 设置进入保护模式 -----------------------------
        ; 1 打开A20 gate
        ; 2 加载gdt
        ; 3 将cr0 的 pe位(第0位)置1

        ; -----------------  打开A20  ----------------
        in al, 0x92                     ; 端口号0x92 中的第1位变成 1 即可
        or al, 0000_0010B
        out 0x92, al

        ; -----------------  加载GDT  ----------------
        lgdt [gdt_ptr]                  ;lgdt 48位内存数据表示访问gdtr

        ; -----------------  cr0第0位置1  ----------------
        mov eax, cr0
        or eax, 0x00000001
        mov cr0, eax


        ; -------------------------------- 已经打开保护模式 ---------------------------------------
        jmp dword SELECTOR_CODE:p_mode_start        ; 刷新流水线

        .error_hlt:                     ; 出错则挂起
            hlt                         ; 处理器暂停, 直到出现中断或复位信号才继续

        [bits 32]
        p_mode_start: 
            mov ax, SELECTOR_DATA
            mov ds, ax
            mov es, ax
            mov ss, ax
            mov esp, LOADER_STACK_TOP
            mov ax, SELECTOR_VIDEO
            mov gs, ax
        ;---------------------加载kernel-------------------------
        mov eax,KERNEL_START_SECTOR       ;kernel.bin所在扇区号
        mov ebx,KERNEL_BIN_BASE_ADDR      ;从磁盘读出后，写入到ebx指定的地址
        mov ecx,200                       ;读入的扇区数

        call rd_disk_m_32                 
        ;--------------------------------------------------------
        ;创建页目录表及页表并初始化页内存位图
        call setup_page

        ;要将描述符表地址及偏移量写入内存gdt_ptr中，一会儿用新地址加载
        sgdt [gdt_ptr]                      ;存储到原来gdt所有的位置,sgdt可以获取gdt表的位置，可以在3环和0环运行，会将gdtr寄存器能容返回

        ;因为内核运行在3GB之上，打印功能肯定要在内核中运行，不能让用户程序控制显存
        ;将gdt描述符中视频段描述符中的段基址+0xc000_0000
        mov ebx,[gdt_ptr+2]                 ;gdt前2字节是偏移量，后4字节是基址，这里是取得gdt基址
        or dword [ebx+0x18+4],0xc000_0000
        ;视频段是第3个段描述符，每个描述符是8字节，故0x18
        ;段描述符的最高4字节用来记录段基址，段基址的第31-24位

        ;修改完显存描述符后，来修改gdt基址，我们把gdt也移到内核空间中
        ;将gdt的基址加上0xc000_0000使其成为内核所在的最高位
        add dword [gdt_ptr+2],0xc000_0000
        add esp,0xc000_0000                 ;将栈指针同样映射到内核地址

        ;把页目录地址赋给cr3
        mov eax,PAGE_DIR_TABLE_POS
        mov cr3,eax

        ;打开cr0的pg位
        mov eax,cr0
        or eax,0x8000_0000
        mov cr0,eax

        ;在开启分页后，用gdt新地址重新加载
        lgdt [gdt_ptr]  ;重新加载

        ;------------此时不刷新流水线也没关系，为了以防万一还是加上
        jmp SELECTOR_CODE:enter_kernel 
        enter_kernel:
            call kernel_init
            mov esp,0xc009_f000
            jmp KERNEL_ENTRY_POINT

;------------------将kernel.bin中的segment拷贝到编译的地址---------------
kernel_init:        ;全部清零
    xor eax,eax
    xor ebx,ebx     ;ebx记录程序头表地址
    xor ecx,ecx     ;cx记录程序头表中的program header数量
    xor edx,edx     ;dx记录program header尺寸，即e_phentsize

    mov dx,[KERNEL_BIN_BASE_ADDR + 42]     ;dx = e_phentsize：偏移文件42字节处的属性是e_phentsize，表示program header的大小
    mov ebx,[KERNEL_BIN_BASE_ADDR + 28]    ;ebx = e_phoff：偏移文件开始部分28字节的地方是e_phoff，表示第一个program header在文件中的偏移量。这里是将e_phoff给ebx而不是KERNEL_BIN_BASE_ADDR + 28的地址
    add ebx,KERNEL_BIN_BASE_ADDR           ;ebx = KERNEL_BIN_BASE_ADDR + e_phoff = 程序头表的物理地址
    mov cx,[KERNEL_BIN_BASE_ADDR + 44]     ;cx = e_phnum：偏移文件开始部分44字节的地方是e_phnum，表示有几个program header

.each_segment:                      ;分析每个段，如果不是空程序类型，则将其拷贝到编译的地址中
    cmp byte [ebx + 0],PT_NULL      ;程序先判断下段类型是不是PT_NULL，表示空段类型
    je .PTNULL                      ;如果p_type = PTNULL(空程序类型)，说明此program header未使用，则跳转到下一个段头

    ;为函数mem_cpy(dst,src,size)压入参数，参数从右往左依次压入
    push dword [ebx + 16]           ;push f_filesz：program header中偏移16字节的地方是p_filesz，压入函数memcpy的第三个参数size
    mov eax,[ebx + 4]               ;eax = p_offset：距程序头偏移量为4字节的位置是p_offset
    add eax,KERNEL_BIN_BASE_ADDR    ;eax = KERNEL_BIN_BASE_ADDR + p_offset = 该段的物理地址：加上kernel.bin被加载到的物理地址，eax为该段的物理地址
    push eax                        ;push 该段的物理地址：压入memcpy的第二个参数：源地址
    push dword [ebx + 8]            ;push p_vaddr：压入memcpy的第一个参数：目的地址，偏移程序头8字节的位置是p_vaddr
    call mem_cpy                    ;调用mem_cpy完成段复制
    add esp,12                      ;清理栈中压入的三个参数，每个4B

.PTNULL:
    add ebx,edx                     ;edx为program header大小，即e_phentsize;每遍历一个段头，就跳转到下一个段头处
    loop .each_segment              ;在此ebx指向下一个program header
    ret

;------------逐字节拷贝mem_cpy(dst,src,size)-------------
;输入：栈中三个参数(dst,src,size)
;输出：无
;-------------------------------------------------------
mem_cpy:
    cld                 ;clean direction，将eflags寄存器中的方向标志位DF置0，这样rep在循环执行后面的字符串指令时，esi和edi根据使用的字符串搬运指令，自动加上所搬运数据的字节大小。
    push ebp
    mov ebp,esp         ;esp是栈顶指针
    push ecx            ;rep指令用到了ecx，但ecx对于外层段的循环还有用，所以先入栈备份
    mov edi,[ebp + 8]   ;dst
    mov esi,[ebp + 12]  ;src
    mov ecx,[ebp + 16]  ;size
    rep movsb           ;逐字节拷贝：movs表示mov string，b表示byte，w表示word，d表示dword。将DS:EI/SI指向的地址处的字节搬运到ES:DI/EI指向的地址去。
                        ;16位环境下源地址指针用SI寄存器，目的地址指针用DI寄存器；32位环境下源地址用SI寄存器，目的地址用EDI寄存器。

    ;恢复环境
    pop ecx
    pop ebp
    ret                 ;在调用ret时，栈顶处的数据是正确的返回地址。一般情况下，我们在函数体中保持push和pop配对使用。


;------------------创建页目录表及页表-------------------
setup_page:
;先把页目录表占用的空间逐字清零
    mov ecx,4096                ;4KB，ecx = 0用于loop循环的终止条件
    mov esi,0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi],0       ;PAGE_DIR_TABLE_POS用于定义页目录表的物理地址
    inc esi                     ;esi++,PAGE_DIR_TABLE_POS为基址，esi为变址
    loop .clear_page_dir

;开始创建页目录项（PDE）
.create_pde:                    ;创建Page Directory Entry
    mov eax,PAGE_DIR_TABLE_POS  
    add eax,0x1000              ;此时eax为第一个页表的位置和属性,0x10_1000
    mov ebx,eax                 ;此处为ebx赋值，是为.create_pte做准备，ebx是基址，在.create_pte中使用

;下面将页目录项0和0xc00都存为第一个页表的地址，指向同一个页表，每个页表表示4MB内存
;这样0xc03f_ffff以下的地址和0x003f_ffff以下的地址都指向相同的页表
;这是为将地址映射为内核地址做准备
    or eax,PG_US_U | PG_RW_W | PG_P         ;页目录项的属性RW和P位为1，US为1，表示用户属性，所有特权级别都可以访问,逻辑或后结果为0x7
    mov [PAGE_DIR_TABLE_POS + 0x0],eax      ;第一个目录项，在页目录表中第一个页目录项写入第一个页表的位置(0x10_1000)及属性（7）,eax = 0x10_1007
    mov [PAGE_DIR_TABLE_POS + 0xc00],eax    
;一个页表项占4B，0xc00表示第768个页表占用的目录项，0xc00以上的目录项用于内核空间，也就是页表的0xc000_0000-0xffff_ffff共计1G属于内核
;0x0-0xbfff_ffff共计3G属于用户进程
    sub eax,0x1000                          ;eax = 0x10_0000
    mov [PAGE_DIR_TABLE_POS + 4092],eax     ;使最后一个目录项指向页目录表自己的地址,4096-4=4092，因为一个目录项4B,为了将来能动态操作页表

;下面创建页表项PTE
;创建第一个页表0x10_1000,它用来分配物理范围0-0x3f_ffff之间的物理页，也就是虚拟地址0-0x3f_ffff和0xc000_0000-0xc03f_ffff对应的物理页。
    mov ecx,256                             ;因为目前只用到了1MB内存，所以只分配这1MB。1M低端内存/每页大小4k = 256页，即256个页表项，一共要创建256个页表
    mov esi,0
    mov edx,PG_US_U | PG_RW_W | PG_P        ;属性为7，US=1，RW=1，P=1
.create_pte:                                ;创建Page Table Entry
    mov [ebx + esi*4],edx                   ;向页表项中写入页表地址;此时ebx已经通过上面eax赋值为0x10_1000，也就是第一个页表的地址

    add edx,4096                            ;edx + 4KB指向下一个页表的起始地址（第二个页表）
    inc esi
    loop .create_pte

;创建内核其他页表的PDE，即内核空间中除第0个页表外的其余所有页表对应的页目录项
    mov eax,PAGE_DIR_TABLE_POS              
    add eax,0x2000                          ;此时eax为第二个页表的位置
    or eax,PG_US_U |PG_RW_W |PG_P           ;页目录项的属性US、RW和P位都是1
    mov ebx,PAGE_DIR_TABLE_POS
    mov ecx,254                             ;范围为第769-1022的所有目录项数量，第255个已经指向了页目录表本身
    mov esi,769
.create_kernel_pde:
    mov [ebx+esi*4],eax                     ;从第二个页目录项开始写
    inc esi
    add eax,0x1000
    loop .create_kernel_pde
    ret

;读取文件到内存
;eax:扇区号 ebx:待读入的地址 ecx:读入的扇区数
rd_disk_m_32:
    mov esi,eax ;备份eax
    mov di,cx   ;备份cx
    ;读写硬盘
    ;1.设置待读取的扇区数
    mov dx,0x1f2    ;设置端口号，dx用来存储端口号，要写入待读入的扇区数
    mov al,cl 
    out dx,al       ;待读入的扇区数
    mov eax,esi     ;恢复eax
    ;2.将LBA地址存入0x1f3~0x1f6
    ;LBA 7~0位写入端口0x1f3
    mov dx,0x1f3
    out dx,al
	
	;LBA 15~8位写入端口0x1f4
    mov cl,0x08
    shr eax,cl      ;逻辑右移8位，将eax的低8位移掉。
    mov dx,0x1f4 
    out dx,al 

    ;LBA 24~16位写入端口0x1f5
    shr eax,cl 
    mov dx,0x1f5 
    out dx,al 

    shr eax,cl 
    and al,0x0f     ;设置lba的24~27位
    or al,0xe0      ;设置7~4位是1110表示LBA模式
    mov dx,0x1f6
    out dx,al 

    ;3.向0x1f7端口写入读命令0x20
    mov dx,0x1f7
    mov al,0x20 
    out dx,al 

    ;4.检测硬盘状态
.not_ready:
    ;同写入命令端口，读取时标示硬盘状态，写入时是命令
    nop
    in al,dx 
    and al,0x88     ;第3位=1表示已经准备好，第7位为1表示硬盘忙
    cmp al,0x08 
    jnz .not_ready

    ;5.0x1f0端口读取数据
    mov ax,di       ;要读取的扇区数
    mov dx,256      ;一个扇区512B，一次读取2B，需要读取256次
    mul dx          ;结果放在ax中
    mov cx,ax       ;要读取的次数
    mov dx,0x1f0 
.go_on_read:
    in ax,dx 
    mov [ebx],ax    ;bx是要读取到的内存地址
    add ebx,0x02 
    loop .go_on_read;循环cx次
    ret 

