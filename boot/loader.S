%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR

    LOADER_STACK_TOP equ LOADER_BASE_ADDR           ; loader�ڱ���ģʽ�µ�ջָ���ַ��esp

    ; ����GDT�����ڲ�������, ÿ��������8���ֽ�, ���Ϊ�ߵ͸�4�ֽ�(32λ)
    GDT_BASE:   dd 0x00000000                       ; ��0��������,������
                dd 0x00000000

    CODE_DESC:  dd 0x0000ffff                       ; ��32λ31~16λΪ�λ�ַ15~0λ, 15~0λΪ�ν���15~0λ
                dd DESC_CODE_HIGH4

    DATA_STACK_DESC:    dd 0x0000ffff               ; ���ݶ�(ջ��)������
                        dd DESC_DATA_HIGH4

    VIDEO_DESC: dd 0x80000007                       ; 0xB8000 ��0xBFFFFΪ����ģʽ��ʾ�ڴ� �ν���:limit=(0xbffff-0xb8000) / 4k=0x7
                dd DESC_VIDEO_HIGH4                 ; 0xB

    GDT_SIZE:   equ $ - GDT_BASE                    ; ��ǰλ�ü�ȥGDT_BASE�ĵ�ַ ����GDT�Ĵ�С
    GDT_LIMIT:  equ GDT_SIZE - 1                    ; SIZE - 1��Ϊ���ƫ����

    times 60 dq 0                                   ; Ԥ��60�� ������ ��������λ, ���ں�����չ
                                                    
    SELECTOR_CODE  equ (0x0001<<3) + TI_GDT + RPL0  ; ��ѡ����: ��3λΪTI RPL״̬, ����Ϊ����������ֵ
    SELECTOR_DATA  equ (0x0002<<3) + TI_GDT + RPL0  
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

    ; total_mem_bytes���ڱ����ڴ�����,���ֽ�Ϊ��λ,��λ�ñȽϺüǡ�
    ; ��ǰƫ��loader.bin�ļ�ͷ0x200�ֽ�,loader.bin�ļ��ص�ַ��0x900,
    ; ��total_mem_bytes�ڴ��еĵ�ַ��0xb00.�������ں������ǻ����ô˵�ַ
    total_mem_bytes dd 0

    ; gdtָ��, ǰ2�ֽ�Ϊgdt����, ��4�ֽ�Ϊgdt��ʼ��ַ(��48λ)
    gdt_ptr dw GDT_LIMIT
            dd GDT_BASE

    ; �˹�����:total_mem_bytes 4�ֽ� + gdt_ptr 6�ֽ� + ards_buf 244�ֽ� + ards_nr 2�ֽ� , ��256�ֽ�
    ards_buf times 244 db 0             ; ��¼�ڴ��С�Ļ�����
    ards_nr dw 0                        ; ��¼ ARDS �ṹ������


    loader_start:

        ; -------  int 15h eax = 0000E820h ,edx = 534D4150h ('SMAP') ��ȡ�ڴ沼��  -------
        xor ebx, ebx                    ; ��һ�ε��ý�eb��0
        mov edx, 0x534d4150             ; edxֻ��ֵһ�Σ�ѭ�����в���ı�
        mov di,  ards_buf               ; diָ��ARDS������

        .e820_mem_get_loop:             ; ѭ����ȡÿ��ARDS�ڴ淶Χ�����ṹ
            mov eax, 0x0000e820         ; ִ��int 0x15��,eaxֵ��Ϊ0x534d4150, ����ÿ��ִ��intǰ��Ҫ����Ϊ�ӹ��ܺ�
            mov ecx, 20                 ; ARDS��ַ��Χ�������ṹ��С��20�ֽ�
            int 0x15
            jc  .e820_failed_so_try_e801    ; ��cfλΪ1���д�����������0xe801�ӹ���
            add di, cx                  ; ʹdi����20�ֽ�ָ�򻺳������µ�ARDS�ṹλ��
            inc word [ards_nr]          ; ARDS������1
            cmp ebx, 0                  ; �� ebx Ϊ 0 �� cf ��Ϊ 1, ��˵�� ards ȫ�����أ���ǰ�������һ��
            jnz .e820_mem_get_loop      ; ��Ϊ0��ѭ����ȡ

            ; ������ards�ṹ�У��ҳ�(base_add_low + length_low)�����ֵ�����ڴ������
            mov cx, [ards_nr]           ; ����ÿһ��ARDS�ṹ��,ѭ��������ARDS������
            mov ebx, ards_buf
            xor edx, edx                ; ��edx��¼���ֵ, ������������

        .find_max_mem_area:             ; �����ж�type�Ƿ�Ϊ1,�����ڴ��һ���ǿɱ�ʹ��
            mov eax, [ebx]              ; base_add_low
            add eax, [ebx+8]            ; base_add_low + length_low = ���ADRS����
            add ebx, 20                 ; ָ����һ��ARDS
            cmp edx, eax                ; �ҳ����,edx�Ĵ���ʼ���������ڴ�����
            jge .next_ards              ; ���edx>=eax, ����������һ��
            mov edx, eax                ; ���edx<=eax, ����edx
        .next_ards:
            loop .find_max_mem_area
            jmp .mem_get_ok             ; ��ȡ�ڴ���������


        ; ------  int 15h ax = E801h ��ȡ�ڴ��С,���֧��4G  ------
        ; ���غ�, ax cx ֵһ��,��KBΪ��λ,bx dxֵһ��,��64KBΪ��λ
        ; ��ax��cx�Ĵ�����Ϊ��16M,��bx��dx�Ĵ�����Ϊ16MB��4G
        .e820_failed_so_try_e801:
            mov ax, 0xe801
            int 15
            jc .e801_failed_so_try88    ; ����ǰe801����ʧ��,�ͳ���0x88����

            ; 1 �������15M���ڴ�, ax��cx������KBΪ��λ���ڴ�����,����ת��Ϊ��byteΪ��λ
            ; ������eax, ���ڴ�����, ����16λ��edx, ��16λ��eax
            mov cx, 0x400               ; 0x400 = 1024
            mul cx
            shl edx, 16                 ; ����16λ, ����16λ�ŵ�edx��16λ
            and eax, 0x0000FFFF         ; 0x0000FFFF = 1111 1111 1111 1111, ��16λ��0
            or  edx, eax                ; ���������32λ��
            add edx, 0x100000           ; edx��ʵ����1M, ��Ҫ��1MB
            mov esi, edx                ; �Ȱѵ�15MB���ڴ���������esi�Ĵ�������

            ; 2 �ٽ�16MB���ϵ��ڴ�ת��ΪbyteΪ��λ,�Ĵ���bx��dx������64KBΪ��λ���ڴ�����
            xor eax, eax
            mov ax, bx
            mov ecx, 0x10000            ; 0x10000ʮ����Ϊ64KB
            mul ecx                     ; 32λ�˷�,Ĭ�ϵı�������eax, ��Ϊ64λ, ��32λ����edx, ��32λ����eax
            add esi, eax                ; ���ڴ˷���ֻ�ܲ��4G���ڵ��ڴ�, ��32λeax�㹻��, edx�϶�Ϊ0, ֻ��eax���
            mov edx, esi                ; edxΪ���ڴ��С
            jmp .mem_get_ok


        ; -----------------  int 15h ah = 0x88 ��ȡ�ڴ��С,ֻ�ܻ�ȡ64M֮��  ----------
        .e801_failed_so_try88:
            ; int 15��ax���������kbΪ��λ���ڴ�����
            mov  ah, 0x88
            int  0x15
            jc   .error_hlt
            and  eax, 0x0000FFFF

            ; 16λ�˷�����������ax,��Ϊ32λ, ���ĸ�16λ��dx�У����ĵ�16λ��ax��
            mov cx, 0x400               ; 0x400����1024, ��ax�е��ڴ�������Ϊ��byteΪ��λ
            mul cx
            shl edx, 16
            or  edx, eax                ; �ѻ��ĵ�16λ��ϵ�edx,Ϊ32λ�Ļ�
            add edx, 0x100000           ; 0x88�ӹ���ֻ�᷵��1MB���ϵ��ڴ�, ��ʵ���ڴ��СҪ����1MB


        .mem_get_ok:
            mov [total_mem_bytes], edx  ; ���ڴ滻Ϊbyte��λ�����total_mem_bytes��


        ; --------------------------------- ���ý��뱣��ģʽ -----------------------------
        ; 1 ��A20 gate
        ; 2 ����gdt
        ; 3 ��cr0 �� peλ(��0λ)��1

        ; -----------------  ��A20  ----------------
        in al, 0x92                     ; �˿ں�0x92 �еĵ�1λ��� 1 ����
        or al, 0000_0010B
        out 0x92, al

        ; -----------------  ����GDT  ----------------
        lgdt [gdt_ptr]                  ;lgdt 48λ�ڴ����ݱ�ʾ����gdtr

        ; -----------------  cr0��0λ��1  ----------------
        mov eax, cr0
        or eax, 0x00000001
        mov cr0, eax


        ; -------------------------------- �Ѿ��򿪱���ģʽ ---------------------------------------
        jmp dword SELECTOR_CODE:p_mode_start        ; ˢ����ˮ��

        .error_hlt:                     ; ���������
            hlt                         ; ��������ͣ, ֱ�������жϻ�λ�źŲż���

        [bits 32]
        p_mode_start: 
            mov ax, SELECTOR_DATA
            mov ds, ax
            mov es, ax
            mov ss, ax
            mov esp, LOADER_STACK_TOP
            mov ax, SELECTOR_VIDEO
            mov gs, ax
        ;---------------------����kernel-------------------------
        mov eax,KERNEL_START_SECTOR       ;kernel.bin����������
        mov ebx,KERNEL_BIN_BASE_ADDR      ;�Ӵ��̶�����д�뵽ebxָ���ĵ�ַ
        mov ecx,200                       ;�����������

        call rd_disk_m_32                 
        ;--------------------------------------------------------
        ;����ҳĿ¼����ҳ������ʼ��ҳ�ڴ�λͼ
        call setup_page

        ;Ҫ������������ַ��ƫ����д���ڴ�gdt_ptr�У�һ������µ�ַ����
        sgdt [gdt_ptr]                      ;�洢��ԭ��gdt���е�λ��,sgdt���Ի�ȡgdt����λ�ã�������3����0�����У��Ὣgdtr�Ĵ������ݷ���

        ;��Ϊ�ں�������3GB֮�ϣ���ӡ���ܿ϶�Ҫ���ں������У��������û���������Դ�
        ;��gdt����������Ƶ���������еĶλ�ַ+0xc000_0000
        mov ebx,[gdt_ptr+2]                 ;gdtǰ2�ֽ���ƫ��������4�ֽ��ǻ�ַ��������ȡ��gdt��ַ
        or dword [ebx+0x18+4],0xc000_0000
        ;��Ƶ���ǵ�3������������ÿ����������8�ֽڣ���0x18
        ;�������������4�ֽ�������¼�λ�ַ���λ�ַ�ĵ�31-24λ

        ;�޸����Դ������������޸�gdt��ַ�����ǰ�gdtҲ�Ƶ��ں˿ռ���
        ;��gdt�Ļ�ַ����0xc000_0000ʹ���Ϊ�ں����ڵ����λ
        add dword [gdt_ptr+2],0xc000_0000
        add esp,0xc000_0000                 ;��ջָ��ͬ��ӳ�䵽�ں˵�ַ

        ;��ҳĿ¼��ַ����cr3
        mov eax,PAGE_DIR_TABLE_POS
        mov cr3,eax

        ;��cr0��pgλ
        mov eax,cr0
        or eax,0x8000_0000
        mov cr0,eax

        ;�ڿ�����ҳ����gdt�µ�ַ���¼���
        lgdt [gdt_ptr]  ;���¼���

        ;------------��ʱ��ˢ����ˮ��Ҳû��ϵ��Ϊ���Է���һ���Ǽ���
        jmp SELECTOR_CODE:enter_kernel 
        enter_kernel:
            call kernel_init
            mov esp,0xc009_f000
            jmp KERNEL_ENTRY_POINT

