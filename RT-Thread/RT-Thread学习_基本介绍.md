# RT-Thread组成

1. 内核层：RT-Rhread内核，包括内核系统中对象的实现、libcpi/BSP（芯片移植相关文件/板级支持包），与硬件密切相关，由外设驱动和CPU移植构成
2. 组件与服务层：组件即**基于内核之上的上层软件**，如虚拟文件系统、FinSH命令行界面、网络框架、设备框架等。采用模块化设计，组件内部高内聚、组件之间低耦合
3. RT-Thread软件包：运行在操作系统平台上，面向不同应用领域的通用软件组件，由描述信息、源代码或库文件组成

# 内核基础

内核位于硬件层之上，包括**内核库**、**实时内核实现**

内核库是为了保证内核能够独立运行的一套小型的类似C库的函数实现子集，根据编译器的不同自带c库的情况也会有些不同（当使用GNU GCC编译器时，会携带更多的标准c库实现）

*C库又叫C运行库（C Runtime Library），提供了类似"strcpy"、"memcpy"等函数，有些也会包括"printf"、"scanf"等函数的实现，RTT Kernal Service Library仅提供内核用到的一小部分C库函数实现，这些函数前都会加上rt_前缀*

实时内核实现包括：对象管理、线程管理 及 调度器、线程间通信管理、时钟管理及内存管理等

内核最小资源占用：3KB ROM 1.2KB RAM

![image-20210104163844358](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210104163844358.png)

## 线程调度

线程是RTT中的最小调度单位

线程调度算法：**基于优先级的全抢占式多线程调度算法**

支持256个线程优先级，针对stm32默认配置32个线程优先级，==**0优先级代表最高优先级**==

最低优先级留给空闲进程

支持创建多个相同优先级的线程，之间采用**时间片的轮转调度算法**进行调度，**能使每个线程运行相应时间**

线程数目只和硬件平台的具体内存相关

## 时钟管理

时钟节拍是RTT的最小时钟单位

RTT定时器提供两类定时器机制：

1. 单次触发定时器：启动后只触发一次定时器事件，然后定时器停止
2. 周期触发定时器：传统定时器的工作方式

根据超时函数执行时所处的上下文环境，RTT的定时器可设置为HARD_TIMER模式或SOFT_TIMER模式

通常使用**定时器回调函数（超时函数）**完成定时任务

## 线程间同步

采用**信号量、互斥量、事件集**实现

见后续线程间同步介绍

## 线程间通信

支持**邮箱、消息队列**等通信机制，邮箱中一封邮件的长度固定为4字节大小；消息队列能接受不固定长度的消息并将其缓存在自己的内存空间中

邮箱效率比消息队列更高效

邮箱和消息队列的发送动作可安全用于中断服务例程中，线程可按优先级等待或按FIFO方式获取

见后续介绍

## 内存管理

RTT支持静态内存池管理和动态内存堆管理

静态内存池有可用内存时：系统对内存块分配的时间是恒定的

### 静态内存池

静态内存池空时：系统将申请内存块的线程挂起（线程等待一段时间后仍未获得内存块就放弃申请并返回）或阻塞（立刻返回），当其他线程释放内存块到内存池时，如果有挂起的待分配内存块的线程存在，则系统会将这个线程唤醒

### 动态内存堆

根据系统资源不同，可提供面向小内存的内存管理算法和面向大内存的SLAB内存管理算法

系统内包含多个地址不连续内存堆时，可使用memheap管理算法将多个内存堆”粘贴“在一起，”虚拟“出一个内存堆

## IO设备管理

RTT将PIN、IIC、SPI、USB、USART等作为外设设备，统一通过设备注册完成

实现了**可按名称访问**的**设备管理子系统**，可按照统一的API界面访问硬件设备

根据MCU系统的特点对不同设备可挂接相应事件，当设备事件触发时，由驱动程序通知给上层的应用程序

见后续介绍

## 程序内存分配

一般MCU包括片上FLASH和片上RAM，RAM相当于内存，FLASH相当于硬盘，编译器会将一个程序分为**多个部分，分别存储在MCU不同的存储区**

keil编译完成后会显示

```c
Program Size: Code=2932 RO-data=424 RW-data=28 ZI-data=1836
After Build - User command #1: fromelf --bin .\build\rtthread-stm32.axf --output rtthread.bin
```

Code:代码段，存放程序的*代码*部分

RO-data:只读数据段(Read Only)存放程序中定义的*常量*

RW-data:读写数据段(Read&Write)存放初始化为*非0值的全局变量*

ZI-data:零数据段(Zero)存放*初始化为0的变量*和*未初始化的全局变量*

编译以后工程会生成一个.map文件，说明各个函数占用的尺寸和地址

