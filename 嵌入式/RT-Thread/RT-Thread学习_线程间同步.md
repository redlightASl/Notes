# 线程间同步

## 名词解释

同步：按预定的先后次序进行运行

**线程同步：多个线程通过特定的机制（如互斥量、事件对象、临界区等）来控制线程之间的执行顺序**

线程同步的作用：在线程之间建立起顺序执行的关系，防止两个线程争夺同一系统资源的情况发生

**临界区：会被多个线程操作/访问的同一块代码区域**

**资源互斥：任何时刻只允许一个线程去使用临界区的线程同步策略**

线程同步的核心思想就是资源互斥

# 信号量

信号量对象：一种轻型的用于解决线程同步问题的内核对象，线程可以获取或释放它从而达到同步或互斥的目的

信号量由**信号量值**、**线程等待队列**组成。信号量值对应信号量对象的资源（相当于信号量对象的实例）数目，信号量值为n就表示可用的信号量实例数目为n，当信号量值为0时，再申请该信号量的线程就会被挂起到该信号量的线程等待队列上

信号量控制块：操作系统用于管理信号量的一个数据结构

信号量控制块的具体代码如下：

```c
struct rt_semaphore
{
    struct rt_ipc_object parent;//继承自ipc_object类
    rt_uint16_t value;//信号量的值，最大为65535
};
typedef struct rt_semaphore *rt_sem_t;//将信号量句柄封装为rt_sem_t


struct rt_ipc_object//IPC_object容器类
{
    struct rt_object parent;//继承自内核对象
    rt_list_t suspend_thread;//挂起线程链表
};
```

## 信号量的管理方式

### 创建和删除动态信号量

创建信号量使用函数接口rt_sem_create()

**信号量标志参数**决定了**信号量不可用时多个线程等待的排队方式**

可选择以下类型：

| 方式 | 说明                             | 填入参数         |
| ---- | -------------------------------- | ---------------- |
| FIFO | 等待队列按先入先出方式排队       | RT_IPC_FLAG_FIFO |
| PRIO | 等待队列按优先级从高到低顺序排队 | RT_IPC_FLAG_PRIO |

下面是代码实现：

```c
rt_sem_t rt_sem_create(const char *name,//信号量名
                       rt_uint32_t value,//信号量值
                       rt_uint8_t flag//信号量标志参数
                      )
{
    rt_sem_t sem;
    RT_DEBUG_NOT_IN_INTERRUPT;

    /* 分配信号量对象 */
    sem = (rt_sem_t)rt_object_allocate(RT_Object_Class_Semaphore, name);
    if (sem == RT_NULL)
        return sem;

    /* 初始化信号量对象 */
    rt_ipc_object_init(&(sem->parent));

    /* 设置信号量值 初值 */
    sem->value = value;

    /* 设置信号量标志参数 */
    sem->parent.parent.flag = flag;

    return sem;
}
```

可以使用接口rt_sem_delete()来删除信号量以释放系统资源

==注意：被唤醒的等待线程会获得-RT_ERROR的返回值==

```c
rt_err_t rt_sem_delete(rt_sem_t sem)
{
    RT_DEBUG_NOT_IN_INTERRUPT;

    /* 检查参数是否合法 */
    RT_ASSERT(sem != RT_NULL);
    RT_ASSERT(rt_object_get_type(&sem->parent.parent) == RT_Object_Class_Semaphore);
    RT_ASSERT(rt_object_is_systemobject(&sem->parent.parent) == RT_FALSE);

    /* 唤醒所有等待在该信号量上的线程 */
    rt_ipc_list_resume_all(&(sem->parent.suspend_thread));

    /* 删除信号量，释放内存资源 */
    rt_object_delete(&(sem->parent.parent));

    return RT_EOK;
}

//唤醒等待线程的实现
rt_inline rt_err_t rt_ipc_list_resume_all(rt_list_t *list)
{
    struct rt_thread *thread;
    register rt_ubase_t temp;

    /* 唤醒所有挂起线程 */
    while (!rt_list_isempty(list))
    {
        /* 关闭中断 */
        temp = rt_hw_interrupt_disable();
        /* 获取链表中下一个线程 */
        thread = rt_list_entry(list->next, struct rt_thread, tlist);
        /* 设置错误代码 */
        thread->error = -RT_ERROR;
        /*
         * 加载线程
         * 从挂起线程列表中移除所有线程
         */
        rt_thread_resume(thread);
        /* 使能中断 */
        rt_hw_interrupt_enable(temp);
    }
    return RT_EOK;
}
```

### 初始化和脱离静态信号量

静态信号量对象的内存空间在编译期间被分配在读写数据段或未初始化数据段，只需要在使用前进行初始化即可

用接口rt_sem_init()进行初始化

```c
rt_err_t rt_sem_init(rt_sem_t    sem,//需要被初始化的静态信号量
                     const char *name,//信号量名
                     rt_uint32_t value,//信号量值
                     rt_uint8_t  flag)//信号量标志参数
{
    RT_ASSERT(sem != RT_NULL);//检查传入的信号量参数是否合法

    /* 初始化内核对象 */
    rt_object_init(&(sem->parent.parent), RT_Object_Class_Semaphore, name);
    /* 初始化IPC对象 */
    rt_ipc_object_init(&(sem->parent));
    /* 设置信号量值 初值 */
    sem->value = value;
    /* 设置信号量标志参数 */
    sem->parent.parent.flag = flag;

    return RT_EOK;
}
```

