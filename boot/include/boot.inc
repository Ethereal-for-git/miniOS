;-------------	 loader��kernel   ----------
; loader ���ڴ��е�λ��
LOADER_BASE_ADDR equ 0x900
; loader ��Ӳ���ϵ��߼�������ַ(LBA)
LOADER_START_SECTOR equ 0x2

KERNEL_START_SECTOR equ 0x9
KERNEL_BIN_BASE_ADDR equ 0x70000
KERNEL_ENTRY_POINT equ 0xc000_1500
PT_NULL equ 0

PAGE_DIR_TABLE_POS equ 0x10_0000    ;ҳĿ¼����������ַ����Ϊ�Ͷ�1MB���ڱ�ʾ�ںˣ���0x10_0000�ǳ�1MB��ĵ�ַ
;ҳ��������ԣ�b��ʾ������
PG_P equ 1b                         ;P = 1��ʾ��ҳ�������ڴ���
PG_RW_R equ 00b                     ;RW��ʾ��дλ��0��ʾֻ��
PG_RW_W equ 10b                     ;RW��ʾ��дλ��1��ʾ�ɶ�д
PG_US_S equ 000b                    ;��ʾPTE��PDE��US������S����ʾ�����û�����ҳ���ܱ���Ȩ��Ϊ3�Ľ��̷���
PG_US_U equ 100b                    ;��US������U����ʾ��ͨ�û�����ҳ���Ա����н��̷��� 

;--------------   gdt����������  -------------
; ���»��ߵ����� ��ʵû���κ����� �������Ϊ�˷��� ȷ����ЩλΪ������Ҫ��������ר���õ��»��߷ָ�
DESC_G_4K equ 1_00000000000000000000000b        ; ��23λG ��ʾ4K����1MBλ �ν��޵ĵ�λֵ ��ʱΪ1��Ϊ4k 
DESC_D_32 equ 1_0000000000000000000000b         ; ��22λD/Bλ ��ʾ��ֵַ��32λEIP�Ĵ��� ��������ָ����32λ
DESC_L    equ 0_000000000000000000000b          ; ��21λ ���ó�0��ʾ�����ó�64λ����� ����
DESC_AVL  equ 0_00000000000000000000b           ; ��20λ ���������õ� ����ϵͳ�����ṩ�� �ɲ�����

DESC_LIMIT_CODE2 equ 1111_0000000000000000b     ; ��16-19λ �ν��޵������λ ȫ����ʼ��Ϊ1 ��Ϊ���ν���*���ȱ������0xffffffff
DESC_LIMIT_DATA2 equ DESC_LIMIT_CODE2           ; ���ݶ������ζν�����ͬ
DESC_LIMIT_VIDEO2 equ	0000_0000000000000000b  ; ��16-19λ �Դ��������� VIDEO2 �����ȫ��0Ϊ��λ ��λ���ɱ�ʾ�λ�ַ

DESC_P            equ 	1_000000000000000b	    ; ��15λ  P present�ж϶��Ƿ�������ڴ�  
DESC_DPL_0        equ  00_0000000000000b        ; ��13-14λ Privilege Level 0-3
DESC_DPL_1        equ  01_0000000000000b	    ; 0Ϊ����ϵͳ Ȩ����� 3Ϊ�û��� ���ڱ���
DESC_DPL_2        equ  10_0000000000000b
DESC_DPL_3        equ  11_0000000000000b

DESC_S_sys        equ  0_000000000000b          ; ��12λΪ0 ���ʾϵͳ�� Ϊ1���ʾ���ݶ�
DESC_S_CODE       equ  1_000000000000b          ; ��12λ��type�ֶν�� �ж��Ƿ�Ϊϵͳ�λ������ݶ�
DESC_S_DATA       equ  DESC_S_CODE

;x=1 e=0 w=0 a=0                       
DESC_TYPE_CODE    equ  1000_00000000b           ; ��9-11λ��ʾ�ö�״̬ 1000 ��ִ�� �������ɶ� �ѷ���λ0
;x=0 e=0 w=1 a=0
DESC_TYPE_DATA    equ  0010_00000000b           ; ��9-11λtype��   0010  ��д  

; �������������λ4�ֽڳ�ʼ�� (0x00��8λ <<24 ��32λ��ʼ��0), 0x00 ����16����, һ��ʮ�����ƿɱ�ʾ4��������λ, 0x00��8λ 8+24=36λ 
; 4KBΪ��λ Data��32λ������ ��ʼ���Ĳ��ֶν��� ���Ȩ�޲���ϵͳ����� P���ڱ�ʾ ״̬ 
DESC_CODE_HIGH4   equ (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + \
DESC_P + DESC_DPL_0 + DESC_S_CODE + DESC_TYPE_CODE + 0x00

; ���ݶ���������λ4�ֽڳ�ʼ��
DESC_DATA_HIGH4   equ (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + \
DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x00  

; �Դ����������λ4�ֽڳ�ʼ��
; �Դ����ʼ��ַ��0xb8000, �ڶ���������4�ֽ��жλ�ַ0-15λ�洢����0x8000, ���Զ���������4�ֽ����8λ�Ƕλ�ַ��23-16λ��ֵӦ����0xB
DESC_VIDEO_HIGH4  equ (0x00<<24) + DESC_G_4K + DESC_D_32 + \
DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + \
DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x0B

;-------------------- ѡ�������� --------------------------------
;��0-1λ RPL ��Ȩ���Ƚ��Ƿ���������  ��2λTI 0��ʾGDT 1��ʾLDT    ��3-15λ����ֵ
RPL0    equ 00b
RPL1    equ 01b
RPL2    equ 10b
RPL3    equ 11b
TI_GDT  equ 000b
TI_LDT  equ 100b