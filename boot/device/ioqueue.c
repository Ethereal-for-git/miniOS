#include "ioqueue.h"
#include "interrupt.h"
#include "global.h"
#include "debug.h"
#define NULL 0

/*初始化io队列ioq*/
void ioqueue_init(struct ioqueue* ioq){
    lock_init(&ioq->lock);                  //初始化io队列的锁
    ioq->producer = ioq->consumer = NULL;   //生产者和消费者置空
    ioq->head = ioq->tail = 0;              //队列的首尾指针指向缓冲区数组第0个位置
}

/*返回pos缓冲区中的下一个位置值*/
static int32_t next_pos(int32_t pos){
    return (pos+1)%bufsize;
}

/*判断队列是否已满*/
bool ioq_full(struct ioqueue* ioq){     //书中是static，但是不能被keyboard.c引用，所以改为非static并声明
    ASSERT(intr_get_status() == INTR_OFF);
    return next_pos(ioq->head) == ioq->tail;
}

/*判断队列是否已空*/
bool ioq_empty(struct ioqueue* ioq){
    ASSERT(intr_get_status() == INTR_OFF);
    return ioq->head == ioq->tail;
}

/*使当前生产者/消费者在此缓冲区上等待*/
static void ioq_wait(struct task_struct** waiter){
    ASSERT(*waiter == NULL && waiter != NULL);
    *waiter = running_thread();
    thread_block(TASK_BLOCKED);
}

/*唤醒waiter*/
static void wakeup(struct task_struct** waiter){
    ASSERT(*waiter != NULL);
    thread_unblock(*waiter);
    *waiter = NULL;
}

/*消费者ioq队列中获取一个字符*/
char ioq_getchar(struct ioqueue* ioq){
    ASSERT(intr_get_status() == INTR_OFF);

    /*若缓冲区（队列）为空，把消费者ioq->consumer记为当前线程自己，
    目的是将来生产者往缓冲区里包装商品后，生产者知道唤醒哪个消费者，
    也就是唤醒当前线程自己*/
    while(ioq_empty(ioq)){
        lock_acquire(&ioq->lock);
        ioq_wait(&ioq->consumer);
        lock_release(&ioq->lock);
    }

    char byte = ioq->buf[ioq->tail];
    ioq->tail = next_pos(ioq->tail);

    if(ioq->producer != NULL)
        wakeup(&ioq->producer);
    return byte;
}

/*生产者往ioq队列中写入一个字节byte*/
void ioq_putchar(struct ioqueue* ioq,char byte){
    ASSERT(intr_get_status() == INTR_OFF);

    /*若缓冲区（队列）满了，把生产者ioq->producer记为自己，
    为的是当缓冲区里的东西被消费者取完后让消费者知道唤醒哪个生产者，
    也就是唤醒当前线程自己*/
    while (ioq_full(ioq))
    {
        lock_acquire(&ioq->lock);
        ioq_wait(&ioq->producer);
        lock_release(&ioq->lock);
    }
    ioq->buf[ioq->head] = byte;
    ioq->head = next_pos(ioq->head);

    if(ioq->consumer != NULL){
        wakeup(&ioq->consumer);
    }
}