用接口rt_sem_detach()脱离信号量

```c
rt_err_t rt_sem_detach(rt_sem_t sem)
{
    /* 检查传入参数是否合法 */
    RT_ASSERT(sem != RT_NULL);
    RT_ASSERT(rt_object_get_type(&sem->parent.parent) == RT_Object_Class_Semaphore);
    RT_ASSERT(rt_object_is_systemobject(&sem->parent.parent));

    /* 唤醒所有挂在该信号量等待队列上的线程 */
    rt_ipc_list_resume_all(&(sem->parent.suspend_thread));

    /* 将信号量对象从内核对象管理器中脱离 */
    rt_object_detach(&(sem->parent.parent));

    return RT_EOK;
}
```

==注意：被唤醒的等待线程会获得-RT_ERROR的返回值==

### 获取信号量

线程通过获取信号量来获得信号量资源实例：当信号量值大于0时，线程将获得信号量，相应的信号量值-1

使用rt_sem_take()获取信号量

```c
rt_err_t rt_sem_take(rt_sem_t sem,//要获取的信号量
                     rt_int32_t time//预设等待时间
                    )
{
    register rt_base_t temp;
    struct rt_thread *thread;

    /* 检查参数是否合法 */
    RT_ASSERT(sem != RT_NULL);
    RT_ASSERT(rt_object_get_type(&sem->parent.parent) == RT_Object_Class_Semaphore);

    RT_OBJECT_HOOK_CALL(rt_object_trytake_hook, (&(sem->parent.parent)));//调用相关钩子函数

    /* 关闭中断 */
    temp = rt_hw_interrupt_disable();
    RT_DEBUG_LOG(RT_DEBUG_IPC, ("thread %s take sem:%s, which value is: %d\n",
                                rt_thread_self()->name,
                                ((struct rt_object *)sem)->name,
                                sem->value));
    if (sem->value > 0)//若信号量值>0
    {
        /* 可以获取信号量，对应信号量值-1 */
        sem->value --;
        /* 使能中断 */
        rt_hw_interrupt_enable(temp);
    }
    else//若信号量值<0
    {
        /* 当前信号量资源实例不可用 */
        if (time == 0)//若在参数time指定时间内仍无法得到信号量
        {
            rt_hw_interrupt_enable(temp);//使能线程中断
            return -RT_ETIMEOUT;//超时返回
        }
        else//若在参数time指定时间之内
        {
            /* 检查当前上下文 */
            RT_DEBUG_IN_THREAD_CONTEXT;
            /* 信号量无法获取，线程被挂到等待队列 */
            /* 获取当前线程 */
            thread = rt_thread_self();
            /* 重置线程错误号 */
            thread->error = RT_EOK;
            RT_DEBUG_LOG(RT_DEBUG_IPC, ("sem take: suspend thread - %s\n",
                                        thread->name));//显示debug信息
            /* 挂起线程 */
            rt_ipc_list_suspend(&(sem->parent.suspend_thread),
                                thread,
                                sem->parent.parent.flag);
            
            if (time > 0)/* 若有剩余等待时间，则开启线程计时器 */
            {
                RT_DEBUG_LOG(RT_DEBUG_IPC, ("set thread:%s to timer list\n",
                                            thread->name));

                /* 重设线程计时器定时时间并启动 */
                rt_timer_control(&(thread->thread_timer),
                                 RT_TIMER_CTRL_SET_TIME,
                                 &time);
                rt_timer_start(&(thread->thread_timer));
            }
            /* 使能中断 */
            rt_hw_interrupt_enable(temp);

            /* 按线程队列执行任务 */
            rt_schedule();

            if (thread->error != RT_EOK)//若线程出错
            {
                return thread->error;//则返回线程错误（超时则返回-RT_ETIMEOUT，其他错误返回-RT_ERROR）
            }
        }
    }
    RT_OBJECT_HOOK_CALL(rt_object_take_hook, (&(sem->parent.parent)));//执行钩子函数
    return RT_EOK;
}
```

### 无等待获取信号量

用户不想在申请的信号量上挂起线程进行等待时，可以使用无等待方式获取信号量，可以使用接口函数rt_sem_trytake()

```c
rt_err_t rt_sem_trytake(rt_sem_t sem)
{
    return rt_sem_take(sem, 0);
}
```

本质上就是套皮的rt_sem_take()函数，但是等待时间设置为0

当线程申请的信号量资源实例不可用的时候，它不会等待在该信号量上，而是直接返回-RT_ETIMEOUT

### 释放信号量

释放信号量是获取信号量的反动作：当信号量值为0且有线程等待时，唤醒等待队列中的第一个线程，由它获取信号量；否则将信号量的值+1

释放信号量使用接口rt_sem_release()

