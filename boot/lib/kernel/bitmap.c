#include "bitmap.h"
#include "stdint.h"
#include "../../lib/string.h"
#include "print.h"
#include "interrupt.h"
#include "debug.h"

//将位图btmp初始化
void bitmap_init(struct bitmap* btmp){
	memset(btmp->bits,0,btmp->btmp_bytes_len);
}

//判断bit_idx位是否为1 [修改]
bool bitmap_scan_test(struct bitmap* btmp,uint32_t bit_idx){
	uint32_t byte_idx = bit_idx / 8;
	uint32_t bit_odd = bit_idx % 8;
	return (btmp->bits[byte_idx] & (BITMAP_MASK << bit_odd));
}

//在位图中连续申请cnt个位，成功则返回下标，不成功则返回0
int bitmap_scan(struct bitmap* btmp,uint32_t cnt){
    uint32_t idx_byte = 0;
    //找到空闲的首字节
    while ((btmp->bits[idx_byte] == 0xff) && (idx_byte < btmp->btmp_bytes_len))
        idx_byte++;
    //若idx_byte>len则返回错误，=len则返回-1
    ASSERT(idx_byte <= btmp->btmp_bytes_len);
    if(idx_byte == btmp->btmp_bytes_len)
        return -1;
    //找到空间的首位
    int idx_bit = 0;
    while (btmp->bits[idx_byte] & (uint8_t)(BITMAP_MASK << idx_bit))
        idx_bit++;

    int bit_idx_start = -1;    //返回首地址
    if(cnt == 1){
        bit_idx_start = idx_byte*8 + idx_bit;
        return bit_idx_start;
    }
    uint32_t bit_left = btmp->btmp_bytes_len*8 - (idx_byte*8 + idx_bit);
    uint32_t next_bit = idx_byte*8 + idx_bit + 1;
    uint32_t count = 1;

    while (bit_left--){
        if(!bitmap_scan_test(btmp,next_bit))
            count++;
        else
            count = 0;
        if(count == cnt){
            bit_idx_start = next_bit - cnt + 1;
            break;
        }
        next_bit++;
    }
    return bit_idx_start;   
}

//将位图btmp的bit_idx位设置为value
void bitmap_set(struct bitmap* btmp,uint32_t bit_idx,int8_t value){
    ASSERT((value == 0) | (value == 1));
    uint32_t byte_idx = bit_idx / 8;
    uint32_t bit_odd = bit_idx % 8;
    if(value){
        btmp->bits[byte_idx] |= (BITMAP_MASK << bit_odd);
    }else{
        btmp->bits[byte_idx] &= ~(BITMAP_MASK << bit_odd);
    }
};

