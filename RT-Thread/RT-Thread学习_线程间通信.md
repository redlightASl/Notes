# 线程间通信

裸机编程中经常使用**全局变量进行功能间的通信**（标志）：某些功能由于特定的操作改变全局变量的值，另一个功能对此全局变量进行读取，根据读取到的全局变量执行相应的操作来达到通信协作的目的。RTT提供了邮箱、消息队列和信号等工具来完成这样的类似操作

## 邮箱

邮箱作用过程如下

1. 线程1（发件线程）：获取到外设特定状态并将其作为邮件发送到邮箱
2. 线程2（收件线程）：读取邮箱并执行后续操作

### 邮箱工作机制

邮箱的特点：开销低、效率高、支持一对多

邮箱中一封邮件只能容纳固定的4字节信息（针对32位操作系统，指针大小为4字节，**一封邮件恰好能容纳一个指针**），所以典型的邮箱也被称为**交换消息**

一般如果邮箱中存在邮件且收取邮件时的超时时间为0，邮件的收取过程是非阻塞的；但邮箱中不存在邮件且超时时间不为0时，邮件收取过程就是阻塞的，邮件收取阻塞的情况下只能由线程进行邮件的收取。

邮件发送阻塞：一个线程向邮箱发送邮件时，如果邮箱未满，则把邮件复制到邮箱中，如果邮箱已满，则发送线程挂起并等待邮箱有空间时将其唤醒再发送邮件 或 直接返回-RT_EFULL

邮件接收阻塞：一个线程从邮箱中接收邮件时，如果邮箱已空，接收线程可以挂起直到收到新的邮件被唤醒；也可以设置超时时间并进行等待，如果达到设置的超时时间但邮箱仍未收到邮件时，超时线程将被唤醒并返回-RT_ETIMEOUT；如果邮箱中存在邮件，则接收线程赋值邮箱中的邮件到接收缓存

### 邮箱控制快

RTT使用邮箱控制快管理邮箱，由结构体struct rt_mailbox表示，其指针被封装为邮箱句柄rt_mailbox_t

```c
#ifdef RT_USING_MAILBOX
struct rt_mailbox
{
    struct rt_ipc_object parent;                        /**< 继承自ipc对象，由ipc容器管理 */
    rt_uint32_t         *msg_pool;                      /**< 邮箱缓冲区的开始地址 */
    rt_uint16_t          size;                          /**< 邮箱缓冲区的大小 */
    
    rt_uint16_t          entry;                         /**< 邮箱中邮件的数目 */
    rt_uint16_t          in_offset;                     /**< 邮箱缓冲的进指针 */
    rt_uint16_t          out_offset;                    /**< 邮箱缓冲的出指针 */

    rt_list_t            suspend_sender_thread;         /**< 发送线程的挂起等待队列 */
};
typedef struct rt_mailbox *rt_mailbox_t;
#endif
```

### 邮箱的管理

1. 创建动态邮箱

使用函数接口rt_mb_create()创建动态邮箱对象

```c
rt_mailbox_t rt_mb_create(const char *name,//邮箱名称
                          rt_size_t size,//邮箱大小
                          rt_uint8_t flag)//邮箱标志，可使用RT_IPC_FLAG_FIFO或RT_IPC_FLAG_PRIO
{
    rt_mailbox_t mb;
    RT_DEBUG_NOT_IN_INTERRUPT;

    /* 从内核对象管理器中分配邮箱对象 */
    mb = (rt_mailbox_t)rt_object_allocate(RT_Object_Class_MailBox, name);
    if (mb == RT_NULL)
        return mb;

    /* 设置邮箱标志 */
    mb->parent.parent.flag = flag;

    /* 初始化ipc对象并分配内存 */
    rt_ipc_object_init(&(mb->parent));

    /* 初始化邮箱 */
    mb->size = size;
    mb->msg_pool = RT_KERNEL_MALLOC(mb->size * sizeof(rt_uint32_t));
    if (mb->msg_pool == RT_NULL)//如果未能分配得内存
    {
        /* 删除邮箱对象 */
        rt_object_delete(&(mb->parent.parent));
        return RT_NULL;//返回失败结果
    }
    mb->entry      = 0;//初始化接收邮件数目
    mb->in_offset  = 0;//初始化发送和接收邮件的偏移量
    mb->out_offset = 0;

    /* 初始化发送线程等待队列 */
    rt_list_init(&(mb->suspend_sender_thread));
    return mb;
}
```

邮箱分配得的内存空间大小等于邮件大小（4字节）与邮箱容量的乘积

2. 删除动态邮箱

使用接口rt_mb_delete()永久删除邮箱并释放系统资源

删除时内核会唤醒挂起在该邮箱上的所有线程，然后再释放邮箱使用的内存，最后删除邮箱对象

```c
rt_err_t rt_mb_delete(rt_mailbox_t mb)//输入参数是邮箱对象的句柄
{
    RT_DEBUG_NOT_IN_INTERRUPT;
    /* 检查参数是否合法 */
    RT_ASSERT(mb != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mb->parent.parent) == RT_Object_Class_MailBox);
    RT_ASSERT(rt_object_is_systemobject(&mb->parent.parent) == RT_FALSE);

    /* 唤醒所有挂起的接收线程 */
    rt_ipc_list_resume_all(&(mb->parent.suspend_thread));
    /* 唤醒所有挂起的发送线程 */
    rt_ipc_list_resume_all(&(mb->suspend_sender_thread));

    /* 释放邮箱占用的内存 */
    RT_KERNEL_FREE(mb->msg_pool);
    /* 删除邮箱对象 */
    rt_object_delete(&(mb->parent.parent));
    return RT_EOK;
}

#define RT_KERNEL_FREE(ptr) rt_free(ptr)//用宏定义封装的free()函数
```

