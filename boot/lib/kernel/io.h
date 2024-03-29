/*机器模式
    b -- 输出寄存器QImode名称，即寄存器的低8位：[a-d]l
    w -- 输出寄存器HImode名称，即寄存器中2字节的部分，如[a-d]x
    HImode
        "Half-Integer"模式，表示一个两字节的整数
    QImode
        "Quarter-Integer"模式，表示一个一字节的整数
*/

#ifndef __LIB_KERNEL_IO_H
#define __LIB_KERNEL_IO_H
#include "stdint.h"

/*向端口port写入一个字节*/
static inline void outb(uint16_t port,uint8_t data){
    /*对端口指定N表示0~255，d表示用dx存储端口号，%b0表示对应al，%w1表示对应dx*/
    //outb：将一个字节的数据从CPU输出到指定的I/O端口
    asm volatile("outb %b0,%w1" : : "a"(data),"Nd"(port));
}

/*将addr处起始的word_cnt个字写入端口port*/
static inline void outsw(uint16_t port,const void* addr,uint32_t word_cnt){
    /*+表示此限制既做输入，又做输出 outsw是把ds:esi处的16位内容写入port端口，我们在设置段描述符时，已经把ds，es，ss段的选择子都设置为相同的值了，此处不用担心数据混乱*/
    asm volatile("cld;rep outsw" : "+S"(addr),"+c"(word_cnt) : "d"(port));
}

/*将从端口port读入一个字节返回*/
static inline uint8_t inb(uint16_t port){
    uint8_t data;
    asm volatile("inb %w1,%b0" : "=a"(data) : "Nd"(port));  //inb：从指定的I/O端口读取一个字节的数据，并将其加载到CPU的寄存器中
    return data;
}

/*将从端口port读入的word_cnt个字写入addr*/
static inline void insw(uint16_t port,void* addr,uint32_t word_cnt){
    /*insw是将端口port处读入的16位内容写入es:edi指向的内存
    因为ds,es,ss处我们设置了数据相同，所以此处不需要担心紊乱*/
    asm volatile("cld;rep insw" : "+D"(addr),"+c"(word_cnt) : "d"(port) : "memory");
}

#endif