```c
Total RO  Size (Code + RO Data)                63528 (  62.04kB)
Total RW  Size (RW Data + ZI Data)             22576 (  22.05kB)
Total ROM Size (Code + RO Data + RW Data)      63676 (  62.18kB)
```

RO Size包含Code和RO-data，表示程序占用FLASH大小

RW Size包括RW-data和ZI-data，表示程序运行时占用RAM大小

ROM Size包括Code、RO data、RW data，表示烧写程序所占用的FLASH大小

程序经过编译后生成的bin或hex文件称为**可执行映像文件**，包含RO段（包括Code、RO-data）和RW段（包括RW-data，ZI-data不包含在映像文件中），它们被存储在FLASH中。stm32上电后默认从FLASH启动，启动后会将RW段的RW-data搬运到RAM中，但不会搬运RO段，另外根据编译器给出的ZI地址和大小分配出ZI段，并将这块RAM区域清零。即**CPU从FLASH读取执行代码，从RAM中读取所需的数据，根据预先规定的ZI地址分配清零的ZI段，剩余RAM空间作为动态内存堆**

![image-20210104151601680](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210104151601680.png)

动态内存堆用于rt_malloc()申请内存

## RTT自动初始化机制

自动初始化机制：初始化函数不需要被显式调用，只要在函数定义处通过宏定义的方式进行申明，就会在系统启动过程中被执行

自动初始化机制使用了**自定义RTI符号段**，将需要在启动时进行初始化的函数指针放到了该段中，形成一张初始化函数表，在系统启动过程中会遍历该表，并调用表中的函数，达到自动初始化的目的

自动初始化宏接口定义如下：

| 初始化顺序 | 宏接口                  | 描述                             |
| ---------- | ----------------------- | -------------------------------- |
| 1          | INIT_BOARD_EXPORT()     | 调度器启动之前初始化             |
| 2          | INIT_PREV_EXPORT()      | 纯软件初始化，没有太多依赖的函数 |
| 3          | INIT_DEVICE_EXPORT()    | 外设驱动初始化                   |
| 4          | INIT_COMPONENT_EXPORT() | 组件初始化                       |
| 5          | INIT_ENV_EXPORT()       | 系统环境初始化                   |
| 6          | INIT_APP_EXPORT()       | 应用初始化                       |

由INIT_BOARD_EXPORT()申明的函数会被放在**位于内存分布的RO段内的RTI符号段中**，该RTI符号段中的所有函数在系统初始化时会被自动调用

## 内核对象模型

==**RTT内核采用面向对象的设计思想**==

系统及的基础设施都是一种内核对象

### 静态对象和动态对象

内核对象分成静态内核对象和动态内核对象

1. 静态对象

放在RW段和ZI段中，在系统启动后，在程序中初始化

在编译时决定使用堆栈空间等设置，占用RAM空间不依赖内存堆管理器，内存分配时间确定

2. 动态对象

位于内存堆，手工做初始化

在运行中动态调整堆栈设置等，依赖于内存堆管理器，运行时申请RAM空间，对象被删除后占用的RAM空间会被释放

### 内核对象管理架构

**内核对象管理系统**负责访问/管理所有内核对象，包括线程、信号量、互斥量、事件、邮箱、消息队列、定时器、内存池、设备驱动等

**对象容器**包含了每类对象的信息，包括对象类型、大小等。对象容器给每类内核对象分配一个链表，所有内核对象都被链接到该链表上

![image-20210104163823932](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210104163823932.png)

对于每一种具体内核对象和对象控制块，除了基本结构外，还有自己的扩展属性（**私有属性**），可认为==每一种具体对象是抽象对象的派生，继承了基本对象的属性并在此基础上扩展了与自己相关的属性==

**对象管理模块**中定义了通用的数据结构来保存各种对象的共同属性，具体对象只要在此基础上加上自己某些特有属性就可以表示自己的特征。

### 对象控制块

```c
struct rt_object
{
    char name[RT_NAME_MAX];//内核对象名称
    rt_uint8_t type;//内核对象类型
    rt_uint8_t flag;//内核对象参数

#ifdef RT_USING_MODULE
    void *module_id;//应用模块的id
#endif
    
    rt_list_t list;//内核对象管理链表
};
typedef struct rt_object *rt_object_t;//将内核对象指针封装成“内核对象类”
```

如果是静态对象，对象类型的最高位为1，否则就是动态对象

系统最多能容纳的对象类别数目是127个

### 内核对象容器

```c
struct rt_object_information
{
    enum rt_object_class_type type;//对象类型
    rt_list_t object_list;//对象链表
    rt_size_t object_size;//对象大小
};
```

一类对象由一个rt_object_information结构体管理，每个这类对象的具体实例都通过链表的形式挂接在object_list上。这一类对象的内存块尺寸由object_size标识出来