```c
rt_err_t rt_sem_release(rt_sem_t sem)
{
    register rt_base_t temp;
    register rt_bool_t need_schedule;

    /* 检查参数是否合法 */
    RT_ASSERT(sem != RT_NULL);
    RT_ASSERT(rt_object_get_type(&sem->parent.parent) == RT_Object_Class_Semaphore);

    RT_OBJECT_HOOK_CALL(rt_object_put_hook, (&(sem->parent.parent)));//调用钩子函数

    need_schedule = RT_FALSE;
    /* 关闭中断 */
    temp = rt_hw_interrupt_disable();
    RT_DEBUG_LOG(RT_DEBUG_IPC, ("thread %s releases sem:%s, which value is: %d\n",
                                rt_thread_self()->name,
                                ((struct rt_object *)sem)->name,
                                sem->value));
    if (!rt_list_isempty(&sem->parent.suspend_thread))//如果等待队列非空
    {
        /* 唤醒被挂起的线程 */
        rt_ipc_list_resume(&(sem->parent.suspend_thread));
        need_schedule = RT_TRUE;//有线程被唤醒，需要重排计划任务
    }
    else//如果等待队列为空
        sem->value ++; /* 将信号量值+1 */
    /* 使能中断 */
    rt_hw_interrupt_enable(temp);

    /* 如果有线程被唤醒，则按重排后的计划任务执行 */
    if (need_schedule == RT_TRUE)
        rt_schedule();

    return RT_EOK;
}
```

## 信号量的使用场合

1. 线程同步

   信号量值初始化且始终为0，线程获得该信号量后会直接被挂入等待队列；挂在等待队列上的第一个线程完成工作时，释放信号量，等待在后面的第二个线程被唤醒

   **==相当于把信号量当作工作完成标志：持有信号量的线程先完成自己的工作，再通过释放信号量通知下一个线程完成下一部分工作==**

2. 锁

   **单一的锁常应用于多个线程间对临界区的访问**

   信号量值初始化为1，默认有1个资源可用；信号量值始终在1和0之间变动，称为二值信号量

   线程需要访问临界区时，它要先获得资源锁，如果成功获得，其他将访问临界区的线程会被挂起；当占有信号量的线程处理完毕，退出临界区时，它释放信号量，让挂在锁上的第一个等待线程被唤醒并获取临界区访问权

3. 中断与线程间同步

   预先信号量初始值设为0。当线程试图获取信号量时，会直接被挂在等待队列直到信号量被释放。

   中断触发时，中断服务例程应先进行硬件相关动作，确认中断并清除中断源后释放信号量来唤醒相应线程以进行后续的任务

   特别地，**中断与线程间互斥行为不能采取信号量，而应采用开关中断的方式**

4. 资源计数

   信号量可以被看作一个递增或递减的非负值计数器。

   若线程间工作处理速度不匹配，信号量可以作为前一线程工作完成个数的计数；当调度到后一线程，可以以一种连续的方式一次处理多个事件

   人话：==干得快的任务用信号量计数，累计好几次再唤醒干得慢的任务一次把剩下的东西处理完==

   注意：一般资源计数类型多用于混合方式的线程间同步

# 互斥量

**互斥量即“互相排斥的信号量”**，是一种特殊的二值信号量

互斥量与一般信号量的区别：拥有互斥量的线程拥有互斥量的所有权，互斥量**支持递归访问**，**能防止线程优先级翻转**，互斥量**只能由持有它的线程进行释放**，但一般信号量可以由任何线程释放

人话：互斥量由持有它的线程全权掌控，且具有“递归访问”的特性

## 互斥量的工作机制

互斥量只有**开锁**或**闭锁**两种状态值。有线程持有时，互斥量闭锁，这个线程获得其所有权；当且仅当这个线程释放它时，互斥量开锁，线程失去他的所有权。当一个线程持有互斥量时，其他线程不能对它进行开锁或获取操作，但持有该互斥量的线程可以再次获得这个锁而不被挂起，即“递归访问”。

信号量的使用过程中可能会出现“优先级反转”的情况，使用互斥量可以有效解决这个问题

### 优先级反转

优先级反转并不是指字面意义上的“低优先级比高优先级先执行”——由于线程抢占机制，这种情况不可能发生。优先级反转指的是“看起来”低优先级线程“抢占了”高优先级线程的运行时间。如下图所示

![image-20210115153741932](RT-Thread学习_线程间同步.assets/image-20210115153741932.png)

低优先级线程C在执行时已经通过信号量占用了临界区，一段时间后高优先级线程A到来，抢占C运行；但当C试图获取临界区的信号量时，发现C还在临界区等待执行，于是A被信号量挂起到等待队列，C转而使用临界区；这样一来只有C用完临界区的资源，A才能正式开始使用临界区资源。而优先级反转指的是：如果C执行途中还有中优先级线程B把C抢占，C的运行就要向后拖延更长时间，这就造成了A明明是高优先级线程，却无法保证优先得到运行。

我们把这称为：大水冲了龙王庙，信号量不认调度器，内核对象左右互搏

互斥量可以用优先级继承算法解决这种情况！

思路：在线程A尝试获取共享资源而被挂起的期间内，将线程C的优先级提升到线程A的同等优先级别，防止被B抢占