3. 初始化静态邮箱

使用接口rt_mb_init()完成静态邮箱对象的初始化

```c
rt_err_t rt_mb_init(rt_mailbox_t mb,//邮箱对象的句柄
                    const char  *name,//邮箱名
                    void        *msgpool,//缓冲区指针
                    rt_size_t    size,//邮箱容量
                    rt_uint8_t   flag)//邮箱标志，可使用RT_IPC_FLAG_FIFO或RT_IPC_FLAG_PRIO
{
    RT_ASSERT(mb != RT_NULL);

    /* 初始化邮箱对象 */
    rt_object_init(&(mb->parent.parent), RT_Object_Class_MailBox, name);
    /* 设置邮箱标志 */
    mb->parent.parent.flag = flag;
    /* 初始化ipc对象并分配内存 */
    rt_ipc_object_init(&(mb->parent));
    /* 初始化邮箱设置 */
    mb->msg_pool   = msgpool;
    mb->size       = size;
    mb->entry      = 0;
    mb->in_offset  = 0;
    mb->out_offset = 0;
    /* 初始化发送线程等待队列 */
    rt_list_init(&(mb->suspend_sender_thread));
    return RT_EOK;
}
```

size参数指定的是邮箱的容量，如果msgpool指向的缓冲区字节数是N，那么邮箱容量size应该是N/4

4. 脱离静态邮箱

使用接口函数rt_mb_detach()将邮箱对象从内核对象管理器中脱离

```c
rt_err_t rt_mb_detach(rt_mailbox_t mb)
{
    /* 检查参数是否合法 */
    RT_ASSERT(mb != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mb->parent.parent) == RT_Object_Class_MailBox);
    RT_ASSERT(rt_object_is_systemobject(&mb->parent.parent));

    /* 唤醒所有挂起的线程 */
    rt_ipc_list_resume_all(&(mb->parent.suspend_thread));
    /* 唤醒所有挂起的发送线程 */
    rt_ipc_list_resume_all(&(mb->suspend_sender_thread));
    /* 脱离邮箱对象 */
    rt_object_detach(&(mb->parent.parent));
    return RT_EOK;
}
```

5. 发送邮件

使用接口rt_mb_send()以**非等待**方式发送邮件

此接口本质上是**等待**方式发送邮件的套皮

```c
rt_err_t rt_mb_send(rt_mailbox_t mb, rt_uint32_t value)
{
    return rt_mb_send_wait(mb, value, 0);
}
```

使用接口rt_mb_send_wait()以等待方式发送邮件

==发送的邮件可以是32位（4字节）任意格式的数据，既可以是整型值也可以是一个指针==

当邮箱中的邮件已满时，发送线程将等待timeout参数设定的时间，如果超时仍没有空出空间，发送线程或中断程序会收到-RT_ETIMEOUT返回值；如果timeout=0，即非等待方式发送邮件，则发送线程或中断程序会直接收到-RT_EFULL的返回值

```c
rt_err_t rt_mb_send_wait(rt_mailbox_t mb,
                         rt_uint32_t  value,
                         rt_int32_t   timeout)
{
    struct rt_thread *thread;
    register rt_ubase_t temp;
    rt_uint32_t tick_delta;
    /* 检查参数是否合法 */
    RT_ASSERT(mb != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mb->parent.parent) == RT_Object_Class_MailBox);

    /* 初始化delta_tick值 */
    tick_delta = 0;
    /* 获取当前线程 */
    thread = rt_thread_self();

    RT_OBJECT_HOOK_CALL(rt_object_put_hook, (&(mb->parent.parent)));//调用钩子函数

    /* 关闭中断 */
    temp = rt_hw_interrupt_disable();
    /* 非等待方式发送邮件 */
    if (mb->entry == mb->size && timeout == 0)//如果邮箱已满
    {
        rt_hw_interrupt_enable(temp);//使能中断
        return -RT_EFULL;
    }
    
    /* 如果邮箱已满 */
    while (mb->entry == mb->size)
    {
        /* 在线程中重置错误标志 */
        thread->error = RT_EOK;
        /* 如果不等待 */
        if (timeout == 0)
        {
            /* 使能中断 */
            rt_hw_interrupt_enable(temp);
            return -RT_EFULL;
        }

        //等待方式发送邮件
        RT_DEBUG_IN_THREAD_CONTEXT;
        /* 挂起当前线程 */
        rt_ipc_list_suspend(&(mb->suspend_sender_thread),
                            thread,
                            mb->parent.parent.flag);

        /* 等待直到超时 */
        if (timeout > 0)
        {
            /* 获得当前定时器值 */
            tick_delta = rt_tick_get();
            RT_DEBUG_LOG(RT_DEBUG_IPC, ("mb_send_wait: start timer of thread:%s\n",
                                        thread->name));//输出debug信息

            /* 重置定时器并重启 */
            rt_timer_control(&(thread->thread_timer),
                             RT_TIMER_CTRL_SET_TIME,
                             &timeout);
            rt_timer_start(&(thread->thread_timer));
        }
        /* 使能中断 */
        rt_hw_interrupt_enable(temp);

        /* 重新执行计划调度 */
        rt_schedule();

        /* 如果出错 */
        if (thread->error != RT_EOK)
        {
            /* 返回错误 */
            return thread->error;
        }

        /* 关闭中断 */
        temp = rt_hw_interrupt_disable();
        /* 如果不是永久等待则重新计算等待时间 */
        if (timeout > 0)
        {
            tick_delta = rt_tick_get() - tick_delta;
            timeout -= tick_delta;
            if (timeout < 0)
                timeout = 0;
        }
    }

    /* 设置邮箱偏移指针 */
    mb->msg_pool[mb->in_offset] = value;
    /* 增加输入偏移 */
    ++ mb->in_offset;
    if (mb->in_offset >= mb->size)//计算邮箱剩余空间
        mb->in_offset = 0;
    /* 增加邮箱内邮件数 */
    mb->entry ++;

    /* 唤醒挂起的线程 */
    if (!rt_list_isempty(&mb->parent.suspend_thread))
    {
        rt_ipc_list_resume(&(mb->parent.suspend_thread));
        /* 使能中断 */
        rt_hw_interrupt_enable(temp);
        rt_schedule();//按既定调度执行
        return RT_EOK;
    }
    /* 使能中断 */
    rt_hw_interrupt_enable(temp);
    return RT_EOK;
}
```

