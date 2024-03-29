BUILD_DIR = ./build
##用来存储生成的所有目标文件
ENTRY_POINT = 0xc0001500
AS = nasm
CC = gcc
LD = ld
LIB = -I lib/ -I lib/kernel/ -I lib/user/ -I kernel/ -I device/ -I thread/ -I userprog/ 
ASFLAGS = -f elf
CFLAGS = -Wall -m32 -fno-stack-protector $(LIB) -c -fno-builtin -W -Wstrict-prototypes -Wmissing-prototypes
##-fno-builtin是告诉编译器不要采用内部函数 -Wstrict-prototypes是要求函数声明中必须有参数类型 
## -Wmissing-prototypes要求函数必须有声明
LDFLAGS = -m elf_i386 -Ttext $(ENTRY_POINT) -e main -Map $(BUILD_DIR)/kernel.map
OBJS = $(BUILD_DIR)/main.o $(BUILD_DIR)/init.o $(BUILD_DIR)/interrupt.o \
	$(BUILD_DIR)/timer.o $(BUILD_DIR)/kernel.o $(BUILD_DIR)/print.o $(BUILD_DIR)/debug.o \
	$(BUILD_DIR)/string.o $(BUILD_DIR)/memory.o $(BUILD_DIR)/bitmap.o $(BUILD_DIR)/thread.o \
	$(BUILD_DIR)/switch.o $(BUILD_DIR)/list.o $(BUILD_DIR)/sync.o $(BUILD_DIR)/console.o  \
	$(BUILD_DIR)/keyboard.o $(BUILD_DIR)/ioqueue.o $(BUILD_DIR)/tss.o $(BUILD_DIR)/process.o \
	$(BUILD_DIR)/syscall.o $(BUILD_DIR)/syscall_init.o $(BUILD_DIR)/stdio.o
## OBJS用来存储所有目标文件名，不要用%.o，因为不能保证链接顺序

########## c代码编译 ##########
$(BUILD_DIR)/main.o:kernel/main.c lib/kernel/print.h lib/kernel/stdint.h kernel/init.h kernel/memory.h \
	thread/thread.h kernel/interrupt.h device/console.h device/keyboard.h device/ioqueue.h userprog/process.h \
	userprog/syscall_init.h lib/user/syscall.h lib/stdio.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/init.o:kernel/init.c kernel/init.h lib/kernel/print.h lib/kernel/stdint.h \
	kernel/interrupt.h device/timer.h kernel/memory.h thread/thread.h device/console.h device/keyboard.h \
	userprog/tss.h userprog/syscall_init.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/interrupt.o:kernel/interrupt.c kernel/interrupt.h lib/kernel/stdint.h \
	kernel/global.h lib/kernel/io.h lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/timer.o:device/timer.c device/timer.h lib/kernel/stdint.h lib/kernel/io.h lib/kernel/print.h thread/thread.c \
	kernel/debug.h kernel/interrupt.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/thread.o:thread/thread.c thread/thread.h lib/kernel/stdint.h lib/string.h kernel/global.h kernel/memory.h \
	kernel/interrupt.h lib/kernel/list.h kernel/debug.h lib/kernel/print.h userprog/process.h thread/sync.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/debug.o:kernel/debug.c kernel/debug.h lib/kernel/print.h lib/kernel/stdint.h kernel/interrupt.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/string.o:lib/string.c lib/string.h kernel/debug.h kernel/global.h lib/kernel/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/memory.o:kernel/memory.c kernel/memory.h lib/kernel/stdint.h lib/kernel/bitmap.h kernel/debug.h lib/string.h \
	lib/kernel/print.h kernel/global.h thread/sync.h thread/thread.h kernel/interrupt.h lib/kernel/list.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/bitmap.o:lib/kernel/bitmap.c lib/kernel/bitmap.h lib/string.h kernel/interrupt.h lib/kernel/print.h \
	kernel/debug.h lib/kernel/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/list.o: lib/kernel/list.c lib/kernel/list.h kernel/interrupt.h lib/kernel/stdint.h kernel/debug.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/sync.o: thread/sync.c thread/sync.h lib/kernel/list.h lib/kernel/stdint.h thread/thread.h lib/string.h \
	kernel/interrupt.h kernel/debug.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/console.o: device/console.c device/console.h lib/kernel/print.h lib/kernel/stdint.h thread/sync.h thread/thread.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/keyboard.o: device/keyboard.c device/keyboard.h lib/kernel/print.h lib/kernel/stdint.h kernel/interrupt.h lib/kernel/io.h \
	kernel/global.h device/ioqueue.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/ioqueue.o: device/ioqueue.c device/ioqueue.h lib/kernel/stdint.h kernel/interrupt.h  kernel/debug.h thread/thread.h \
	kernel/global.h thread/sync.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/tss.o: userprog/tss.c userprog/tss.h lib/kernel/stdint.h thread/thread.h lib/kernel/print.h lib/string.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/process.o: userprog/process.c userprog/process.h thread/thread.h userprog/tss.h device/console.h \
	kernel/memory.h kernel/global.h lib/kernel/bitmap.h kernel/interrupt.h lib/kernel/stdint.h kernel/debug.h \
	lib/string.h lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/syscall.o: lib/user/syscall.c lib/user/syscall.h lib/kernel/stdint.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/syscall_init.o: userprog/syscall_init.c userprog/syscall_init.h thread/thread.h lib/user/syscall.h lib/kernel/stdint.h \
	lib/string.h lib/kernel/print.h device/console.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/stdio.o: lib/stdio.c lib/stdio.h lib/kernel/stdint.h lib/string.h lib/user/syscall.h kernel/interrupt.h  \
	lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

###########汇编代码编译############
$(BUILD_DIR)/kernel.o:kernel/kernel.S
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD_DIR)/print.o:lib/kernel/print.S
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD_DIR)/switch.o:thread/switch.S
	$(AS) $(ASFLAGS) $< -o $@

##########链接所有目标文件#############
$(BUILD_DIR)/kernel.bin:$(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

.PHONY: mk_dir hd clean all

mk_dir:
	if [ ! -d $(BUILD_DIR) ]; then mkdir $(BUILD_DIR); fi	
###fi为终止符

hd:	
	dd if=$(BUILD_DIR)/kernel.bin of=/home/lily/bochs/hd60M.img bs=512 count=200 seek=9 conv=notrunc

clean:	##将build目录下文件清空
	cd $(BUILD_DIR) && rm -f ./*

build:$(BUILD_DIR)/kernel.bin	##编译kernel.bin，只要执行make build就是编译文件

all:mk_dir build hd	
##依次执行伪目标mk_dir build hd，只要执行make all就是完成了编译到写入硬盘的全过程