注意：==每一类对象的具体实例占有的内存块大小都相同==

使用接口rt_object_init()对**未初始化的静态对象进行初始化**

```c
void rt_object_init(struct rt_object *object,//对象指针，不能为空指针或野指针
                    enum rt_object_class_type type,//对象类型，必须是rt_object_class_type中列出的
                    const char *name)//对象名，最大长度由RT_NAME_MAX决定，系统不关心它是否由'\0'为结尾
{
    register rt_base_t temp;
    struct rt_object_information *information;
#ifdef RT_USING_MODULE
    struct rt_dlmodule *module = dlmodule_self();
#endif

    /* 获取对象信息 */
    information = rt_object_get_information(type);
    RT_ASSERT(information != RT_NULL);

    /* 初始化对象参数 */

    /* 将目标对象视为静态对象 */
    object->type = type | RT_Object_Class_Static;

    /* 复制名字 */
    rt_strncpy(object->name, name, RT_NAME_MAX);

    RT_OBJECT_HOOK_CALL(rt_object_attach_hook, (object));

    /* 锁定中断 */
    temp = rt_hw_interrupt_disable();

#ifdef RT_USING_MODULE
    if (module)
    {
        rt_list_insert_after(&(module->object_list), &(object->list));
        object->module_id = (void *)module;
    }
    else
#endif
    {
        /* 将这个对象节点插入对象容器的对象链表 */
        rt_list_insert_after(&(information->object_list), &(object->list));
    }

    /* 解锁中断 */
    rt_hw_interrupt_enable(temp);
}
```

使用rt_object_detach()将一个**静态内核对象**从内核对象容器中**脱离**（即 从内核对象容器链表上删除相应的对象节点）

注意：==对象脱离后，对象占用的内存并不会被释放==

```c
void rt_object_detach(rt_object_t object)
{
    register rt_base_t temp;

    /* 检验参数指针是否为空指针或野指针 */
    RT_ASSERT(object != RT_NULL);

    RT_OBJECT_HOOK_CALL(rt_object_detach_hook, (object));

    /* 清空对象类型 */
    object->type = 0;

    /* 锁定中断 */
    temp = rt_hw_interrupt_disable();

    /* 从链表中删除对象 */
    rt_list_remove(&(object->list));

    /* 解锁中断 */
    rt_hw_interrupt_enable(temp);
}
```

使用接口rt_object_allocate()**分配新的动态对象**

若分配成功，则返回==分配成功对象的句柄==；若分配失败，则返回==RT_NULL==

```c
rt_object_t rt_object_allocate(enum rt_object_class_type type, const char *name)
{
    struct rt_object *object;
    register rt_base_t temp;
    struct rt_object_information *information;
#ifdef RT_USING_MODULE
    struct rt_dlmodule *module = dlmodule_self();
#endif

    RT_DEBUG_NOT_IN_INTERRUPT;

    /* 获取对象信息 */
    information = rt_object_get_information(type);
    RT_ASSERT(information != RT_NULL);

    object = (struct rt_object *)RT_KERNEL_MALLOC(information->object_size);
    if (object == RT_NULL)
    {
        /* 若不存在可分配的内存 */
        return RT_NULL;
    }

    /* 清空对象所需的内存空间 */
    rt_memset(object, 0x0, information->object_size);

    /* 初始化对象参数 */

    /* 设置对象类型 */
    object->type = type;

    /* 设置对象参数 */
    object->flag = 0;

    /* 命名对象 */
    rt_strncpy(object->name, name, RT_NAME_MAX);

    RT_OBJECT_HOOK_CALL(rt_object_attach_hook, (object));

    /* 锁定中断 */
    temp = rt_hw_interrupt_disable();

#ifdef RT_USING_MODULE
    if (module)
    {
        rt_list_insert_after(&(module->object_list), &(object->list));
        object->module_id = (void *)module;
    }
    else
#endif
    {
        /* 将对象插入链表 */
        rt_list_insert_after(&(information->object_list), &(object->list));
    }

    /* 解锁中断 */
    rt_hw_interrupt_enable(temp);

    /* 返回对象句柄 */
    return object;
}
```

使用接口rt_object_delete()删除对象，释放系统资源

```c
void rt_object_delete(rt_object_t object)
{
    register rt_base_t temp;

    /* 检查传入指针是否为空指针或野指针 */
    RT_ASSERT(object != RT_NULL);
    RT_ASSERT(!(object->type & RT_Object_Class_Static));

    RT_OBJECT_HOOK_CALL(rt_object_detach_hook, (object));

    /* 设定对象类型 */
    object->type = 0;

    /* 锁定中断 */
    temp = rt_hw_interrupt_disable();

    /* 从旧链表中删除 */
    rt_list_remove(&(object->list));

    /* 解锁中断 */
    rt_hw_interrupt_enable(temp);

    /* 释放对象分配得的内存 */
    RT_KERNEL_FREE(object);
}
```