;------------------��kernel.bin�е�segment����������ĵ�ַ---------------
kernel_init:        ;ȫ������
    xor eax,eax
    xor ebx,ebx     ;ebx��¼����ͷ����ַ
    xor ecx,ecx     ;cx��¼����ͷ���е�program header����
    xor edx,edx     ;dx��¼program header�ߴ磬��e_phentsize

    mov dx,[KERNEL_BIN_BASE_ADDR + 42]     ;dx = e_phentsize��ƫ���ļ�42�ֽڴ���������e_phentsize����ʾprogram header�Ĵ�С
    mov ebx,[KERNEL_BIN_BASE_ADDR + 28]    ;ebx = e_phoff��ƫ���ļ���ʼ����28�ֽڵĵط���e_phoff����ʾ��һ��program header���ļ��е�ƫ�����������ǽ�e_phoff��ebx������KERNEL_BIN_BASE_ADDR + 28�ĵ�ַ
    add ebx,KERNEL_BIN_BASE_ADDR           ;ebx = KERNEL_BIN_BASE_ADDR + e_phoff = ����ͷ����������ַ
    mov cx,[KERNEL_BIN_BASE_ADDR + 44]     ;cx = e_phnum��ƫ���ļ���ʼ����44�ֽڵĵط���e_phnum����ʾ�м���program header