6. 接收邮件

使用接口rt_mb_recv()收取邮箱中的邮件

只有当接受的邮箱中有邮件时，接收者才能立刻收到邮件并返回RT_EOK，否则接收线程会直接返回-RT_ERROR或在接收等待队列挂起timeout的时间，如果超时再返回-RT_ETIMEOUT

```c
rt_err_t rt_mb_recv(rt_mailbox_t mb, rt_uint32_t *value, rt_int32_t timeout)
{
    struct rt_thread *thread;
    register rt_ubase_t temp;
    rt_uint32_t tick_delta;
    /* 检查参数是否合法 */
    RT_ASSERT(mb != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mb->parent.parent) == RT_Object_Class_MailBox);

    /* 初始化delta_tick值 */
    tick_delta = 0;
    /* 获得当前线程 */
    thread = rt_thread_self();

    RT_OBJECT_HOOK_CALL(rt_object_trytake_hook, (&(mb->parent.parent)));//调用钩子函数

    /* 关闭中断 */
    temp = rt_hw_interrupt_disable();

    /* 非阻塞接收情况下，邮箱中没有邮件 */
    if (mb->entry == 0 && timeout == 0)
    {
        rt_hw_interrupt_enable(temp);//使能中断
        return -RT_ETIMEOUT;
    }

    /* 阻塞情况下，邮箱为空 */
    while (mb->entry == 0)
    {
        /* 在线程中重设错误状态 */
        thread->error = RT_EOK;

        /* 不等待则直接返回报错 */
        if (timeout == 0)
        {
            /* 使能中断 */
            rt_hw_interrupt_enable(temp);
            thread->error = -RT_ETIMEOUT;
            return -RT_ETIMEOUT;
        }

        RT_DEBUG_IN_THREAD_CONTEXT;
        /* 如果有等待时间则挂起当前线程 */
        rt_ipc_list_suspend(&(mb->parent.suspend_thread),
                            thread,
                            mb->parent.parent.flag);

        /* 启动线程定时器 */
        if (timeout > 0)
        {
            /* 获得定时器时间 */
            tick_delta = rt_tick_get();

            RT_DEBUG_LOG(RT_DEBUG_IPC, ("mb_recv: start timer of thread:%s\n",
                                        thread->name));

            /* 重设定时器定时时间并重启定时器 */
            rt_timer_control(&(thread->thread_timer),
                             RT_TIMER_CTRL_SET_TIME,
                             &timeout);
            rt_timer_start(&(thread->thread_timer));
        }
        /* 使能中断 */
        rt_hw_interrupt_enable(temp);
        /* 按原有调度进行 */
        rt_schedule();
        /* 如果意外从挂起状态唤醒 */
        if (thread->error != RT_EOK)
        {
            /* 返回错误 */
            return thread->error;
        }

        /* 关闭中断 */
        temp = rt_hw_interrupt_disable();

        /* 如果不是永久等待模式则重置定时器 */
        if (timeout > 0)
        {
            tick_delta = rt_tick_get() - tick_delta;
            timeout -= tick_delta;
            if (timeout < 0)
                timeout = 0;
        }
    }

    /* 更改邮箱偏移指针 */
    *value = mb->msg_pool[mb->out_offset];

    /* 增加出指针偏移 */
    ++ mb->out_offset;
    if (mb->out_offset >= mb->size)
        mb->out_offset = 0;
    /* 减少邮箱中邮件的数量 */
    mb->entry --;

    /* 唤醒挂起的发送线程 */
    if (!rt_list_isempty(&(mb->suspend_sender_thread)))
    {
        rt_ipc_list_resume(&(mb->suspend_sender_thread));
        /* 使能中断 */
        rt_hw_interrupt_enable(temp);
        RT_OBJECT_HOOK_CALL(rt_object_take_hook, (&(mb->parent.parent)));
        rt_schedule();//按既定调度执行
        return RT_EOK;
    }

    /* 使能中断 */
    rt_hw_interrupt_enable(temp);
    RT_OBJECT_HOOK_CALL(rt_object_take_hook, (&(mb->parent.parent)));
    return RT_EOK;
}
```

### 邮箱的使用场景

对于复杂（占用内存较大）的信息，可设置一个指向它的指针，并将指针作为邮件发送出去

**==注意：接收完毕后一定将指针和消息占用的内存释放！！！==**

邮箱使用较广，局限性在于发送大量数据时不方便

## 消息队列

消息队列是邮箱的扩展，能够接收来自线程或中断服务例程中不固定长度的消息，并把消息缓存在自己的内存空间中，其他线程也能从消息队列中读取相应的消息。

