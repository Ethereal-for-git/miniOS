#include "string.h"
#include "global.h"
#include "debug.h"

//字符函数
//将dst_其实的size个字节置为value
void memset(void* dst_,uint8_t value,uint32_t size){
	ASSERT(dst_ != NULL);
	uint8_t* dst = (uint8_t*)dst_;	//强制类型转换
	while(size--)
		*dst++ = value;
}

//将src_起始的size个字节复制到dst_
void memcpy(void* dst_,const void* src_,uint32_t size){
	ASSERT(dst_ != NULL && src_ != NULL);
	uint8_t* dst = (uint8_t*)dst_;
	uint8_t* src = (uint8_t*)src_;
	while(size--)
		*dst++ = *src++;
}

//连续比较地址a_和地址b_开头的size个字节，若相等则返回0，大于返回1，小于返回-1
int memcmp(const char* a_,const char* b_,uint32_t size){
	const char* a = a_;
	const char* b = b_;
	ASSERT(a != NULL && b != NULL);
	while(size--){
		if(*a != *b)
			return *a > *b ? 1 : -1;
		a++;
		b++;
	}
	return 0;
}

//字符串函数
//将字符串从src_复制到dst_
//[做了修改]
char* strcpy(char* dst_,const char* src_){
	ASSERT(dst_ != NULL && src_ != NULL);
	char* temp = dst_;
	while((*temp++ = *src_++));
	return dst_;
}

//返回字符串长度
//[做了修改]
uint32_t strlen(const char* str){
	ASSERT(str != NULL);
	uint32_t len = 0;
	const char* p = str;
	while(*p++){
		len++;
	}
	return len;
}

//比较两个字符串
int8_t strcmp(const char* a,const char* b){
	ASSERT(a != NULL && b != NULL);
	while(*a != 0 && *a++ == *b++);
	return *a > *b ? 1 : *a < *b;
}

//从左到右查找字符串str中首次出现的字符ch的地址
char* strchr(const char* str,const uint8_t ch){
	ASSERT(str != NULL );
	while(*str != 0){
		if(*str == ch)
			return (char*)str;
		str++;
	}
	return NULL;
}

//有后向前找字符串str中首次出现字符ch的地址
char* strtchr(const char* str,const uint8_t ch){
	ASSERT(str != NULL);
	char* last_str = NULL;
	while(*str != 0){
		if(*str == ch)
			last_str = (char*)str;
		str++;
	}
	return last_str;
}

//将字符串src_拼接到dst_后，返回拼接的字符串地址
char* strcat(char* dst_,const char* src_){
	ASSERT(dst_ != NULL && src_ != NULL);
	char* p = dst_;
	while(*p++);
	p--;	//消除'\0'
	while((*p++ = *src_++));
	return dst_;
}

//在字符串str中查找字符ch出现的次数
uint32_t strchrs(const char* str,uint8_t ch){
	ASSERT(str != NULL);
	uint32_t cnt = 0;
	while(*str != 0){
		if(*str == ch)
			cnt++;
		str++;
	}
	return cnt;
}