.each_segment:                      ;����ÿ���Σ�������ǿճ������ͣ����俽��������ĵ�ַ��
    cmp byte [ebx + 0],PT_NULL      ;�������ж��¶������ǲ���PT_NULL����ʾ�ն�����
    je .PTNULL                      ;���p_type = PTNULL(�ճ�������)��˵����program headerδʹ�ã�����ת����һ����ͷ

    ;Ϊ����mem_cpy(dst,src,size)ѹ�����������������������ѹ��
    push dword [ebx + 16]           ;push f_filesz��program header��ƫ��16�ֽڵĵط���p_filesz��ѹ�뺯��memcpy�ĵ���������size
    mov eax,[ebx + 4]               ;eax = p_offset�������ͷƫ����Ϊ4�ֽڵ�λ����p_offset
    add eax,KERNEL_BIN_BASE_ADDR    ;eax = KERNEL_BIN_BASE_ADDR + p_offset = �öε�������ַ������kernel.bin�����ص���������ַ��eaxΪ�öε�������ַ
    push eax                        ;push �öε�������ַ��ѹ��memcpy�ĵڶ���������Դ��ַ
    push dword [ebx + 8]            ;push p_vaddr��ѹ��memcpy�ĵ�һ��������Ŀ�ĵ�ַ��ƫ�Ƴ���ͷ8�ֽڵ�λ����p_vaddr
    call mem_cpy                    ;����mem_cpy��ɶθ���
    add esp,12                      ;����ջ��ѹ�������������ÿ��4B