**优先级继承：提高某个占有某种资源的低优先级线程的优先级，使之与所有等待该资源的线程中优先级最高的那个线程的优先级相等，然后执行；而当这个低优先级线程释放该资源时，优先级重新回到初始设定**

解决问题后的示意图如下：

![image-20210115160615391](RT-Thread学习_线程间同步.assets/image-20210115160615391.png)

这个算法使用时应做到：获得互斥量后尽快释放互斥量，并且在持有互斥量的过程中不在进行更改持有互斥量线程的优先级

## 互斥量控制块

RTT使用互斥量控制块管理互斥量，其句柄被封装为rt_mutex_t

```c
struct rt_mutex
{
    struct rt_ipc_object parent;/**< 继承自ipc_object类 */
    rt_uint16_t value;/**< 互斥量的值 */
    rt_uint8_t original_priority;/**< 持有线程的原始优先级 */
    rt_uint8_t hold;/**< 持有线程的持有次数 */
    struct rt_thread *owner;/**< 当前持有互斥量的线程 */
};
typedef struct rt_mutex *rt_mutex_t;//将互斥量指针封装为互斥量句柄
```

互斥量对象从rt_ipc_object类中派生，由IPC容器管理

## 互斥量的管理

互斥量的管理与信号量的管理大同小异，但是由于支持递归访问、优先级继承，所以会多出几个赋值属性

下面的代码仅标明不同点

### 创建

```c
rt_mutex_t rt_mutex_create(const char *name, rt_uint8_t flag)
{
    struct rt_mutex *mutex;
    RT_DEBUG_NOT_IN_INTERRUPT;
    /* allocate object */
    mutex = (rt_mutex_t)rt_object_allocate(RT_Object_Class_Mutex, name);
    if (mutex == RT_NULL)
        return mutex;
    /* init ipc object */
    rt_ipc_object_init(&(mutex->parent));
    mutex->value              = 1;//仅有0和1两个值，是特殊的二值信号量
    mutex->owner              = RT_NULL;//初始化互斥量持有线程
    mutex->original_priority  = 0xFF;//初始化持有线程优先级为最低
    mutex->hold               = 0;//初始化持有次数为0
    /* set flag */
    mutex->parent.parent.flag = flag;
    return mutex;
}
```

### 删除

```c
rt_err_t rt_mutex_delete(rt_mutex_t mutex)//与信号量操作基本一致
{
    RT_DEBUG_NOT_IN_INTERRUPT;
    /* parameter check */
    RT_ASSERT(mutex != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mutex->parent.parent) == RT_Object_Class_Mutex);
    RT_ASSERT(rt_object_is_systemobject(&mutex->parent.parent) == RT_FALSE);
    /* wakeup all suspend threads */
    rt_ipc_list_resume_all(&(mutex->parent.suspend_thread));
    /* delete semaphore object */
    rt_object_delete(&(mutex->parent.parent));
    return RT_EOK;
}
```

### 初始化

```c
rt_err_t rt_mutex_init(rt_mutex_t mutex, const char *name, rt_uint8_t flag)
{
    /* parameter check */
    RT_ASSERT(mutex != RT_NULL);
    /* init object */
    rt_object_init(&(mutex->parent.parent), RT_Object_Class_Mutex, name);
    /* init ipc object */
    rt_ipc_object_init(&(mutex->parent));
    mutex->value = 1;//仅有0和1两个值，是特殊的二值信号量
    mutex->owner = RT_NULL;//初始化互斥量持有线程
    mutex->original_priority = 0xFF;//初始化持有线程优先级为最低
    mutex->hold  = 0;//初始化持有次数为0
    /* set flag */
    mutex->parent.parent.flag = flag;
    return RT_EOK;
}
```

### 脱离

```c
rt_err_t rt_mutex_detach(rt_mutex_t mutex)//与信号量操作基本一致
{
    /* parameter check */
    RT_ASSERT(mutex != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mutex->parent.parent) == RT_Object_Class_Mutex);
    RT_ASSERT(rt_object_is_systemobject(&mutex->parent.parent));
    /* wakeup all suspend threads */
    rt_ipc_list_resume_all(&(mutex->parent.suspend_thread));
    /* detach semaphore object */
    rt_object_detach(&(mutex->parent.parent));
    return RT_EOK;
}
```

### 获取