### 消息队列的工作机制

消息队列空时，可以挂起读取线程，当有新的消息到达时再将挂起的线程唤醒以接收并处理消息

**消息队列是一种异步通信方式**

消息队列是一个“队列”，采取先入先出（FIFO）原则

消息队列对象由多个元素组成：消息队列控制块、消息框、空闲消息框链表

一个消息队列对象包含多个消息框，一个消息框可以存放一条消息

消息链表头：消息队列中第一个消息框，对应msg_queue_head

消息链表尾：消息队列中最后一个消息框，对应msg_queue_tail

空闲消息框链表：由空的消息框通过msg_queue_free形成的链表

**所有消息队列中的消息框总数就是消息队列的长度**

### 消息队列控制块

RTT通过消息队列控制块管理消息队列，其指针被封装为了句柄，通常调用其句柄

```c
#ifdef RT_USING_MESSAGEQUEUE//需要定义RT_USING_MESSAGEQUEUE才能使用消息队列
struct rt_messagequeue
{
    struct rt_ipc_object parent;                        /**< 继承自ipc对象，由IPC容器管理 */
    void                *msg_pool;                      /**< 指向存放消息缓冲区的指针 */
    rt_uint16_t          msg_size;                      /**< 每个消息的长度 */
    rt_uint16_t          max_msgs;                      /**< 最大能容纳的消息数 */
    rt_uint16_t          entry;                         /**< 队列中已有的消息数 */

    void                *msg_queue_head;                /**< 消息链表头 */
    void                *msg_queue_tail;                /**< 消息链表尾 */
    void                *msg_queue_free;                /**< 空闲消息链表 */
};
typedef struct rt_messagequeue *rt_mq_t;//将消息队列控制块的指针封装为其句柄
#endif
```

### 消息队列的管理

以下内容基本和邮箱相同，不再翻译注释

1. 初始化和脱离静态消息队列

初始化

```c
rt_err_t rt_mq_init(rt_mq_t     mq,//消息队列对象句柄
                    const char *name,//消息队列名称
                    void       *msgpool,//指向存放消息缓冲区的指针
                    rt_size_t   msg_size,//消息队列中一条消息的最大长度，单位：字节
                    rt_size_t   pool_size,//存放消息的缓冲区大小
                    rt_uint8_t  flag)//消息队列采用的等待方式，可设置为RT_IPC_FLAG_FIFO或RT_IPC_FLAG_PRIO
{
    struct rt_mq_message *head;
    register rt_base_t temp;

    /* parameter check */
    RT_ASSERT(mq != RT_NULL);
    /* init object */
    rt_object_init(&(mq->parent.parent), RT_Object_Class_MessageQueue, name);
    /* set parent flag */
    mq->parent.parent.flag = flag;
    /* init ipc object */
    rt_ipc_object_init(&(mq->parent));
    /* set messasge pool */
    mq->msg_pool = msgpool;
    /* get correct message size */
    mq->msg_size = RT_ALIGN(msg_size, RT_ALIGN_SIZE);
    mq->max_msgs = pool_size / (mq->msg_size + sizeof(struct rt_mq_message));
    /* init message list */
    mq->msg_queue_head = RT_NULL;
    mq->msg_queue_tail = RT_NULL;
    /* init message empty list */
    mq->msg_queue_free = RT_NULL;
    for (temp = 0; temp < mq->max_msgs; temp ++)
    {
        head = (struct rt_mq_message *)((rt_uint8_t *)mq->msg_pool +
                                        temp * (mq->msg_size + sizeof(struct rt_mq_message)));
        head->next = mq->msg_queue_free;
        mq->msg_queue_free = head;
    }
    /* the initial entry is zero */
    mq->entry = 0;
    return RT_EOK;
}
```

脱离

```c
rt_err_t rt_mq_detach(rt_mq_t mq)
{
    /* parameter check */
    RT_ASSERT(mq != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mq->parent.parent) == RT_Object_Class_MessageQueue);
    RT_ASSERT(rt_object_is_systemobject(&mq->parent.parent));
    /* resume all suspended thread */
    rt_ipc_list_resume_all(&mq->parent.suspend_thread);
    /* detach message queue object */
    rt_object_detach(&(mq->parent.parent));
    return RT_EOK;
}
```

2. 创建和删除动态消息队列

创建

==**注意：为消息队列对象（空闲消息链表）分配的内存大小=[消息大小+消息头大小]*消息队列中消息的最大个数**==

其中消息头用于链表之间的连接（指针域）

```c
rt_mq_t rt_mq_create(const char *name,//消息队列名称
                     rt_size_t   msg_size,//消息队列中一条消息的最大长度，单位：字节
                     rt_size_t   max_msgs,//消息队列中消息的最大个数
                     rt_uint8_t  flag)//消息队列采用的等待方式，可设置为RT_IPC_FLAG_FIFO或RT_IPC_FLAG_PRIO
{
    struct rt_messagequeue *mq;
    struct rt_mq_message *head;
    register rt_base_t temp;

    RT_DEBUG_NOT_IN_INTERRUPT;

    /* allocate object */
    mq = (rt_mq_t)rt_object_allocate(RT_Object_Class_MessageQueue, name);
    if (mq == RT_NULL)
        return mq;
    /* set parent */
    mq->parent.parent.flag = flag;
    /* init ipc object */
    rt_ipc_object_init(&(mq->parent));
    
    /* init message queue */
    /* get correct message size */
    mq->msg_size = RT_ALIGN(msg_size, RT_ALIGN_SIZE);
    mq->max_msgs = max_msgs;
    /* allocate message pool */
    mq->msg_pool = RT_KERNEL_MALLOC((mq->msg_size + sizeof(struct rt_mq_message)) * mq->max_msgs);
    if (mq->msg_pool == RT_NULL)
    {
        rt_mq_delete(mq);
        return RT_NULL;
    }

    /* init message list */
    mq->msg_queue_head = RT_NULL;
    mq->msg_queue_tail = RT_NULL;
    /* init message empty list */
    mq->msg_queue_free = RT_NULL;
    for (temp = 0; temp < mq->max_msgs; temp ++)
    {
        head = (struct rt_mq_message *)((rt_uint8_t *)mq->msg_pool +
                                        temp * (mq->msg_size + sizeof(struct rt_mq_message)));
        head->next = mq->msg_queue_free;
        mq->msg_queue_free = head;
    }

    /* the initial entry is zero */
    mq->entry = 0;
    return mq;
}
```

