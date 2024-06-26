;-------------	 loader和kernel   ----------
; loader 在内存中的位置
LOADER_BASE_ADDR equ 0x900
; loader 在硬盘上的逻辑扇区地址(LBA)
LOADER_START_SECTOR equ 0x2

KERNEL_START_SECTOR equ 0x9
KERNEL_BIN_BASE_ADDR equ 0x70000
KERNEL_ENTRY_POINT equ 0xc000_1500
PT_NULL equ 0

PAGE_DIR_TABLE_POS equ 0x10_0000    ;页目录表的物理地址，因为低端1MB用于表示内核，而0x10_0000是出1MB后的地址
;页表相关属性，b表示二进制
PG_P equ 1b                         ;P = 1表示该页存在于内存中
PG_RW_R equ 00b                     ;RW表示读写位，0表示只读
PG_RW_W equ 10b                     ;RW表示读写位，1表示可读写
PG_US_S equ 000b                    ;表示PTE和PDE的US属性是S，表示超级用户，该页不能被特权级为3的进程访问
PG_US_U equ 100b                    ;表US属性是U，表示普通用户，该页可以被所有进程访问 

;--------------   gdt描述符属性  -------------
; 查下划线的作用 其实没有任何作用 这里仅仅为了方便 确定哪些位为我们想要设置数而专门用的下划线分割
DESC_G_4K equ 1_00000000000000000000000b        ; 第23位G 表示4K或者1MB位 段界限的单位值 此时为1则为4k 
DESC_D_32 equ 1_0000000000000000000000b         ; 第22位D/B位 表示地址值用32位EIP寄存器 操作数与指令码32位
DESC_L    equ 0_000000000000000000000b          ; 第21位 设置成0表示不设置成64位代码段 忽略
DESC_AVL  equ 0_00000000000000000000b           ; 第20位 是软件可用的 操作系统额外提供的 可不设置

DESC_LIMIT_CODE2 equ 1111_0000000000000000b     ; 第16-19位 段界限的最后四位 全部初始化为1 因为最大段界限*粒度必须等于0xffffffff
DESC_LIMIT_DATA2 equ DESC_LIMIT_CODE2           ; 数据段与代码段段界限相同
DESC_LIMIT_VIDEO2 equ	0000_0000000000000000b  ; 第16-19位 显存区描述符 VIDEO2 这里的全是0为高位 低位即可表示段基址

DESC_P            equ 	1_000000000000000b	    ; 第15位  P present判断段是否存在于内存  
DESC_DPL_0        equ  00_0000000000000b        ; 第13-14位 Privilege Level 0-3
DESC_DPL_1        equ  01_0000000000000b	    ; 0为操作系统 权力最高 3为用户段 用于保护
DESC_DPL_2        equ  10_0000000000000b
DESC_DPL_3        equ  11_0000000000000b

DESC_S_sys        equ  0_000000000000b          ; 第12位为0 则表示系统段 为1则表示数据段
DESC_S_CODE       equ  1_000000000000b          ; 第12位与type字段结合 判断是否为系统段还是数据段
DESC_S_DATA       equ  DESC_S_CODE

;x=1 e=0 w=0 a=0                       
DESC_TYPE_CODE    equ  1000_00000000b           ; 第9-11位表示该段状态 1000 可执行 不允许可读 已访问位0
;x=0 e=0 w=1 a=0
DESC_TYPE_DATA    equ  0010_00000000b           ; 第9-11位type段   0010  可写  

; 代码段描述符高位4字节初始化 (0x00共8位 <<24 共32位初始化0), 0x00 代表16进制, 一个十六进制可表示4个二进制位, 0x00共8位 8+24=36位 
; 4KB为单位 Data段32位操作数 初始化的部分段界限 最高权限操作系统代码段 P存在表示 状态 
DESC_CODE_HIGH4   equ (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + \
DESC_P + DESC_DPL_0 + DESC_S_CODE + DESC_TYPE_CODE + 0x00

; 数据段描述符高位4字节初始化
DESC_DATA_HIGH4   equ (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + \
DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x00  

; 显存段描述符高位4字节初始化
; 显存的起始地址是0xb8000, 在段描述符低4字节中段基址0-15位存储的是0x8000, 所以段描述符高4字节最初8位是段基址的23-16位的值应该是0xB
DESC_VIDEO_HIGH4  equ (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + \
DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x0B

;-------------------- 选择子属性 --------------------------------
;第0-1位 RPL 特权级比较是否允许访问  第2位TI 0表示GDT 1表示LDT    第3-15位索引值
RPL0    equ 00b
RPL1    equ 01b
RPL2    equ 10b
RPL3    equ 11b
TI_GDT  equ 000b
TI_LDT  equ 100b