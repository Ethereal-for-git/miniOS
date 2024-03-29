#ifndef __DEVICE_IOQUEUE_H
#define __DEVICE_IOQUEUE_H
#include "stdint.h"
#include "thread.h"
#include "sync.h"

#define bufsize 64

/*环形队列*/
struct ioqueue{
    //生产者消费者问题
    struct lock lock;
    /*生产者，缓冲区不满时就继续往里面放数据，
    否则就睡眠，此项记录哪个生产者在此缓冲区上睡眠*/
    struct task_struct* producer;

    /*消费者，缓冲区不空时就继续从里面拿数据，
    否则就睡眠，此项记录哪个消费者在此缓冲区上睡眠*/
    struct task_struct* consumer;
    char buf[bufsize];      //缓冲区大小
    int32_t head;           //队首，数据往队首处写入
    int32_t tail;           //队尾，数据从队尾处读出
};

//函数声明
/*判断队列是否已满*/
bool ioq_full(struct ioqueue* ioq);

/*判断队列是否已空*/
bool ioq_empty(struct ioqueue* ioq);

/*初始化io队列ioq*/
void ioqueue_init(struct ioqueue* ioq);

/*消费者ioq队列中获取一个字符*/
char ioq_getchar(struct ioqueue* ioq);

/*生产者往ioq队列中写入一个字节byte*/
void ioq_putchar(struct ioqueue* ioq,char byte);
#endif