删除

```c
rt_err_t rt_mq_delete(rt_mq_t mq)
{
    RT_DEBUG_NOT_IN_INTERRUPT;

    /* parameter check */
    RT_ASSERT(mq != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mq->parent.parent) == RT_Object_Class_MessageQueue);
    RT_ASSERT(rt_object_is_systemobject(&mq->parent.parent) == RT_FALSE);

    /* resume all suspended thread */
    rt_ipc_list_resume_all(&(mq->parent.suspend_thread));

    /* free message queue pool */
    RT_KERNEL_FREE(mq->msg_pool);

    /* delete message queue object */
    rt_object_delete(&(mq->parent.parent));

    return RT_EOK;
}
```

3. 发送消息

线程或中断服务程序都能给消息队列发送消息，发送时，消息队列对象先从空闲消息链表上**取下一个空闲消息块**，把消息内容**复制**到该消息块上，再把该消息块**挂到消息队列尾部**。当且仅当空闲消息链表上由可用的空闲消息块时，发送者才能成功发送消息；若空闲消息链表上无可用消息块，说明消息队列已满，再发送消息会收到错误码-RT_EFULL

使用接口rt_mq_send()发送消息

发送时需要制定发送的消息队列句柄、发送的消息内容、消息大小(可以考虑用sizeof运算符获取)

==注意：再发送一个普通消息后，空闲消息链表上的队首消息被转移到消息队列尾==

可以使用rt_mq_send_wait()接口无等待时间地发送消息，本质上也是个套皮的rt_mq_send()

```c
rt_err_t rt_mq_send(rt_mq_t mq, void *buffer, rt_size_t size)
{
    register rt_ubase_t temp;
    struct rt_mq_message *msg;

    /* parameter check */
    RT_ASSERT(mq != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mq->parent.parent) == RT_Object_Class_MessageQueue);
    RT_ASSERT(buffer != RT_NULL);
    RT_ASSERT(size != 0);

    /* greater than one message size */
    if (size > mq->msg_size)
        return -RT_ERROR;

    RT_OBJECT_HOOK_CALL(rt_object_put_hook, (&(mq->parent.parent)));

    /* disable interrupt */
    temp = rt_hw_interrupt_disable();
    /* get a free list, there must be an empty item */
    msg = (struct rt_mq_message *)mq->msg_queue_free;
    /* message queue is full */
    if (msg == RT_NULL)
    {
        /* enable interrupt */
        rt_hw_interrupt_enable(temp);

        return -RT_EFULL;
    }
    /* move free list pointer */
    mq->msg_queue_free = msg->next;
    /* enable interrupt */
    rt_hw_interrupt_enable(temp);
    /* the msg is the new tailer of list, the next shall be NULL */
    msg->next = RT_NULL;
    /* copy buffer */
    rt_memcpy(msg + 1, buffer, size);
    /* disable interrupt */
    temp = rt_hw_interrupt_disable();
    /* link msg to message queue */
    if (mq->msg_queue_tail != RT_NULL)
    {
        /* if the tail exists, */
        ((struct rt_mq_message *)mq->msg_queue_tail)->next = msg;
    }

    /* set new tail */
    mq->msg_queue_tail = msg;
    /* if the head is empty, set head */
    if (mq->msg_queue_head == RT_NULL)
        mq->msg_queue_head = msg;
    /* increase message entry */
    mq->entry ++;

    /* resume suspended thread */
    if (!rt_list_isempty(&mq->parent.suspend_thread))
    {
        rt_ipc_list_resume(&(mq->parent.suspend_thread));

        /* enable interrupt */
        rt_hw_interrupt_enable(temp);

        rt_schedule();

        return RT_EOK;
    }

    /* enable interrupt */
    rt_hw_interrupt_enable(temp);
    return RT_EOK;
}
```

特别地可以发送**==紧急消息==**

发送紧急消息时，从空闲消息链表上去下的消息块不会被挂到消息队列队尾，而是挂到队首

一般情况下**接收者总是能优先接收到紧急消息**

