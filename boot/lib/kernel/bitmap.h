#ifndef __LIB_KERNEL_BITMAP_H
#define __LIB_KERNEL_BITMAP_H
#include "global.h"
#include "stdint.h"
#define BITMAP_MASK 1	//用来在位图中逐位判断
struct bitmap{
	uint32_t btmp_bytes_len;	//遍历位图时，整体上以字节为单位，细节上以位为单位
	uint8_t* bits;	//数组形式保存位图
};
void bitmap_init(struct bitmap* btmp);
bool bitmap_scan_test(struct bitmap* btmp,uint32_t bit_idx);
int bitmap_scan(struct bitmap* btmp,uint32_t cnt);
void bitmap_set(struct bitmap* btmp,uint32_t bit_idx,int8_t value);
#endif