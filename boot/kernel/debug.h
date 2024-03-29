#ifndef __KERNEL_DEBUG_H
#define __KERNEL_DEBUG_H
void panic_spin(char *filename,int line,const char* func,const char* condition);
/*_VA_ARGS********************
代表所有与省略号相对应的参数。
"..."表示定义的宏其参数可变*/
#define PANIC(...) panic_spin(__FILE__,__LINE__,__func__,__VA_ARGS__)
/****************************/

#ifdef NDEBUG
	#define ASSERT(CONDITION) ((void)0)	
#else   //CONDITION判断为真，将ASSERT变成0，相当于删除
    #define ASSERT(CONDITION) \
        if(CONDITION){}else{ \
            PANIC(#CONDITION);	\
        }//符号#让编译器将宏的参数转化为字符串字面量
    #endif 
#endif