使用接口rt_object_is_systemobject()判断一个对象是否为系统对象（静态对象），使用接口rt_object_get_type获取一个对象的类型

```c
rt_bool_t rt_object_is_systemobject(rt_object_t object)
{
    /* 检查传入指针是否为空指针或野指针 */
    RT_ASSERT(object != RT_NULL);

    if (object->type & RT_Object_Class_Static)
        return RT_TRUE;//如果该对象是静态对象，则返回True

    return RT_FALSE;//否则返回False
}

rt_uint8_t rt_object_get_type(rt_object_t object)
{
    /* 检查传入指针是否为空指针或野指针 */
    RT_ASSERT(object != RT_NULL);

    return object->type & ~RT_Object_Class_Static;//如果是静态对象，则返回对象类型
}
```

## 内核自定义

在rtconfig.h文件中可修改宏定义来对代码进行条件编译，最终达到系统配置和裁剪的目的

```c
#ifndef RT_CONFIG_H__
#define RT_CONFIG_H__

/* Automatically generated file; DO NOT EDIT. */
/* RT-Thread Configuration */

/* 内核 */
#define RT_NAME_MAX 8//内核对象名称最大长度，若代码中对象名称长度超出，多余部分会被截掉
#define RT_ALIGN_SIZE 4//字节对齐时设定对齐的字节个数，使用ALIGN(RT_ALIGN_SIZE)进行字节对齐
#define RT_THREAD_PRIORITY_32//系统线程优先级数
#define RT_THREAD_PRIORITY_MAX 32
#define RT_TICK_PER_SECOND 100//时钟节拍
#define RT_DEBUG//是否开启debug模式
#define RT_USING_OVERFLOW_CHECK//栈溢出监测
#define RT_DEBUG_INIT 0//是否打印组件初始化信息
#define RT_DEBUG_THREAD 0//是否打印线程切换信息
#define RT_USING_HOOK//是否开启钩子函数的使用
#define IDLE_THREAD_STACK_SIZE 256//空闲线程的栈大小

/* 线程间通信 */
#define RT_USING_SEMAPHORE//是否开启信号量使用
#define RT_USING_MUTEX//是否开启互斥量使用
#define RT_USING_EVENT//是否开启事件集使用
#define RT_USING_MAILBOX//是否开启邮箱使用
#define RT_USING_MESSAGEQUEUE//是否开启消息队列使用
#define RT_USING_SIGNALS//是否开启信号使用

/* 内存管理 */
#define RT_USING_MEMPOOL//是否开启静态内存池使用
#define RT_USING_MEMHEAP//是否开启两个或以上内存堆拼接
#define RT_USING_SMALL_MEM//是否开启小内存管理算法
#define RT_USING_HEAP//是否开启堆使用

/* 内核设备对象 */
#define RT_USING_DEVICE//开启系统设备
#define RT_USING_CONSOLE//使用系统控制台设备
#define RT_CONSOLEBUF_SIZE 128//控制台设备缓冲区大小
#define RT_CONSOLE_DEVICE_NAME "uart1"//控制台设备名称

/* 自动初始化方式 */
#define RT_USING_COMPONENTS_INIT//是否开启自动初始化机制
#define RT_USING_USER_MAIN//设置应用入口为用户main函数
#define RT_MAIN_THREAD_STACK_SIZE 2048//main线程的栈大小

/* C++特性 */

/* 命令行FinSH */
#define RT_USING_FINSH//是否开启FinSH调试工具
#define FINSH_THREAD_NAME "tshell"//FinSH线程名称
#define FINSH_USING_HISTORY//是否使用历史命令
#define FINSH_HISTORY_LINES 5//对历史命令行数的定义
#define FINSH_USING_SYMTAB//是否开启Tab键补全
#define FINSH_USING_DESCRIPTION//是否启用描述
#define FINSH_THREAD_PRIORITY 20//定义该线程优先级
#define FINSH_THREAD_STACK_SIZE 4096//定义该线程栈大小
#define FINSH_CMD_SIZE 80//命令字符长度
#define FINSH_USING_MSH//是否开启MSH
#define FINSH_USING_MSH_DEFAULT//是否默认使用MSH
#define FINSH_USING_MSH_ONLY//是否仅使用MSH

/* 设备驱动 */
#define RT_USING_DEVICE_IPC//开启IPC
#define RT_USING_SERIAL//使用串口
#define RT_USING_PIN//开启PIN

/* USB使用 */

/* MCU与C标准库 */
#define STM32F103ZE//该工程使用STM32F103ZE
#define RT_HSE_VALUE 8000000//时钟源频率为8000000
#define RT_USING_UART1//开启UART1

#endif
```