.PTNULL:
    add ebx,edx                     ;edxΪprogram header��С����e_phentsize;ÿ����һ����ͷ������ת����һ����ͷ��
    loop .each_segment              ;�ڴ�ebxָ����һ��program header
    ret

;------------���ֽڿ���mem_cpy(dst,src,size)-------------
;���룺ջ����������(dst,src,size)
;�������
;-------------------------------------------------------
mem_cpy:
    cld                 ;clean direction����eflags�Ĵ����еķ����־λDF��0������rep��ѭ��ִ�к�����ַ���ָ��ʱ��esi��edi����ʹ�õ��ַ�������ָ��Զ��������������ݵ��ֽڴ�С��
    push ebp
    mov ebp,esp         ;esp��ջ��ָ��
    push ecx            ;repָ���õ���ecx����ecx�������ε�ѭ�������ã���������ջ����
    mov edi,[ebp + 8]   ;dst
    mov esi,[ebp + 12]  ;src
    mov ecx,[ebp + 16]  ;size
    rep movsb           ;���ֽڿ�����movs��ʾmov string��b��ʾbyte��w��ʾword��d��ʾdword����DS:EI/SIָ��ĵ�ַ�����ֽڰ��˵�ES:DI/EIָ��ĵ�ַȥ��
                        ;16λ������Դ��ַָ����SI�Ĵ�����Ŀ�ĵ�ַָ����DI�Ĵ�����32λ������Դ��ַ��SI�Ĵ�����Ŀ�ĵ�ַ��EDI�Ĵ�����

    ;�ָ�����
    pop ecx
    pop ebp
    ret                 ;�ڵ���retʱ��ջ��������������ȷ�ķ��ص�ַ��һ������£������ں������б���push��pop���ʹ�á�


;------------------����ҳĿ¼����ҳ��-------------------
setup_page:
;�Ȱ�ҳĿ¼��ռ�õĿռ���������
    mov ecx,4096                ;4KB��ecx = 0����loopѭ������ֹ����
    mov esi,0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi],0       ;PAGE_DIR_TABLE_POS���ڶ���ҳĿ¼����������ַ
    inc esi                     ;esi++,PAGE_DIR_TABLE_POSΪ��ַ��esiΪ��ַ
    loop .clear_page_dir

;��ʼ����ҳĿ¼�PDE��
.create_pde:                    ;����Page Directory Entry
    mov eax,PAGE_DIR_TABLE_POS  
    add eax,0x1000              ;��ʱeaxΪ��һ��ҳ����λ�ú�����,0x10_1000
    mov ebx,eax                 ;�˴�Ϊebx��ֵ����Ϊ.create_pte��׼����ebx�ǻ�ַ����.create_pte��ʹ��

;���潫ҳĿ¼��0��0xc00����Ϊ��һ��ҳ���ĵ�ַ��ָ��ͬһ��ҳ����ÿ��ҳ����ʾ4MB�ڴ�
;����0xc03f_ffff���µĵ�ַ��0x003f_ffff���µĵ�ַ��ָ����ͬ��ҳ��
;����Ϊ����ַӳ��Ϊ�ں˵�ַ��׼��
    or eax,PG_US_U | PG_RW_W | PG_P         ;ҳĿ¼�������RW��PλΪ1��USΪ1����ʾ�û����ԣ�������Ȩ���𶼿��Է���,�߼������Ϊ0x7
    mov [PAGE_DIR_TABLE_POS + 0x0],eax      ;��һ��Ŀ¼���ҳĿ¼���е�һ��ҳĿ¼��д���һ��ҳ����λ��(0x10_1000)�����ԣ�7��,eax = 0x10_1007
    mov [PAGE_DIR_TABLE_POS + 0xc00],eax    
;һ��ҳ����ռ4B��0xc00��ʾ��768��ҳ��ռ�õ�Ŀ¼�0xc00���ϵ�Ŀ¼�������ں˿ռ䣬Ҳ����ҳ����0xc000_0000-0xffff_ffff����1G�����ں�
;0x0-0xbfff_ffff����3G�����û�����
    sub eax,0x1000                          ;eax = 0x10_0000
    mov [PAGE_DIR_TABLE_POS + 4092],eax     ;ʹ���һ��Ŀ¼��ָ��ҳĿ¼���Լ��ĵ�ַ,4096-4=4092����Ϊһ��Ŀ¼��4B,Ϊ�˽����ܶ�̬����ҳ��

;���洴��ҳ����PTE
;������һ��ҳ��0x10_1000,����������������Χ0-0x3f_ffff֮�������ҳ��Ҳ���������ַ0-0x3f_ffff��0xc000_0000-0xc03f_ffff��Ӧ������ҳ��
    mov ecx,256                             ;��ΪĿǰֻ�õ���1MB�ڴ棬����ֻ������1MB��1M�Ͷ��ڴ�/ÿҳ��С4k = 256ҳ����256��ҳ���һ��Ҫ����256��ҳ��
    mov esi,0
    mov edx,PG_US_U | PG_RW_W | PG_P        ;����Ϊ7��US=1��RW=1��P=1
.create_pte:                                ;����Page Table Entry
    mov [ebx + esi*4],edx                   ;��ҳ������д��ҳ����ַ;��ʱebx�Ѿ�ͨ������eax��ֵΪ0x10_1000��Ҳ���ǵ�һ��ҳ���ĵ�ַ

    add edx,4096                            ;edx + 4KBָ����һ��ҳ������ʼ��ַ���ڶ���ҳ����
    inc esi
    loop .create_pte

;�����ں�����ҳ����PDE�����ں˿ռ��г���0��ҳ�������������ҳ����Ӧ��ҳĿ¼��
    mov eax,PAGE_DIR_TABLE_POS              
    add eax,0x2000                          ;��ʱeaxΪ�ڶ���ҳ����λ��
    or eax,PG_US_U |PG_RW_W |PG_P           ;ҳĿ¼�������US��RW��Pλ����1
    mov ebx,PAGE_DIR_TABLE_POS
    mov ecx,254                             ;��ΧΪ��769-1022������Ŀ¼����������255���Ѿ�ָ����ҳĿ¼������
    mov esi,769
.create_kernel_pde:
    mov [ebx+esi*4],eax                     ;�ӵڶ���ҳĿ¼�ʼд
    inc esi
    add eax,0x1000
    loop .create_kernel_pde
    ret

;��ȡ�ļ����ڴ�
;eax:������ ebx:������ĵ�ַ ecx:�����������
rd_disk_m_32:
    mov esi,eax ;����eax
    mov di,cx   ;����cx
    ;��дӲ��
    ;1.���ô���ȡ��������
    mov dx,0x1f2    ;���ö˿ںţ�dx�����洢�˿ںţ�Ҫд��������������
    mov al,cl 
    out dx,al       ;�������������
    mov eax,esi     ;�ָ�eax
    ;2.��LBA��ַ����0x1f3~0x1f6
    ;LBA 7~0λд��˿�0x1f3
    mov dx,0x1f3
    out dx,al
	
	;LBA 15~8λд��˿�0x1f4
    mov cl,0x08
    shr eax,cl      ;�߼�����8λ����eax�ĵ�8λ�Ƶ���
    mov dx,0x1f4 
    out dx,al 

    ;LBA 24~16λд��˿�0x1f5
    shr eax,cl 
    mov dx,0x1f5 
    out dx,al 

    shr eax,cl 
    and al,0x0f     ;����lba��24~27λ
    or al,0xe0      ;����7~4λ��1110��ʾLBAģʽ
    mov dx,0x1f6
    out dx,al 

    ;3.��0x1f7�˿�д�������0x20
    mov dx,0x1f7
    mov al,0x20 
    out dx,al 

    ;4.���Ӳ��״̬
.not_ready:
    ;ͬд������˿ڣ���ȡʱ��ʾӲ��״̬��д��ʱ������
    nop
    in al,dx 
    and al,0x88     ;��3λ=1��ʾ�Ѿ�׼���ã���7λΪ1��ʾӲ��æ
    cmp al,0x08 
    jnz .not_ready

    ;5.0x1f0�˿ڶ�ȡ����
    mov ax,di       ;Ҫ��ȡ��������
    mov dx,256      ;һ������512B��һ�ζ�ȡ2B����Ҫ��ȡ256��
    mul dx          ;�������ax��
    mov cx,ax       ;Ҫ��ȡ�Ĵ���
    mov dx,0x1f0 
.go_on_read:
    in ax,dx 
    mov [ebx],ax    ;bx��Ҫ��ȡ�����ڴ��ַ
    add ebx,0x02 
    loop .go_on_read;ѭ��cx��
    ret 