```c
rt_err_t rt_mutex_take(rt_mutex_t mutex, rt_int32_t time)
{
    register rt_base_t temp;
    struct rt_thread *thread;
    /* this function must not be used in interrupt even if time = 0 */
    RT_DEBUG_IN_THREAD_CONTEXT;

    /* 检查参数是否合法 */
    RT_ASSERT(mutex != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mutex->parent.parent) == RT_Object_Class_Mutex);
    /* 获取当前线程 */
    thread = rt_thread_self();
    /* 关闭中断 */
    temp = rt_hw_interrupt_disable();
    RT_OBJECT_HOOK_CALL(rt_object_trytake_hook, (&(mutex->parent.parent)));//调用钩子函数
    RT_DEBUG_LOG(RT_DEBUG_IPC,
                 ("mutex_take: current thread %s, mutex value: %d, hold: %d\n",
                  thread->name, mutex->value, mutex->hold));//输出debug信息

    /* 将线程状态设置为正常 */
    thread->error = RT_EOK;
    if (mutex->owner == thread)//如果是相同的线程再次获取互斥量
    {
        /* 互斥量持有计数+1 */
        mutex->hold ++;
    }
    else//如果是其他线程试图占有互斥量
    {
__again:
        /* 
         * 初态的互斥量值为1
         * 如果其值大于0，表明互斥量可以被获取
         */
        
        if (mutex->value > 0)//互斥量值>0
        {
            /* 互斥量可以被获取 */
            mutex->value --;//互斥量值-1(变为0)
            mutex->owner = thread;//拥有者为当前线程
            mutex->original_priority = thread->current_priority;//设置互斥量优先级与线程优先级相同
            mutex->hold ++;//持有计数+1
        }
        else//如果互斥量值为0
        {
            /* 当等待超时时 */
            if (time == 0)
            {
                /* 设置当前线程超时报错 */
                thread->error = -RT_ETIMEOUT;
                /* 使能中断 */
                rt_hw_interrupt_enable(temp);
                return -RT_ETIMEOUT;//返回报错
            }
            else//在线程等待时间之内
            {
                /* 互斥量不能被获取，试图占有它的线程被挂到等待队列 */
                RT_DEBUG_LOG(RT_DEBUG_IPC, ("mutex_take: suspend thread: %s\n",
                                            thread->name));
                /* 如果当前线程优先级<互斥量拥有者的优先级 */
                if (thread->current_priority < mutex->owner->current_priority)
                {
                    /* 改变互斥量拥有者的优先级和申请线程优先级相同 */
                    rt_thread_control(mutex->owner,
                                      RT_THREAD_CTRL_CHANGE_PRIORITY,
                                      &thread->current_priority);
                }

                /* 挂起当前线程 */
                rt_ipc_list_suspend(&(mutex->parent.suspend_thread),
                                    thread,
                                    mutex->parent.parent.flag);

                /* 如果还有等待时间 */
                if (time > 0)
                {
                    RT_DEBUG_LOG(RT_DEBUG_IPC,
                                 ("mutex_take: start the timer of thread:%s\n",
                                  thread->name));

                    /* 重置线程计数器并重启它 */
                    rt_timer_control(&(thread->thread_timer),
                                     RT_TIMER_CTRL_SET_TIME,
                                     &time);
                    rt_timer_start(&(thread->thread_timer));
                }
                /* 使能中断 */
                rt_hw_interrupt_enable(temp);

                /* 按计划序列执行 */
                rt_schedule();

                if (thread->error != RT_EOK)//如果出错
                {
                	/* 如果当前申请被信号打断，则重试申请获取互斥量 */
                	if (thread->error == -RT_EINTR) goto __again;
                    /* 如果不是则返回报错 */
                    return thread->error;
                }
                else//如果没有出错
                {
                    /* 互斥量被成功占用 */
                    /* 关闭中断 */
                    temp = rt_hw_interrupt_disable();
                }
            }
        }
    }

    /* 使能中断 */
    rt_hw_interrupt_enable(temp);
    RT_OBJECT_HOOK_CALL(rt_object_take_hook, (&(mutex->parent.parent)));//调用钩子函数
    return RT_EOK;
}
```

### 释放

```c
rt_err_t rt_mutex_release(rt_mutex_t mutex)
{
    register rt_base_t temp;
    struct rt_thread *thread;
    rt_bool_t need_schedule;
    /* 检查参数是否合法 */
    RT_ASSERT(mutex != RT_NULL);
    RT_ASSERT(rt_object_get_type(&mutex->parent.parent) == RT_Object_Class_Mutex);

    need_schedule = RT_FALSE;
    /* only thread could release mutex because we need test the ownership */
    RT_DEBUG_IN_THREAD_CONTEXT;

    /* 获取当前线程 */
    thread = rt_thread_self();
    /* 关闭中断 */
    temp = rt_hw_interrupt_disable();
    RT_DEBUG_LOG(RT_DEBUG_IPC,
                 ("mutex_release:current thread %s, mutex value: %d, hold: %d\n",
                  thread->name, mutex->value, mutex->hold));//显示debug信息

    RT_OBJECT_HOOK_CALL(rt_object_put_hook, (&(mutex->parent.parent)));//调用钩子函数

    /* 互斥量只能被拥有控制权的线程释放 */
    if (thread != mutex->owner)
    {
        thread->error = -RT_ERROR;//如果被非控制权线程释放则报错
        /* 使能中断 */
        rt_hw_interrupt_enable(temp);
        return -RT_ERROR;
    }

    /* 正常释放，则互斥量持有计数-1 */
    mutex->hold --;
    /* 如果持有线程已经释放所有的持有操作，即持有计数为0 */
    if (mutex->hold == 0)
    {
        /* 改变持有线程和优先级 */
        if (mutex->original_priority != mutex->owner->current_priority)
        {
            rt_thread_control(mutex->owner,
                              RT_THREAD_CTRL_CHANGE_PRIORITY,
                              &(mutex->original_priority));
        }
        /* 如果唤醒等待队列中有被挂起的线程（等待队列非空） */
        if (!rt_list_isempty(&mutex->parent.suspend_thread))
        {
            /* 获取被挂起的线程 */
            thread = rt_list_entry(mutex->parent.suspend_thread.next,
                                   struct rt_thread,
                                   tlist);

            RT_DEBUG_LOG(RT_DEBUG_IPC, ("mutex_release: resume thread: %s\n",
                                        thread->name));

            /* 设置新的持有线程和优先级给下一个线程 */
            mutex->owner             = thread;
            mutex->original_priority = thread->current_priority;
            mutex->hold ++;//持有数+1

            /* 恢复线程 */
            rt_ipc_list_resume(&(mutex->parent.suspend_thread));
            need_schedule = RT_TRUE;//需要调度标志位置TRUE
        }
        else//如果等待队列空
        {
            /* 将互斥量值+1 */
            mutex->value ++;

            /* 清空所有持有线程 并 将优先级调到最低 */
            mutex->owner             = RT_NULL;
            mutex->original_priority = 0xff;
        }
    }
    /* 使能中断 */
    rt_hw_interrupt_enable(temp);
    /* 如果必要的话，执行调度 */
    if (need_schedule == RT_TRUE)
        rt_schedule();

    return RT_EOK;
}
```