```c
rt_err_t rt_mq_urgent(rt_mq_t mq, void *buffer, rt_size_t size)
{
    register rt_ubase_t temp;
    struct rt_mq_message *msg;

    /* parameter check */
    RT_ASSERT(mq != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mq->parent.parent) == RT_Object_Class_MessageQueue);
    RT_ASSERT(buffer != RT_NULL);
    RT_ASSERT(size != 0);

    /* greater than one message size */
    if (size > mq->msg_size)
        return -RT_ERROR;

    RT_OBJECT_HOOK_CALL(rt_object_put_hook, (&(mq->parent.parent)));

    /* disable interrupt */
    temp = rt_hw_interrupt_disable();

    /* get a free list, there must be an empty item */
    msg = (struct rt_mq_message *)mq->msg_queue_free;
    /* message queue is full */
    if (msg == RT_NULL)
    {
        /* enable interrupt */
        rt_hw_interrupt_enable(temp);

        return -RT_EFULL;
    }
    /* move free list pointer */
    mq->msg_queue_free = msg->next;

    /* enable interrupt */
    rt_hw_interrupt_enable(temp);

    /* copy buffer */
    rt_memcpy(msg + 1, buffer, size);

    /* disable interrupt */
    temp = rt_hw_interrupt_disable();

    /* 这里把消息块挂到了队首 */
    msg->next = mq->msg_queue_head;
    mq->msg_queue_head = msg;

    /* if there is no tail */
    if (mq->msg_queue_tail == RT_NULL)
        mq->msg_queue_tail = msg;

    /* increase message entry */
    mq->entry ++;

    /* resume suspended thread */
    if (!rt_list_isempty(&mq->parent.suspend_thread))
    {
        rt_ipc_list_resume(&(mq->parent.suspend_thread));

        /* enable interrupt */
        rt_hw_interrupt_enable(temp);

        rt_schedule();

        return RT_EOK;
    }

    /* enable interrupt */
    rt_hw_interrupt_enable(temp);

    return RT_EOK;
}
```

4. 接收消息

当消息队列中有消息时，接收者接收消息；否则会根据超时时间设置，挂在等待线程队列上火直接返回

```c
rt_err_t rt_mq_recv(rt_mq_t    mq,//消息队列对象句柄
                    void      *buffer,//消息内容缓存区
                    rt_size_t  size,//消息大小
                    rt_int32_t timeout)//指定超时时间
{
    struct rt_thread *thread;
    register rt_ubase_t temp;
    struct rt_mq_message *msg;
    rt_uint32_t tick_delta;

    /* parameter check */
    RT_ASSERT(mq != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mq->parent.parent) == RT_Object_Class_MessageQueue);
    RT_ASSERT(buffer != RT_NULL);
    RT_ASSERT(size != 0);

    /* initialize delta tick */
    tick_delta = 0;
    /* get current thread */
    thread = rt_thread_self();
    RT_OBJECT_HOOK_CALL(rt_object_trytake_hook, (&(mq->parent.parent)));

    /* disable interrupt */
    temp = rt_hw_interrupt_disable();

    /* for non-blocking call */
    if (mq->entry == 0 && timeout == 0)
    {
        rt_hw_interrupt_enable(temp);

        return -RT_ETIMEOUT;
    }

    /* message queue is empty */
    while (mq->entry == 0)
    {
        RT_DEBUG_IN_THREAD_CONTEXT;

        /* reset error number in thread */
        thread->error = RT_EOK;

        /* no waiting, return timeout */
        if (timeout == 0)
        {
            /* enable interrupt */
            rt_hw_interrupt_enable(temp);

            thread->error = -RT_ETIMEOUT;

            return -RT_ETIMEOUT;
        }

        /* suspend current thread */
        rt_ipc_list_suspend(&(mq->parent.suspend_thread),
                            thread,
                            mq->parent.parent.flag);

        /* has waiting time, start thread timer */
        if (timeout > 0)
        {
            /* get the start tick of timer */
            tick_delta = rt_tick_get();

            RT_DEBUG_LOG(RT_DEBUG_IPC, ("set thread:%s to timer list\n",
                                        thread->name));

            /* reset the timeout of thread timer and start it */
            rt_timer_control(&(thread->thread_timer),
                             RT_TIMER_CTRL_SET_TIME,
                             &timeout);
            rt_timer_start(&(thread->thread_timer));
        }

        /* enable interrupt */
        rt_hw_interrupt_enable(temp);

        /* re-schedule */
        rt_schedule();

        /* recv message */
        if (thread->error != RT_EOK)
        {
            /* return error */
            return thread->error;
        }

        /* disable interrupt */
        temp = rt_hw_interrupt_disable();

        /* if it's not waiting forever and then re-calculate timeout tick */
        if (timeout > 0)
        {
            tick_delta = rt_tick_get() - tick_delta;
            timeout -= tick_delta;
            if (timeout < 0)
                timeout = 0;
        }
    }

    /* get message from queue */
    msg = (struct rt_mq_message *)mq->msg_queue_head;

    /* move message queue head */
    mq->msg_queue_head = msg->next;
    /* reach queue tail, set to NULL */
    if (mq->msg_queue_tail == msg)
        mq->msg_queue_tail = RT_NULL;

    /* decrease message entry */
    mq->entry --;

    /* enable interrupt */
    rt_hw_interrupt_enable(temp);

    /* copy message */
    rt_memcpy(buffer, msg + 1, size > mq->msg_size ? mq->msg_size : size);

    /* disable interrupt */
    temp = rt_hw_interrupt_disable();
    /* put message to free list */
    msg->next = (struct rt_mq_message *)mq->msg_queue_free;
    mq->msg_queue_free = msg;
    /* enable interrupt */
    rt_hw_interrupt_enable(temp);

    RT_OBJECT_HOOK_CALL(rt_object_take_hook, (&(mq->parent.parent)));

    return RT_EOK;
}
```


```c
struct rt_mq_message//消息队列消息块的组成：本质就是个链表
{
    struct rt_mq_message *next;
};
```


### 消息队列的使用场景

1. 发送消息

消息队列可以发送较大的消息，能够直接通过缓存区接收这些大消息，免去了动态内存分配的麻烦

可以在资源充裕的情况下处理复杂的通信问题