## 互斥量的使用场景

使用场景单一，注意使用限制：初始化时互斥量永远处于开锁的状态，而在被线程持有的时候立刻转为闭锁的状态

1. 线程多次持有互斥量，避免同一线程多次递归持有造成死锁
2. 多线程同步可能造成优先级反转的情况

# 事件集

信号量可以完成两个线程间一对一的同步，但仅限于此

事件集是对信号量的补充，一个事件集包含多个事件，利用事件集可完成一对多、多对多的线程同步

一个线程与多个事件的关系可设置为：

1. **任意**事件唤醒线程（或逻辑）
2. 所有事件**都**完成后才唤醒线程（与逻辑）

以此类推，时间也可以是多个线程同步多个事件

## 事件集工作机制

用一个**32位无符号整型变量**表示事件集，变量的每一位代表一个事件

线程通过**逻辑与（关联型同步：线程与若干事件都发生同步）**和**逻辑或（独立型同步：线程与任何事件之一发生同步）**将一个或多个事件关联，形成**事件组合**

事件集的特点：

1. **事件只与线程有关**，事件之间相互独立
2. **每个线程拥有32个事件标志**，采用一个32位无符号整型进行记录，**每位代表一个事件**
3. **事件仅用于同步**，不用于数据传输
4. **事件无排队性**，多次向线程发送同一事件时，若线程还未读取该事件，其效果等同于单次发送

RTT中，每个线程都拥有有个事件信息标志（见线程管理一节）

它具有三个属性：

1. 逻辑与	RT_EVENT_FLAG_AND	被设为1的标志位全部触发才判定唤醒
2. 逻辑或	RT_EVENT_FLAG_OR	只要有一位设为1的标志位触发则判定唤醒
3. 清除标记	RT_EVENT_FLAG_CLEAR	唤醒后主动把触发过的事件标志清零

线程等待事件同步时，通过32个事件标志和这个事件信息来判断当前接收的事件是否满足同步条件

```c
#if defined(RT_USING_EVENT)
    /* 线程事件信息标志 */
    rt_uint32_t event_set;
    rt_uint8_t  event_info;
#endif
```

官方文档例程如下：

![image-20210115183600981](RT-Thread学习_线程间同步.assets/image-20210115183600981.png)

## 事件集控制块

RTT使用事件集控制块管理事件

注意：使能了事件集后才能使用相关功能

```c
#ifdef RT_USING_EVENT

//事件集中的标志定义
#define RT_EVENT_FLAG_AND 0x01 /**< 逻辑与 */
#define RT_EVENT_FLAG_OR 0x02 /**< 逻辑或 */
#define RT_EVENT_FLAG_CLEAR 0x04 /**<清除标志 */

//事件集控制块结构体
struct rt_event
{
    struct rt_ipc_object parent;/**< 继承自ipc_object类 */
    rt_uint32_t set;/**< 事件集合，32位整数中每1位代表1个事件，位的值可以标记某事件是否发生 */
};
typedef struct rt_event *rt_event_t;//将事件集控制块的指针封装为事件集句柄

#endif
```

事件集对象从rt_ipc_object类中派生，由IPC容器管理

## 事件集管理方式

### 创建和删除事件集

使用接口rt_event_create()创建动态事件集

系统会从对象管理器中分配事件集对象并进行初始化，然后初始化父类IPC对象

```c
rt_event_t rt_event_create(const char *name, rt_uint8_t flag)
{
    rt_event_t event;

    RT_DEBUG_NOT_IN_INTERRUPT;

    /* 分配对象*/
    event = (rt_event_t)rt_object_allocate(RT_Object_Class_Event, name);
    if (event == RT_NULL)
        return event;

    /* 对事件集所属的线程的事件状态进行设置 */
    event->parent.parent.flag = flag;
    
    /* 初始化IPC对象 */
    rt_ipc_object_init(&(event->parent));

    /* 初始化事件集合设置 */
    event->set = 0;

    return event;
}
```