2. 同步消息

两个线程间可以采用**【消息队列+信号量/邮箱】**的形式实现发送同步消息：发送线程将消息直接发送给消息队列，发送完毕后等待接收线程的收到确认，将**邮箱的返回信号**作为确认标志或将**信号量**作为确认标志**封装进消息块**，就可以让接收线程收到消息的同时唤醒挂起在邮箱或信号量等待队列上的线程，达到线程间同步通信的效果

## 信号

信号又称为**软中断信号**，不等同于信号量。信号时对硬件中断的软件模拟

### 信号的工作机制

RTT使用信号进行线程间异步通信

POSIX标准定义sigset_t类型定义信号集，RTT中将sigset_t定义为unsigned long类型即32位无符号整型，并命名为rt_sigset_t

应用程序能使用的信号为SGUSR1(10)和SIGUSR2(12)

一个线程不必通过任何操作来等待信号到达，线程之间可以互相调用rt_thread_kill()发送软中断信号(类似unix/linux中的kill)

### 对信号的处理方式

1. 中断：线程指定处理函数，由该信号中断服务函数来处理**信号中断**
2. 忽略信号
3. 保留系统默认值

一个信号被传递给某线程时，如果它正处于阻塞态，则将状态变为就绪态进行处理信号；如果正处于运行态，则会在它当前的线程栈基础上建立新的栈空间去处理对应信号

此时==它使用的线程栈大小也会相应增加==

### 信号的管理

1. 安装信号

**在某线程中安装某信号代表该线程会响应该信号**，相当于给线程装了个“信号雷达”，他会“主动捕捉”响应特定的信号

信号值signo只能被设定为SGUSR1或SIGUSR2

handler时信号对应的处理函数指针（回调函数），可以设为**用户中断服务函数指针**、**SIG_IGN（忽略某个信号）**、**SIG_DFL（调用系统默认中断处理函数_signal_default_handler()）**

```c
rt_sighandler_t rt_signal_install(int signo, rt_sighandler_t handler)
{
    rt_sighandler_t old = RT_NULL;
    rt_thread_t tid = rt_thread_self();

    if (!sig_valid(signo))
        return SIG_ERR;

    rt_enter_critical();
    if (tid->sig_vectors == RT_NULL)
    {
        rt_thread_alloc_sig(tid);
    }
    if (tid->sig_vectors)
    {
        old = tid->sig_vectors[signo];

        if (handler == SIG_IGN)
            tid->sig_vectors[signo] = RT_NULL;
        else if (handler == SIG_DFL)
            tid->sig_vectors[signo] = _signal_default_handler;
        else
            tid->sig_vectors[signo] = handler;
    }
    rt_exit_critical();
    return old;
}
```

```c
void rt_thread_handle_sig(rt_bool_t clean_state)
{
    rt_base_t level;
    rt_thread_t tid = rt_thread_self();
    struct siginfo_node *si_node;
    level = rt_hw_interrupt_disable();
    if (tid->sig_pending & tid->sig_mask)
    {
        /* if thread is not waiting for signal */
        if (!(tid->stat & RT_THREAD_STAT_SIGNAL_WAIT))
        {
            while (tid->sig_pending & tid->sig_mask)
            {
                int signo, error;
                rt_sighandler_t handler;

                si_node = (struct siginfo_node *)tid->si_list;
                if (!si_node)
                    break;
                /* remove this sig info node from list */
                if (si_node->list.next == RT_NULL)
                    tid->si_list = RT_NULL;
                else
                    tid->si_list = (void *)rt_slist_entry(si_node->list.next, struct siginfo_node, list);
                signo   = si_node->si.si_signo;
                handler = tid->sig_vectors[signo];
                rt_hw_interrupt_enable(level);
                dbg_log(DBG_LOG, "handle signal: %d, handler 0x%08x\n", signo, handler);
                if (handler)
                    handler(signo);
                level = rt_hw_interrupt_disable();
                tid->sig_pending &= ~sig_mask(signo);
                error = -RT_EINTR;
                rt_mp_free(si_node); /* release this siginfo node */
                /* set errno in thread tcb */
                tid->error = error;
            }
            /* whether clean signal status */
            if (clean_state == RT_TRUE) tid->stat &= ~RT_THREAD_STAT_SIGNAL;
        }
    }

    rt_hw_interrupt_enable(level);
}
```

2. 阻塞信号

阻塞信号即“屏蔽信号”，线程会彻底听不见信号

```c
void rt_signal_mask(int signo)
{
    rt_base_t level;
    rt_thread_t tid = rt_thread_self();
    level = rt_hw_interrupt_disable();
    tid->sig_mask &= ~sig_mask(signo);
    rt_hw_interrupt_enable(level);
}
```

3. 解除阻塞

```c
void rt_signal_unmask(int signo)
{
    rt_base_t level;
    rt_thread_t tid = rt_thread_self();
    level = rt_hw_interrupt_disable();
    tid->sig_mask |= sig_mask(signo);
    /* let thread handle pended signals */
    if (tid->sig_mask & tid->sig_pending)
    {
        rt_hw_interrupt_enable(level);
        _signal_deliver(tid);
    }
    else
    {
        rt_hw_interrupt_enable(level);
    }
}
```

4. 发送信号

调用接口rt_thread_kill()向某线程tid发送某信号，信号值sig决定了发送的是1号信号还是2号信号