系统不在使用动态事件集对象时可用接口函数rt_event_delete()删除事件集对象控制块

```c
rt_err_t rt_event_delete(rt_event_t event)
{
    /* 检查参数是否合法 */
    RT_ASSERT(event != RT_NULL);
    RT_ASSERT(rt_object_get_type(&event->parent.parent) == RT_Object_Class_Event);
    RT_ASSERT(rt_object_is_systemobject(&event->parent.parent) == RT_FALSE);

    RT_DEBUG_NOT_IN_INTERRUPT;

    /* 恢复所有挂起的线程 */
    rt_ipc_list_resume_all(&(event->parent.suspend_thread));

    /* 删除事件集对象 */
    rt_object_delete(&(event->parent.parent));

    return RT_EOK;
}
```

删除前会唤醒挂在该事件集上的所有线程，然后释放事件集对象占用的内存块

### 初始化和脱离事件集

初始化静态事件集对象可使用接口rt_event_init()

调用前需指定静态时间及对象的句柄，系统才会初始化该事件集对象，并加入内核对象容器中进行管理

```c
rt_err_t rt_event_init(rt_event_t event,//事件集对象的句柄
                       const char *name,//事件集名称
                       rt_uint8_t flag//事件集的标志
                      )
{
    /* 检查参数是否合法 */
    RT_ASSERT(event != RT_NULL);

    /* 初始化对象 */
    rt_object_init(&(event->parent.parent), RT_Object_Class_Event, name);

    /* 对事件集所属的线程的事件状态进行设置 */
    event->parent.parent.flag = flag;

    /* 初始化IPC对象 */
    rt_ipc_object_init(&(event->parent));

    /* 初始化事件集合 */
    event->set = 0;

    return RT_EOK;
}
```

使用接口rt_event_detach()将事件集对象从内核对象管理器中脱离，并释放系统资源

```c
rt_err_t rt_event_detach(rt_event_t event)
{
    /* 检查参数是否合法 */
    RT_ASSERT(event != RT_NULL);
    RT_ASSERT(rt_object_get_type(&event->parent.parent) == RT_Object_Class_Event);
    RT_ASSERT(rt_object_is_systemobject(&event->parent.parent));

    /* 恢复所有挂起的线程 */
    rt_ipc_list_resume_all(&(event->parent.suspend_thread));

    /* 从内核对象链表中脱离事件集 */
    rt_object_detach(&(event->parent.parent));

    return RT_EOK;
}
```

调用时会唤醒所有正挂在该事件集等待队列上的线程，然后将该事件集从内核对象管理器中脱离

### 发送事件

发送事件时可以使用函数rt_event_send()发送事件集中的一个或多个事件

发送时，通过参数set指定的事件标志来设定event事件集对象的事件标志值，然后遍历所有挂在event事件集对象上的等待线程，判断是否有现成的事件激活要求与当前event对象事件标志值匹配，如果有，则唤醒该线程

```c
rt_err_t rt_event_send(rt_event_t event,//事件集对象的句柄
                       rt_uint32_t set//发送的一个或多个事件的标志值
                      )
{
    struct rt_list_node *n;
    struct rt_thread *thread;
    register rt_ubase_t level;
    register rt_base_t status;
    rt_bool_t need_schedule;

    /* 检查参数是否合法 */
    RT_ASSERT(event != RT_NULL);
    RT_ASSERT(rt_object_get_type(&event->parent.parent) == RT_Object_Class_Event);
    if (set == 0)
        return -RT_ERROR;

    need_schedule = RT_FALSE;

    /* 关闭中断 */
    level = rt_hw_interrupt_disable();
    /* 设置事件集 */
    event->set |= set;

    RT_OBJECT_HOOK_CALL(rt_object_put_hook, (&(event->parent.parent)));//调用钩子函数
    
    if (!rt_list_isempty(&event->parent.suspend_thread))//如果挂在该事件集上的等待链表非空
    {
        /* 遍历链表寻找合适的线程来激活 */
        n = event->parent.suspend_thread.next;
        while (n != &(event->parent.suspend_thread))
        {
            /* 获取当前线程 */
            thread = rt_list_entry(n, struct rt_thread, tlist);

            status = -RT_ERROR;
            if (thread->event_info & RT_EVENT_FLAG_AND)//如果有设置为逻辑与的
            {
                if ((thread->event_set & event->set) == thread->event_set)//如果触发的事件和设定事件符合
                {
                    /* 当前线程收到一个逻辑与事件 */
                    status = RT_EOK;
                }
            }
            else if (thread->event_info & RT_EVENT_FLAG_OR)//如果有设置为逻辑或的
            {
                if (thread->event_set & event->set)//只要存在一个触发的事件和设定事件中某一位符合
                {
                    /* 保存收到的事件集 */
                    thread->event_set = thread->event_set & event->set;

                    /* 当前线程收到了一个逻辑或事件 */
                    status = RT_EOK;
                }
            }

            /* 将结点指针移动到下一个线程节点 */
            n = n->next;

            /* 如果满足条件则唤醒线程 */
            if (status == RT_EOK)
            {
                /* 清除事件 */
                if (thread->event_info & RT_EVENT_FLAG_CLEAR)
                    event->set &= ~thread->event_set;

                /* 唤醒线程并将其从等待链表上脱离 */
                rt_thread_resume(thread);

                /* 有必要重新按计划列表调度 */
                need_schedule = RT_TRUE;
            }
        }
    }
    /* 使能中断 */
    rt_hw_interrupt_enable(level);
    /* 如果有必要，按计划列表调度 */
    if (need_schedule == RT_TRUE)
        rt_schedule();
    return RT_EOK;
}
```