```c
int rt_thread_kill(rt_thread_t tid, int sig)
{
    siginfo_t si;
    rt_base_t level;
    struct siginfo_node *si_node;

    RT_ASSERT(tid != RT_NULL);
    if (!sig_valid(sig)) return -RT_EINVAL;

    dbg_log(DBG_INFO, "send signal: %d\n", sig);
    si.si_signo = sig;
    si.si_code  = SI_USER;
    si.si_value.sival_ptr = RT_NULL;

    level = rt_hw_interrupt_disable();
    if (tid->sig_pending & sig_mask(sig))
    {
        /* whether already emits this signal? */
        struct rt_slist_node *node;
        struct siginfo_node  *entry;

        node = (struct rt_slist_node *)tid->si_list;
        rt_hw_interrupt_enable(level);

        /* update sig info */
        rt_enter_critical();
        for (; (node) != RT_NULL; node = node->next)
        {
            entry = rt_slist_entry(node, struct siginfo_node, list);
            if (entry->si.si_signo == sig)
            {
                memcpy(&(entry->si), &si, sizeof(siginfo_t));
                rt_exit_critical();
                return 0;
            }
        }
        rt_exit_critical();

        /* disable interrupt to protect tcb */
        level = rt_hw_interrupt_disable();
    }
    else
    {
        /* a new signal */
        tid->sig_pending |= sig_mask(sig);
    }
    rt_hw_interrupt_enable(level);

    si_node = (struct siginfo_node *) rt_mp_alloc(_rt_siginfo_pool, 0);
    if (si_node)
    {
        rt_slist_init(&(si_node->list));
        memcpy(&(si_node->si), &si, sizeof(siginfo_t));

        level = rt_hw_interrupt_disable();
        if (!tid->si_list) tid->si_list = si_node;
        else
        {
            struct siginfo_node *si_list;

            si_list = (struct siginfo_node *)tid->si_list;
            rt_slist_append(&(si_list->list), &(si_node->list));
        }
        rt_hw_interrupt_enable(level);
    }
    else
    {
        dbg_log(DBG_ERROR, "The allocation of signal info node failed.\n");
    }

    /* deliver signal to this thread */
    _signal_deliver(tid);
    return RT_EOK;
}
```

5. 等待信号

等待set信号的到来，如果没有等到则将信号挂起，直到等到信号或等待超时；如果等到了该信号，则将指向该信号体的指针存入si

```c
int rt_signal_wait(const rt_sigset_t *set,//等待的信号
                   rt_siginfo_t *si,//指向存储等到信号信息的指针
                   rt_int32_t timeout)//超时时间
{
    int ret = RT_EOK;
    rt_base_t   level;
    rt_thread_t tid = rt_thread_self();
    struct siginfo_node *si_node = RT_NULL, *si_prev = RT_NULL;

    /* current context checking */
    RT_DEBUG_IN_THREAD_CONTEXT;

    /* parameters check */
    if (set == NULL || *set == 0 || si == NULL )
    {
        ret = -RT_EINVAL;
        goto __done_return;
    }

    /* clear siginfo to avoid unknown value */
    memset(si, 0x0, sizeof(rt_siginfo_t));

    level = rt_hw_interrupt_disable();

    /* already pending */
    if (tid->sig_pending & *set) goto __done;

    if (timeout == 0)
    {
        ret = -RT_ETIMEOUT;
        goto __done_int;
    }

    /* suspend self thread */
    rt_thread_suspend(tid);
    /* set thread stat as waiting for signal */
    tid->stat |= RT_THREAD_STAT_SIGNAL_WAIT;

    /* start timeout timer */
    if (timeout != RT_WAITING_FOREVER)
    {
        /* reset the timeout of thread timer and start it */
        rt_timer_control(&(tid->thread_timer),
                         RT_TIMER_CTRL_SET_TIME,
                         &timeout);
        rt_timer_start(&(tid->thread_timer));
    }
    rt_hw_interrupt_enable(level);

    /* do thread scheduling */
    rt_schedule();

    level = rt_hw_interrupt_disable();

    /* remove signal waiting flag */
    tid->stat &= ~RT_THREAD_STAT_SIGNAL_WAIT;

    /* check errno of thread */
    if (tid->error == -RT_ETIMEOUT)
    {
        tid->error = RT_EOK;
        rt_hw_interrupt_enable(level);

        /* timer timeout */
        ret = -RT_ETIMEOUT;
        goto __done_return;
    }

__done:
    /* to get the first matched pending signals */
    si_node = (struct siginfo_node *)tid->si_list;
    while (si_node)
    {
        int signo;

        signo = si_node->si.si_signo;
        if (sig_mask(signo) & *set)
        {
            *si  = si_node->si;

            dbg_log(DBG_LOG, "sigwait: %d sig raised!\n", signo);
            if (si_prev) si_prev->list.next = si_node->list.next;
            else tid->si_list = si_node->list.next;

            /* clear pending */
            tid->sig_pending &= ~sig_mask(signo);
            rt_mp_free(si_node);
            break;
        }

        si_prev = si_node;
        si_node = (void *)rt_slist_entry(si_node->list.next, struct siginfo_node, list);
     }

__done_int:
    rt_hw_interrupt_enable(level);

__done_return:
    return ret;
}
```

### 信号的使用场景

一般信号就当中断用，步骤如下：

1. 设置中断向量（安装信号）
2. 设置中断源（配置发送信号的线程）
3. 编写中断服务函数（自定义的信号处理函数）
4. 初始化中断（解除信号阻塞、等待信号）
5. 清除中断标志位（阻塞信号）
6. 中断发生时调用中断服务函数
7. 等待中断服务函数处理完毕
8. 恢复中断（接触信号阻塞、等待信号）
9. 不需要中断后关闭中断（阻塞信号、正常运行）