### 接收事件

一个事件集对象可同时等待接收32个事件，在线程中调用函数rt_event_recv()来接收事件

接收流程如下：

1. 根据set参数和接收选项option来判断它要接收的事件是否发生
2. 如果已经发生，根据参数option上是否设置了RT_EVENT_FLAG_CLEAR来决定是否重置事件的相应标志位
3. 如果没有发生，会把等待的set和option参数填入线程本身的结构中，然后将线程挂起在当前事件，直到其等待的事件满足条件或等待时间超过接收超时时间
4. 如果满足条件则唤醒线程
5. 如果超过超时时间则会自动返回-RT_ETIMEOUT

特别地，如果超时时间为0，表示当线程要接收的时间没有满足其要求时就不等待，而是直接返回-RT_ETIMEOUT



option取值可为RT_EVENT_FLAG_OR，RT_EVENT_FLAG_AND，RT_EVENT_FLAG_CLEAR

```c
rt_err_t rt_event_recv(rt_event_t   event,//事件集对象的句柄
                       rt_uint32_t  set,//接收线程感兴趣的事件
                       rt_uint8_t   option,//接收选项
                       rt_int32_t   timeout,//接收超时时间
                       rt_uint32_t *recved)//指向接收到对象的指针
{
    struct rt_thread *thread;
    register rt_ubase_t level;
    register rt_base_t status;

    RT_DEBUG_IN_THREAD_CONTEXT;

    /* 检查参数是否合法 */
    RT_ASSERT(event != RT_NULL);
    RT_ASSERT(rt_object_get_type(&event->parent.parent) == RT_Object_Class_Event);
    if (set == 0)
        return -RT_ERROR;

    /* 初始化状态 */
    status = -RT_ERROR;
    /* 获取当前线程 */
    thread = rt_thread_self();
    /* 重设线程状态为正常 */
    thread->error = RT_EOK;

    RT_OBJECT_HOOK_CALL(rt_object_trytake_hook, (&(event->parent.parent)));

    /* 关闭中断 */
    level = rt_hw_interrupt_disable();

    /* 检查option参数 */
    if (option & RT_EVENT_FLAG_AND)//option参数设定为RT_EVENT_FLAG_AND
    {
        if ((event->set & set) == set)
            status = RT_EOK;
    }
    else if (option & RT_EVENT_FLAG_OR)//RT_EVENT_FLAG_OR
    {
        if (event->set & set)
            status = RT_EOK;
    }
    else
    {
        /* option参数应该至少设置以上两个选项之一 */
        RT_ASSERT(0);
    }

    if (status == RT_EOK)
    {
        /* 设定收到事件集合 */
        if (recved)
            *recved = (event->set & set);

        /* 重设事件 */
        if (option & RT_EVENT_FLAG_CLEAR)
            event->set &= ~set;
    }
    else if (timeout == 0)//如果超时时间设定为0
    {
        /* 不等待超时 */
        thread->error = -RT_ETIMEOUT;
    }
    else
    {
        /* 设定线程的事件集属性 */
        thread->event_set  = set;
        thread->event_info = option;

        /* 将线程挂载到等待队列 */
        rt_ipc_list_suspend(&(event->parent.suspend_thread),
                            thread,
                            event->parent.parent.flag);

        /* 如果有等待超时，则重启定时器 */
        if (timeout > 0)
        {
            /* 重设线程定时器初值并重启定时器 */
            rt_timer_control(&(thread->thread_timer),
                             RT_TIMER_CTRL_SET_TIME,
                             &timeout);
            rt_timer_start(&(thread->thread_timer));
        }

        /* 使能中断 */
        rt_hw_interrupt_enable(level);

        /* 进行线程调度 */
        rt_schedule();

        if (thread->error != RT_EOK)
        {
            /* 返回出错信息 */
            return thread->error;
        }

        /* 如果收到事件，则关闭中断进行保护 */
        level = rt_hw_interrupt_disable();
        /* 设定收到的事件 */
        if (recved)
            *recved = thread->event_set;
    }

    /* 使能中断 */
    rt_hw_interrupt_enable(level);
    RT_OBJECT_HOOK_CALL(rt_object_take_hook, (&(event->parent.parent)));//调用钩子函数
    return thread->error;
}
```

## 事件集的使用场景

事件集用途广泛，一定程度上可以替代信号量用于线程间同步

==**但是**==，事件的发送操作在事件未清除前是不可累积的，但信号量或互斥量的释放动作可以累计。同时，事件可以进行一对多或多对多同步，信号量无法完成这一点