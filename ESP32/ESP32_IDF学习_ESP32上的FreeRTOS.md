[TOC]

# Bootloader

ESP32的Bootloader（引导加载程序）主要执行以下任务：

1. 内部模块的基础初始化配置
2. 根据**分区表**和**ota_data**（如果存在）选择需要引导的应用程序（app）分区
3. 将应用程序映像加载到 RAM（IRAM和DRAM）中
4. 完成以上工作后把控制权转交给应用程序

**引导加载程序位于Flash的偏移地址0x1000处**

## 分区表

每片ESP32的flash可以包含多个应用程序，以及多种不同类型的数据（例如校准数据、文件系统数据、参数存储器数据等），使用**分区表**对这些程序和数据进行规划

ESP32 在flash的**默认偏移地址0x8000**处烧写一张分区表

该分区表的长度为0xC00字节，**最多可以保存95条分区表条目**。分区表数据后还保存着该表的MD5校验和用于验证分区表的完整性。此外，如果芯片使能了安全启动功能，该分区表后还会保存签名信息

分区表中的每个条目都包括以下几个部分：Name（标签）、Type（app、data 等）、SubType 以及在flash中的偏移量（分区的加载地址）

烧写到ESP32中的分区表采用二进制格式，而不是CSV文件本身。ESP-IDF提供了gen_esp32part.py工具来配置、构建分区表

## 默认分区表

menuconfig中自带了两套分区表，如果编写大程序会经常遇到空间不足的问题（特别是当你像我一样买了16MB超大FLASH的白金纪念典藏款ESP32-WROOM-32E，甚至还想外挂一个W25Q128（16MB）时会经常感觉默认分区表把FLASH都浪费了），但是很适合学习开发使用

* Single factory app, no OTA
* Factory app, two OTA definitions

两个选项，都将出厂应用程序烧录至flash的0x10000偏移地址处，但是一个没有OTA分区，一个有OTA分区

它们都在0x10000 (64KB)偏移地址处存放一个标记为 “factory” 的二进制应用程序，且Bootloader将默认加载这个应用程序

分区表中还定义了两个数据区域，分别用于存储NVS库专用分区和PHY初始化数据

带OTA分区的`Factory app, two OTA definitions`里还新增了otadata的数据分区，用于保存OTA升级所需的数据，Bootloader还会查询该分区的数据来 判断从哪个OTA应用程序分区加载程序，如果这个分区为空则会执行出厂程序

## 自定义分区表

在menuconfig里选择了“自定义分区表”选项后，输入该分区表的路径和完整文件名就可以使用自定义分区表了

分区表以CSV的格式书写，用“#”注释；offset字段可以为空，程序会自动计算并填充该分区的偏移地址，但size字段一定要填写好

说明如下（抄自官网文档）

* Name字段可以是任何有意义的名称，但不能超过 16 个字符（之后的内容将被截断）

* Type 字段可以指定为app (0) 或data (1)，也可以直接使用数字0-254（或者十六进制 0x00-0xFE）；但**0x00-0x3F不得使用**（预留给 esp-idf 的核心功能）；bootloader将忽略 app (0) 和 data (1) 以外的其他分区类型

* SubType 字段长度为8位，内容与具体Type有关。目前esp-idf仅仅规定了“app”和“data”两种子类型

  * 当 Type 定义为 `app` 时，SubType 字段可以指定为 factory (0)，ota_0 (0x10) … ota_15 (0x1F) 或者 test (0x20)
  * 当 Type 定义为 `data` 时，SubType 字段可以指定为 ota (0)，phy (1)，nvs (2) 或者 nvs_keys (4)

  其中factory (0) 是Bootloader默认跳转到的app分区；ota(0)是OTA数据分区；nvs(2)是NVS专用的分区，最好分配至少0x3000字节的空间；nvs_keys(4)是密钥分区，用于NVS加密相关功能；phy(1)是用于存放PHY初始化数据的分区，默认配置下phy分区并不启用，会直接将phy初始化数据编译至应用程序中，使能CONFIG_ESP32_PHY_INIT_DATA_IN_PARTITION后才能使用该分区

* 分区若为指定偏移地址，则会紧跟着前一个分区之后开始。若此分区为首个分区，则将紧跟着分区表开始。app 分区的偏移地址必须要与 0x10000 (64K) 对齐，如果将偏移字段留空，`gen_esp32part.py` 工具会自动计算得到一个满足对齐要求的偏移地址。如果 app 分区的偏移地址没有与 0x10000 (64K) 对齐，则该工具会报错

* Flags 分区当前仅支持 `encrypted` 标记。如果 Flags 字段设置为 `encrypted`，且已启用Flash Encryption（FLASH加密）功能，则该分区将会被加密

通过改动示例分区表就能配置新的分区表

```cmake
# Name,   Type, SubType, Offset,   Size, Flags
# 注意，如果你增大了引导加载程序的大小，请确保更新偏移量，避免和其它分区发生重叠
nvs,      data, nvs,     0x9000,   0x4000 # NVS分区
otadata,  data, ota,     0xd000,   0x2000 # OTA数据分区
phy_init, data, phy,     0xf000,   0x1000 # 初始化分区
factory,  0,    0,       0x10000,  1M # 工厂分区
test,     0,    test,    ,         512K # 保留分区
ota_0,    0,    ota_0,   ,         512K # 第一OTA分区，一般用于OTA烧录
ota_1,    0,    ota_1,   ,         512K # 第二OTA分区，一般用于OTA回滚或备份
```

## 出厂程序

出厂程序就是按下复位按钮后从串口喷涌而出的那一堆自检信息

自定义出厂程序还可以把自己想要的图标通过字符画的形式扔进去，开机的时候就会刷出来，比如可以刷个Ubuntu字符画假装移植了linux（误）

```
                          ./+o+-
                  yyyyy- -yyyyyy+
               ://+//////-yyyyyyo
           .++ .:/++++++/-.+sss/`
         .:++o:  /++++++++/:--:/-
        o:+o+:++.`..```.-/oo+++++/
       .:+o:+o/.          `+sssoo+/
  .++/+:+oo+o:`             /sssooo.
 /+++//+:`oo+o               /::--:.
 \+/+o+++`o++o               ++////.
  .++.o+++oo+:`             /dddhhh.
       .+.o+oo:.          `oddhhhh+
        \+.++o+o``-````.:ohdhhhhh+
         `:o+++ `ohhhhhhhhyo++os:
           .o:`.syhhhhhhh/.oo++o`
               /osyyyyyyo++ooo+++/
                   ````` +oo+++o\:
                          `oo++.
```

## 恢复出厂设置

通过设置CONFIG_BOOTLOADER_FACTORY_RESET来使能GPIO触发恢复出厂设置

恢复出厂设置时将进行以下操作：

1. 清除所有数据分区
2. 从工厂分区启动

## 自定义Bootloader

用户可以自定义当前的Bootloader

1. 复制`/esp-idf/components/bootloader`文件夹到项目目录
2. 编辑`/your_project/components/bootloader/subproject/ain/bootloader_main.c`文件

注意：**在引导加载程序的代码中，用户不可以使用驱动和其他组件提供的函数**，如果确实需要，应该将该功能的实现部分放在bootloader目录中（会增加引导程序的大小）

目前，引导程序被限制在了分区表之前的区域（分区表位于0x8000地址处）

# 应用级程序追踪

ESP-IDF提供实用的dubug功能，能够通过menuconfig开启，并通过调用库函数进行使用，可以通过JTAG在ESP32和主机之间传输debug logs，可用于：

* 跟踪特定应用程序
* 记录日志到主机
* 基于SEGGEr SystemView进行系统行为分析

在程序中`#incldue "esp_app_trace.h"`即可使用相关库函数

当前这个debug功能已经比较完善，可以用来做调试，但是因为它通过库函数进行数据发送，可能会对正常程序执行造成干扰，使用位置需要注意

# FreeRTOS简介

*详细内容可以参考FreeRTOS相关教程*

**以下内容应当由接触过RTOS的同学学习，如果你还没碰过RTOS，还像我这样遇上了老师发的离谱作业，千万不要慌，先去按照下面这些标题百度/google/bing一通，弄得差不多再读一读下面的API讲解应该就能糊弄过去了**

顾名思义，freeRTOS是free的RTOS，具有以下特点：

* FREE！FreeRTOS使用LGPL协议，开源且可用于商业，很自由（虽然FSF那帮人可能觉得LGPL不够自由）
* 小内核、模块化、扩展性强
* 高效、便于使用
* **用户无需关心时间信息**，内核中的相关模块会负责处理计时任务和线程调度

## 内核组成

FreeRTOS是一个可裁剪、可剥夺型（也可根据用户需要裁剪为不可剥夺型）的多任务内核，**不设置任务数限制**。

内涵和基于硬件适配层实现跨平台移植

### 源码结构

这里参考的FreeRTOS源码是在[官网](https://freertos.org/)上下载到的/freertos/FreeRTOSv10.4.1/FreeRTOS/Source目录下的部分

FreeRTOS-Plus包含kernal之外的系统常用功能组件

Source目录下才是kernal相关源码

* list.c任务链表模块
* queue.c消息队列模块
* tasks.c任务配置模块
* timers.c系统定时器模块
* event_groups.c事件集模块
* include目录是各种头文件

### 任务管理（线程管理、线程调度）

#### 优先级抢占式调度算法

最低优先级是0，**优先级数字越大，当前任务越优先**

**不同任务可以共用同一个优先级**

### 时间管理（时钟节拍）

FreeRTOS使用系统节拍（systick）确定其运行时钟，这个系统节拍由硬件定时器中断引起

使用**configCPU_CLOCK_HZ**设置当前硬件平台CPU的系统时钟，单位Hz

使用**configTICK_RATE_HZ**设置FreeRTOS的时间片频率（1秒钟可以切换多少次任务），单位Hz

#### ESP32的硬件定时器

ESP32提供两组硬件定时器，每组包含两个64位通用定时器，共**4个通用定时器**，分别标记为TIMER0-3。

所有定时器均包括16位预分频器和64位自动重载向上/向下计数器

##### 定时器初始化

使用timer_config_t结构体配置定时器参数，然后将这个结构体作为参数传递给timer_init()函数来进行定时器初始化

可设置的参数如下：

```c
struct timer_config_t
{
	timer_alarm_t alarm_en;//是否使能报警
	timer_start_t counter_en;//是否是能计数器
    timer_intr_mode_t intr_type;//选择定时器警报上触发的中断类型
    timer_count_dir_t counter_dir;//选择向上/向下计数
    timer_autoreload_t auto_reload;//设置计数器是否在定时器警报上使用auto_reload自动重载首个计数值，或者继续递增/递减
    uint32_t divider;//计数器分频器，可设置为2-65536，用作输入的80MHz APB_CLK时钟的分频系数
}
```

使用timer_get_copnfig()获取定时器设置的当前值

##### 定时器控制

1. 开启定时器

设置timer_config_t::counter_en位true后调用timer_init()初始化即可开启定时器

或者也可以直接调用timer_start()来开启定时器

调用timer_pause()随时暂停定时器

2. 设置计数值

可以通过调用timer_set_counter_value()来指定定时器的首个计数值

使用timer_get_counter_value()或timer_get_counter_time_sec()检查定时器的当前值

3. 设置警报

先调用函数timer_set_alarm_value()设置警报值，再调用timer_set_alarm()使能警报，或在初始化阶段通过设置初始化结构体来设置警报值并开启警报

**当警报使能且定时器到达警报值后，可以触发中断或重新加载**

如果auto_reload已使能，定时器的计数器将重新加载，从之前设置好的值重新计数，使用timer_set_counter_value()预先设置该值

如果已设置警报值且定时器已经超过该值，则将立即触发警报

**警报一旦触发，将自动关闭，需要重新使能以再次触发**

使用timer_get_alarm_value()来获取特定的警报值

调用函数timer_isr_register()来为特定定时器组和定时器注册中断服务程序

使用timer_group_intr_enable()来使能定时器组的中断程序，使用timer_enable_intr()使能某定时器的中断程序；使用timer_group_intr_disable()和timer_disable_intr()关闭对应的中断程序

在中断服务程序中处理中断时，需要明确地清除中断状态位，通过以下设置来清除某定时器的中断状态位

```c
TIMERGN.int_clr_timers.tM = 1;

//TIMERGN中的N代表定时器组别编号，可设置0或1
//tM中的M代表定时器编号，可设置为0或1

TIMERG0.int_clr_timers.t1 = 1;//清除定时器组别0中定时器1的中断状态位
```

#### ESP32中的FreeRTOS时钟

ESP32中的FreeRTOS使用任意硬件定时器通过开启警报中断模式来实现系统时钟（systick）

定时器计数器到达预设警报值后，将触发中断，调用相关API来让RTOS的系统时钟+1

一般这个API由PRO_CPU执行

### 内存管理（内存堆）

FreeRTOS可以使用四种内存分配方案

1. heap1.c

分配简单，时间确定，实时性强

只分配内存不回收内存，容易造成资源浪费

2. heap2.c

链表式内存块结构分配

动态分配、最佳匹配

容易造成内存碎片且时间不可控

3. heap3.c

调用标准库函数分配内存

速度较慢且内存分配时间不确定

4. heap4.c

按照物理地址对内存进行排序

使相邻的内存空间可以合并

容易造成内存碎片且合并效率低

### 通信管理（消息队列、事件集、信号量、互斥量）

#### 消息队列

使用FIFO队列的数据结构处理消息的存储和传输

消息发出后被缓存到FIFO队尾，其他任务可以调用接收消息的API接收队首的消息，该消息被接收后，后面的消息会自动前进

### 事件集

用于取代全局变量标志，更加安全（但**更慢**）

# ESP32上的FreeRTOS

【翻译自官网】==普通的FreeRTOS运行在单核上，不彳亍！我们的ESP32-FreeRTOS能运行在双核，彳亍！==

众所周知，ESP32是物美价廉的双核SoC，CPU0和CPU1同时运行、共享内存。乐鑫修改了普通的FreeRTOS，让它能够支持SMP（symmetric multiprocessing对称多处理），所以ESP32的FreeRTOS变成了基于FreeRTOS v8.2.0的Xtensa架构移植版SMP RTOS

**下面对移植版的FreeRTOS简称为SMP RTOS**，

【补充】对称多处理（SMP）架构是一种两个或多个CPU共享同一内存公共链路的计算机体系结构

*他改变了FreeRTOS*

## backport

v9.0版本的FreeRTOS特性被部分移植到了基于v8.0版本的ESP32-SMP-RTOS中

任务删除机制使用v9.0版本的：使用vTaskDelete()后任务会被立刻删除；如果任务在此时正好被另一个核心运行，那么释放内存的步骤会被交给空闲线程（空闲任务）

也引入了TLSP（Thread Local Storage Pointers线程本地存储指针）机制，当任务删除时删除回调函数会被自动执行，这个函数用于释放被TLSP指向的内存区域

* TLSP是指向TCB存储区的指针，它可以让每个任务都有自己独立的一套数据结构指针系统；SMP RTOS也提供了通过删除回调函数和TLSP执行的任务删除机制：当任务删除函数被调用，任务转到空闲线程后触发这个回调函数，可以配置为自动删除任务的内存空间，但是**不要在这个回调函数中加入阻塞的、延时的、临界区等相关代码！尽可能让回调函数短小来确保系统实时性**

* 回调函数的类型是

  ```c
  void (*TlsDeleteCallbackFunction_t)(int,void*)
  ```

  这里针对c语言基础不太好的老哥解释一下：这是一个函数指针，它指向一个“以int型变量和任意指针为参数”，“无返回值”的函数

  第一个参数是关联的TLSP的序号，第二个参数是TLSP自身（它本身就是个指针）

  如果一个删除回调函数设置为空，那么用户需要在TLSP被删除之前手动释放指向关联的TLSP指向部分的内存，否则就会造成TLSP指向的部分内存变成“无主内存”，导致内存溢出

## 双核任务

使用

```c
BaseType_t xTaskCreatePinnedToCore(TaskFunction_t pvTaskCode,
                                   const char *const pcName,
                                   const uint32_t usStackDepth,
                                   void *const pvParameters,
                                   UBaseType_t uxPriority,
                                   TaskHandle_t *const pvCreatedTask,
                                   const BaseType_t xCoreID);

TaskHandle_t xTaskCreateStaticPinnedToCore(TaskFunction_t pvTaskCode,
                                           const char *const pcName,
                                           const uint32_t ulStackDepth,
                                           void *const pvParameters,
                                           UBaseType_t uxPriority,
                                           StackType_t *const pxStackBuffer,
                                           StaticTask_t *const pxTaskBuffer,
                                           const BaseType_t xCoreID)
```

创建SMP任务

最后的xCoreID设置为0或1，分别表示单独在PRO_CPU或APP_CPU上运行任务，也可以设置tskNO_AFINITY来允许任务在两个核心上运行

SMP RTOS使用**轮询调度算法**来进行任务调度，然而当两个相同优先级的任务同时处于就绪态时会被轮询算法跳过。应当通过任务阻塞或设置宽优先级的方式避免这种情况

任务挂起仅会对独立的核心起效，另一个核心上运行的任务不会受到任务挂起的影响

传统FreeRTOS的xTaskCreate()和xTaskCreateStatic()函数被以内联函数的形式重定义为上述两个函数，并默认使用tskNO_AFFINITY作为xCoreID的参数

每个任务控制块（TCB Task Control Block）将xCoreID作为一个成员存储起来，因此每个核心都会调用调度器来选择一个任务来运行，**调度器会根据xCoreID成员变量决定是否让被核心请求运行的任务在该核心上运行**（人话：核心请求运行某个任务，调度器会查看这个任务的xCoreID成员变量，如果符合这个核心，就让任务运行，否则会将任务放到任务链表尾并让当前核心尝试申请下一个任务）

### 任务调度

传统的FreeRTOS通过vTaskSwitchContext()函数执行线程调度。这个函数会从就绪任务链表（由处于就绪态的任务组成）中选取最高优先级的任务来运行。但在SMP RTOS中，每个核心都会独立调用vTaskSwitchContext()来从两个核心共用的就绪任务链表中选取任务来执行。SMP RTOS与传统FreeRTOS关于任务调度的区别如下所示：

* 轮询调度算法：一般的FreeRTOS会在每个任务之间执行轮询调度，不会遗漏任何任务（一般通过遍历链表的方法进行轮询）；而SMP RTOS可能会在轮询调度多个相同优先级的就绪态任务中跳过其中的一部分

  传统FreeRTOS中，使用pxReadyTasksList这个链表结构体来管理就绪态任务链表，相同优先级的任务被挂到相同链表上，这些链表被按照优先级从高到低挂到pxReadyTasksList链表中，pxIndex指针会指向刚刚被调用过的TCB

  图示如下：

![](C:\Users\NH55\Pictures\Screenshots\freertos-ready-task-list.png)



然而在SMP RTOS中，就绪链表被两个核心共享，因此pxReadyTasksList会包含固定在两个不同核心上的任务，共用一个核心调用调度器时会发生抢占资源的情况，这种情况下资源调度器会查询TCB的xCoreID成员变量来决定一个任务是否被允许在当前请求执行的CPU上运行。虽然每个TCB都有一个xCoreID成员变量，但每个优先级链表中只有一个pxIndex，因此**调度器从某个核心被调用并遍历链表时，他会跳过被标记为另一个核心才能执行的任务**，如果另一个核心在此之后请求调度器分配任务，则pxIndex会从头开始遍历链表，来自另一个核心的上一个调度器并不会在当前核心的当前调度器的考虑范围内；当一个核心正在执行任务时，另一个核心请求分配任务，会从当前pxIndex的位置向后进行遍历。这就导致了一个问题：

![ESP-IDF pxIndex Behavior](https://docs.espressif.com/projects/esp-idf/zh_CN/release-v4.1/_images/freertos-ready-task-list-smp-pxIndex.png)

如上图所示，蓝色和橙色标明了由哪个CPU执行这个任务，当任务A被PRO_CPU执行时，APP_CPU申请分配任务，调度器自动从1向后遍历，找到了任务C；之后任务A完成，PRO_CPU请求分配任务，调度器从2向后遍历找到了任务3——这就导致任务B被跳过了！

解决的方法是**确保每个任务都会进入一段时间的阻塞态来让他们从就绪任务链表中移除，或是让每个任务分配不同的优先级**

## 中断同步

CPU0和CPU1的中断不同步

不要想当然地用任务延迟函数来进行两个核心之间的任务同步，如果**需要任务同步可以使用信号量**来进行

* 调度器阻塞：一般的FreeRTOS中，使用vTaskSuspendAll()来挂起调度器，这会阻止任务调度，但是中断服务函数ISR还是会运行；在SMP RTOS中，vTaskSuspendAll()只会阻止一个CPU的任务调度，另一个CPU还是会运行，这个机制很可能会引起数据阻塞、任务不同步等情况，所以最好不要使用vTaskSuspendAll()而是换用互斥量来保护临界区
* SMP RTOS中，两个核心在相同的系统时钟下可能并没有运行在相同状态——两个核心的调度器、时钟控制等等都是独立的，**时钟中断也是异步的**；传统FreeRTOS中时钟中断会触发一个xTaskIncrementTick()的函数，使得系统时钟计数器+1，创造出了系统节拍，通过vTaskDelay()可以通过系统节拍进行延时等任务；但在SMP RTOS中使用PRO_CPU处理来自硬件定时器的中断，并创造出系统节拍（换句话说**PRO_CPU是SMP RTOS的心脏**），因为各种软硬件原因，中断并不会同时到达两个核心，因此两个核心任务很可能产生异步行为，**延时函数绝对不应当被作为一种同步线程（任务）的方法**

## 临界区与互斥量

SMP RTOS会使用互斥量访问临界区，流程如下

1. 某任务获取临界区互斥量
2. 关闭线程调度器
3. 关闭当前核心中断
4. 完成任务
5. 开启当前核心中断
6. 开启线程调度器
7. 释放互斥量
8. 其他任务可以访问临界区

在此期间如果另外核心的任务需要访问该资源，需要获取相同的互斥量，但它会被挂起直到当前持有互斥量的任务完成

详细内容可以参考官网

## 硬件浮点运算的限制

ESP32支持单精度浮点运算硬件加速。但是使用硬件加速会受到一些SMP RTOS的行为限制。使用浮点数会被自动固定在单一CPU上运行，且浮点数不能在中断服务例程中使用

ESP32不支持双精度浮点数的硬件加速，因此双精度浮点数的运算时间可能比单精度的运算时间慢很多！

## 可视化编辑

可使用ESP-IDF的menuconfig可视化地配置SMP RTOS相关参数

## 官方库中的事件处理函数

wifi、以太网、IP、蓝牙这些组件都使用事件event和状态机FSM让应用程序处理状态变化

esp_event库文件用于取代传统的事件循环，让ESP-IDF的事件处理更加方便。所有可能能事件类型和事件数据结构都需要在system_event_id_t枚举和system_event_info_t联合中定义；而在的事件循环

使用esp_event_loop_init()来处理事件循环，应用程序通常需要设置一个事件处理函数

传统的事件处理函数如下：

```c
esp_err_t event_handler(void *ctx, system_event_t *event){}
```

需要向esp_event_loop_init()传入一个专门的上下文指针，当使用wifi、以太网、IP协议栈时往往会产生事件，这些事件都会被保存在事件队列中等待收取，每个处理函数都会获取一个指向事件结构体的指针，这个指针用于描述现在队首的事件，这个事件被用联合标注：event_id、event_info，通常应用程序使用switch结构体与状态机来处理不同种类的事件

所以在wifi、蓝牙、IP协议栈相关代码中经常会看到大段的switch语句

**当需要将事件传送到其他任务中时，应用程序需要将全部结构体都复制下来并进行传输**

特别地，蓝牙通常使用回调函数来进行事件处理，这些回调函数可以用来收取、发送、处理特定的蓝牙协议栈消息；通常也配合各种结构体来使用

# ESP32移植FreeRTOS的API简介

这里以示例程序+API简介的方式介绍ESP32上的FreeRTOS特性，我对FreeRTOS也处在学习阶段（从RTThread和GNU/Linux入手的RTOS），可能会存在不少漏洞，见谅TAT

## 系统控制

FreeRTOS以任务为程序的最小执行单元，相当于RTT里的线程，拥有自己的上下文。使用信号量、事件集、队列进行线程间同步与通信

下面是一些控制系统常用的宏定义

```c
configUSE_PREEMPTION//选择1为抢占式调度器，0则是协作式调度器
configCPU_CLOCK_HZ//MCU内核的工作频率，单位Hz；对不同的移植代码也可能不使用这个参数
configTICK_RATE_HZ//FreeRTOS时钟心跳，也就是FreeRTOS用到的定时中断的产生频率
configMAX_PRIORITIES//程序中可以使用的最大优先级
configMINIMAL_STACK_SIZE//任务堆栈的最小大小
configTOTAL_HEAP_SIZE//堆空间大小；只有当程序中采用FreeRTOS提供的内存分配算法时才会用到
configMAX_TASK_NAME_LEN//任务名称最大的长度，包括最后的'\0'结束字节，单位字节
    
configUSE_COUNTING_SEMAPHORES//是否使用信号量
configUSE_RECURSIVE_MUTEXES//是否使用互斥量递归持有
configUSE_MUTEXES//是否使用互斥量
configUSE_TIMERS//是否使用软件定时器

configTIMER_TASK_PRIORITY//设置软件定时器任务的优先级
configTIMER_QUEUE_LENGTH//设置软件定时器任务中用到的命令队列的长度
configTIMER_TASK_STACK_DEPTH//设置软件定时器任务需要的任务堆栈大小
```

## 任务管理

```c
//创建一个在单核心运行的任务
BaseType_t xTaskCreatePinnedToCore(TaskFunction_t pvTaskCode,
                                   const char *const pcName,
                                   const uint32_t usStackDepth,
                                   void *const pvParameters,
                                   UBaseType_t uxPriority,
                                   TaskHandle_t *const pvCreatedTask,
                                   const BaseType_t xCoreID)//固定执行该任务的核心，不需要则填tskNO_AFFINITY
//用于一般地创建任务，这个API被内联到了双核心交替运行任务的API上
static BaseType_t xTaskCreate(TaskFunction_t pvTaskCode,//任务入口函数指针
                              const char *const pcName,//任务名
                              const uint32_t usStackDepth,//任务堆栈大小
                              void *const pvParameters,//任务创建时传入的参数，如果任务入口函数没有参数则填NULL
                              UBaseType_t uxPriority,//任务优先级，数字越大优先级越高
                              TaskHandle_t *const pvCreatedTask)//任务回传句柄，如果没有任务回传值则设置为NULL
```

除了这两个API用于创建动态任务外，还可以使用以下API创建静态任务

```c
TaskHandle_t xTaskCreateStaticPinnedToCore(TaskFunction_t pvTaskCode, const char *const pcName, const uint32_t ulStackDepth, void *const pvParameters, UBaseType_t uxPriority, StackType_t *const pxStackBuffer, StaticTask_t *const pxTaskBuffer, const BaseType_t xCoreID)

static TaskHandle_t xTaskCreateStatic(TaskFunction_t pvTaskCode, const char *const pcName, const uint32_t ulStackDepth, void *const pvParameters, UBaseType_t uxPriority, StackType_t *const pxStackBuffer, StaticTask_t *const pxTaskBuffer)
```

下面是创建任务的例子

```c
void task(void* pvPar)//这个任务传入了参数
{
	while(1)
	{
		printf("I'm %s\r\n",(char *)pvPar);//传入的参数在这里调用
        
		vTaskDelay(1000/portTICK_PERIOD_MS);//将任务转入阻塞态一段时间来达到延时效果
	}
}

void app_main(void)
{
	vTaskDelay(pdMS_TO_TICKS(100));//等待系统初始化

    xTaskCreatePinnedToCore(task,//任务入口函数名作为函数指针调用
    		               "task1",//任务名
			                2048,//任务栈
			               "task1",//传给任务函数的参数
			                2,//任务优先级
			               NULL,//任务回传句柄
			               tskNO_AFFINITY);//这个任务将不会固定在某个核心上执行
    xTaskCreate(task,"task2",2048,"task2",2, NULL);
    //创建不固定在某个核心上运行的任务，如果对双核利用没有要求，一般情况下可以直接使用这个函数
    
	while(1)
    {
        vTaskDelay(1000/portTICK_PERIOD_MS);//app_main()也被看作一个任务，所以需要设置任务切换
    }
    vTaskDelete();//不会执行到此，但如果不加上面的死循环则必须用这个指令删除任务防止内存溢出或程序跑飞
}
```

使用下面的API进行任务延时

```c
//使当前任务挂起xTicksToDelay的时间
void vTaskDelay(const TickType_t xTicksToDelay)
    
//根据系统时间向后延迟到pxPreviousWakeTime
void vTaskDelayUntil(TickType_t *const pxPreviousWakeTime,//任务开始挂起的时间, 第一次使用时必须用当前时间初始化
                      const TickType_t xTimeIncrement)//每次进入挂起的时间
```

两个API的不同点在于vTaskDelay()从当前时间开始xTicksToDelay的时间延迟；vTaskDelayUntil()根据pxPreviousWakeTime和xTimeIncrement计算延迟的时间，延迟到系统时钟为pxPreviousWakeTime时，每次进入延迟的时间为xTimeIncrement

下面是使用例：

```c
vTaskDelay(10);//直接延迟10个时钟周期

//用下面的函数可以完成恒定频率的任务
const TickType_t xFrequency=10;
TickType_t xLastWakeTime=xTaskGetTickCount();//获取当前系统时间
while(1)
	vTaskDelayUntil(&xLastWakeTime,xFrequency);//重复xFrequency延迟
```

vTaskDelayUntil()可能不太好理解，建议写几个程序验证一下

## 任务调度

使用以下API控制任务调度

```c
vTaskStartScheduler();//启动任务调度器
vTaskEndScheduler();//停止使用任务调度器，这将释放所有内核分配的内存资源，但不会释放由程序分配的资源
```

## 队列通信与空闲任务

**队列（消息队列）是任务通信的主要形式**

队列用于在任务和任务之间以及任务和中断之间发送消息。队列消息会使用线程安全FIFO进行传输

可以使用队列API函数指定阻塞时间，阻塞时间代表任务进入阻塞状态，等待队列中数据或者等待队列空间变为可以使用时的最大系统节拍数。当一个以上任务在同一个队列中被阻塞时，高优先级的任务先解除阻塞

使用`#include "queue.h"`来使用队列相关的API

项目（消息）在队列中传送时，通过复制而不是引用进入FIFO，需要在传递项目到队列时为每个项目分配同样的大小

```c
//创建新队列，返回这个队列的句柄
xQueueHandle xQueueCreate ( 
    unsigned portBASE_TYPE uxQueueLength,//队列中包含最大项目数量
    unsigned portBASE_TYPE uxItemSize//队列中每个项目所需的字节数
);

//传递项目到队列
portBASE_TYPE xQueueSend ( 
    xQueueHandle xQueue,//要传进的队列 
    const void * pvItemToQueue,//要传项目的指针 
    portTickType xTicksToWait//等待的最大时间量（单位：系统时钟） 
);

//从队列接收一个项目
portBASE_TYPE xQueueReceive ( 
    xQueueHandle xQueue,//项目所在队列的句柄 
    void *pvBuffer,//指向缓冲区的指针，接收的项目会被复制进去 
    portTickType xTicksToWait//任务中断并等待队列中可用空间的最大时间 
);

//从中断传递项目到一个队列中的后面
portBASE_TYPE xQueueSendFromISR (
	xQueueHandle pxQueue,//将项目传进的队列
	const void *pvItemToQueue,//项目的指针
	portBASE_TYPE *pxHigherPriorityTaskWoken//因空间数据问题被挂起的任务是否解锁
);
/* 如果传进队列而导致因空间数据问题被挂起的任务解锁，并且解锁的任务的优先级高于当前运行任务，
xQueueSendFromISR 将设置 *pxHigherPriorityTaskWoken 到 pdTRUE
当pxHigherPriorityTaskWoken被设置为pdTRUE 时，则在中断退出之前将请求任务切换 */

//中断时从队列接收一个项目
portBASE_TYPE xQueueReceiveFromISR ( 
    xQueueHandle pxQueue,//发送项目的队列的句柄 
    void *pvBuffer,//指向缓冲区的指针，接收的项目会被复制进去 
    portBASE_TYPE *pxTaskWoken//任务将被锁住来等待队列中的可用空间
);

//移除队列
void vQueueUnregisterQueue (xQueueHandle xQueue);//要移除队列的句柄
```

## 信号量与互斥量

使用`#include "semphr.h"`后才能使用信号量相关API

互斥量是特殊的信号量，一般可以用信号量/互斥量替代裸机编程中的全局变量标志

信号量的两种典型应用

### 事件计数

事件处理程序在每次事件发生时发送信号量；任务处理程序会在每次处理事件时请求信号量

这样一边递增信号量，一边递减信号量，计数值为事件发生和事件处理两者间的差值

若计数值为正，则存在没有处理的事件

一般此时将信号量计数值初始化为0

### 资源管理（临界区）

如果系统中存在临界区（多个线程/应用程序同时需要使用的硬件资源）时，一般使用信号量来进行管理

使用信号量计数值指示出可用的资源数量，当计数值降为0时表示没有空闲资源

任务使用临界区时申请信号量，而不再访问临界区前返还信号量

这种情况下应该将信号量的计数值初始化为临界区系统资源的值

### 互斥量与二值信号量

互斥量是一种特殊的二值信号量，又被称为**互斥锁**

**二值信号量**就是只有两个可用值的信号量，比如一个只包含了0和1的信号量

互斥锁包含一个优先级继承机制，而信号量没有。这个特点决定了二值信号量适合实现线程间（任务间）同步；互斥锁更适合实现简单的互斥

当有另外一个具有更高优先级的任务试图获取同一个互斥锁时，已经获得互斥锁的任务的优先级会被提升，已经获得互斥锁的任务将继承试图获取同一互斥锁的任务的优先级。这意味着互斥锁必须总是要返还的，否则高优先级的任务将永远也不能获取互斥锁，而低优先级的任务将不会放弃优先级的继承。这就避免了出现互斥锁卡死的bug

二值信号量并不需要在得到后立即释放，任务同步可以通过一个任务/中断持续释放信号量而另外一个持续获得信号量来实现

互斥锁与二元信号量均赋值为xSemaphoreHandle类型，可以在任何此类型参数的API 函数中使用

注意：**互斥类型的信号量不能在中断服务程序中使用**

下面介绍互斥量和信号量的相关API

```c
//创建递归的互斥锁
xSemaphoreHandle xSemaphoreCreateRecursiveMutex (void);
/*
一个递归的互斥锁可以重复地被其所有者“获取”
在其所有者为每次的成功“获取”请求调用xSemaphoreGiveRecursive()前，此互斥锁不会再次可用
也就是说，一个任务重复获取同一个互斥锁n次，则需要在释放互斥锁n次后，其他任务才可以使用此互斥锁
*/

//获取信号量与互斥锁
xSemaphoreTake ( 
    xSemaphoreHandle xSemaphore,//将被获得的信号量句柄
    portTickType xBlockTime//等待信号量可用的时钟滴答次数
);//获得信号量

xSemaphoreTakeRecursive ( 
    xSemaphoreHandle xMutex,//将被获得的互斥锁句柄
    portTickType xBlockTime//等待互斥锁可用的时钟滴答次数 
);//递归获得互斥锁信号量

//释放信号量
xSemaphoreGive (xSemaphoreHandle xSemaphore);
//递归释放互斥锁信号量
xSemaphoreGiveRecursive (xSemaphoreHandle xMutex);
//从中断释放信号量
xSemaphoreGiveFromISR ( 
    xSemaphoreHandle xSemaphore,//将被释放的信号量的句柄 
    portBASE_TYPE *pxHigherPriorityTaskWoken//因空间数据问题被挂起的任务是否解锁
);
```

## 事件集

FreeRTOS的事件可以理解为多个二值信号量的组合

事件只与任务相关联，事件之间相互独立；事件仅用于同步，不提供数据传输功能

事件无排队性，多次向任务设置同一事件，如果任务还未来得及读走，则等效于只设置一次；允许多个任务对同一事件进行读写操作

**事件通常可以用来替代裸机编程中的if/switch语句配合枚举/全局变量标志**

```c
EventGroupHandle_t xEventGroupCreate(void);//创建事件标志组，返回事件标志组的句柄

//设置事件标志位
EventBits_t xEventGroupSetBits(EventGroupHandle_t xEventGroup,//事件标志组句柄
                               const EventBits_t uxBitsToSet//事件标志位
);//注意使用前一定要创建对应的事件标志

//从中断服务程序中设置事件标志位
BaseType_t EventGroupSetBitsFromISR(EventGroupHandle_t xEventGroup,//事件标志组句柄
                                    const EventBits_t uxBitsToSet,//事件标志位设置
                                    BaseType_t *pxHigherPriorityTaskWoken//高优先级任务是否被唤醒的状态保存
);
```

### ESP-IDF中的事件循环库

为了处理wifi、蓝牙、网络接口等外设中大量的状态变化，一般会使用状态机（FSM），而指示状态就需要用到事件集。ESP-IDF中提供了可用的**事件循环**。向默认事件循环发送事件相当于事件的handler依次执行队列中的命令

事件循环被囊括在**事件循环库**（event loop library）中。事件循环库允许组件将事件发布到事件循环，而当其他组件被注册到事件循环且设置了对应的处理函数时，程序会自动地在事件发生时执行处理程序。

在ESP32的魔改版FreeRTOS中很少使用正经的事件集，而是使用ESP-IDF提供的更方便的事件循环

使用`#include "esp_event.h"`即可开启事件循环库功能

使用流程如下：

1. 用户定义一个事件处理函数，该函数被必须与esp_event_handler_t具有相同的结构（也就是说该函数是esp_event_handler_t类型的函数指针）

   ```c
   typedef
   void (*esp_event_handler_t)(void *event_handler_arg,//事件处理函数的参数
                               esp_event_base_t event_base,//指向引发事件子程序的特殊指针
                               int32_t event_id,//事件的ID
                               void *event_data)//事件数据
   ```

2. 使用`esp_event_loop_create()`函数创建一个事件循环，该API会传回一个esp_event_loop_handle_t类型的指针用于指向事件循环。每个用该API创建的事件循环都被称为**用户事件循环**；除此之外，还可以使用一种称为**默认事件循环**的特殊事件循环（默认事件循环是系统自带的事件循环，实际上只使用默认事件循环就足够了，相关内容在之后叙述）
3. 使用`esp_event_handler_register_with()`函数将事件处理函数**注册**到事件循环（注意：一个处理函数可以被注册到多个不同的事件循环中！）
4. 开始运行程序
5. 使用`esp_event_post_to`发送一个事件到目标事件循环
6. 事件处理函数收取该事件并进行处理
7. 使用`esp_event_handler_unregister_with`来取消注册某个事件处理函数
8. 使用`esp_event_loop_delete`删除不再需要的事件循环

官方给出的流程代码描述如下：

```c
//1.定义事件处理函数
void run_on_event(void* handler_arg, esp_event_base_t base, int32_t id, void* event_data)
{}

void app_main()
{
    //2.配置esp_event_loop_args_t结构体来配置事件循环
    esp_event_loop_args_t loop_args = {
        .queue_size = ...,
        .task_name = ...
        .task_priority = ...,
        .task_stack_size = ...,
        .task_core_id = ...
    };

    //创建一个用户事件循环
    esp_event_loop_handle_t loop_handle;
    esp_event_loop_create(&loop_args, &loop_handle);
    //3.注册事件处理函数
    esp_event_handler_register_with(loop_handle, MY_EVENT_BASE, MY_EVENT_ID, run_on_event, ...);
    ...
    //4.事件源使用以下API将事件发送到事件循环，随后事件处理函数会根据其中的逻辑进行处理
    //这一系列操作可以跨任务使用
    esp_event_post_to(loop_handle, MY_EVENT_BASE, MY_EVENT_ID, ...)
    ...
    //5.解除注册一个事件处理函数
    esp_event_handler_unregister_with(loop_handle, MY_EVENT_BASE, MY_EVENT_ID, run_on_event);
    ...
    //6.删除一个不需要的事件循环
    esp_event_loop_delete(loop_handle);
}
```

使用如下函数来声明和定义事件

一个事件由两部分标识组成：**事件类型**和**事件ID**

事件类型标识了一个独立的事件组；事件ID区分在该组内的事件

==可以将事件类型视为人的姓，事件ID是人的名==

使用以下两个宏函数来声明、定义事件类型。一般地，在程序中使用XXX_EVENT的形式来定义一个事件类型

```c
ESP_EVENT_DECLARE_BASE(EVENT_BASE)//声明事件类型
ESP_EVENT_DEFINE_BASE(EVENT_BASE)//定义事件类型
    
//事件类型举例：WIFI_EVENT
```

一般使用枚举变量来定义事件ID，如下所示

```c
enum {
    EVENT_ID_1,
    EVENT_ID_2,
    EVENT_ID_3,
    ...
}
```

当注册一个事件处理函数到不同事件循环后，**事件循环可以根据不同的事件类型和事件ID来区分应该执行哪一个事件处理函数**

可以使用ESP_EVENT_ANY_BASE和ESP_EVENT_ANY_ID作为注册事件处理函数的参数，这样事件处理函数就可以处理发到当前注册事件循环上的任何事件

### 默认事件循环

默认事件循环是一种系统事件（如wifi、蓝牙事件等）使用的特殊事件循环。特殊的一点是它的句柄被隐藏起来，用户无法直接使用。用户只能通过一系列固定的API来操作这个事件循环

API如下表所示

| 用户事件循环                        | 默认事件循环                    | 事件循环API              |
| ----------------------------------- | ------------------------------- | ------------------------ |
| esp_event_loop_create()             | esp_event_loop_create_default() | 创建                     |
| esp_event_loop_delete()             | esp_event_loop_delete_default() | 删除                     |
| esp_event_handler_register_with()   | esp_event_handler_register()    | 注册处理函数             |
| esp_event_handler_unregister_with() | esp_event_handler_unregister()  | 取消注册处理函数         |
| esp_event_post_to()                 | esp_event_post()                | 事件源发送事件到事件循环 |

除了API区别和系统事件会自动发送到默认事件循环外，**两者并没有更多差别**，所以说用户可以将自定义的事件直接发送到默认事件循环，这比用户定义的事件循环更节约内存且**更方便**！

==任务、队列和事件循环是ESP32中最常用也是最特殊的SMP FreeRTOS API==

### 事件循环库API简介

使用以下API控制事件循环

```c
esp_err_t esp_event_loop_create_default(void);//创建默认事件循环
esp_err_t esp_event_loop_delete_default(void);//删除默认事件循环

//创建用户事件循环
esp_err_t esp_event_loop_create(const esp_event_loop_args_t *event_loop_args,//事件循环参数
                                esp_event_loop_handle_t *event_loop);//事件循环句柄
    
//删除用户事件循环
esp_err_t esp_event_loop_delete(esp_event_loop_handle_t event_loop);//事件循环

esp_err_t esp_event_loop_run(esp_event_loop_handle_t event_loop, TickType_t ticks_to_run);
//将时间分配到一个事件循环，不常用，注意事项一大堆懒得看了——总之详细用法请参考官网API简介    
```

使用以下API来注册/注销事件处理函数

```c
//将事件处理程序注册到系统事件循环
esp_err_t esp_event_handler_register(esp_event_base_t event_base,//事件类型
                                     int32_t event_id,//事件ID
                                     esp_event_handler_t event_handler,//事件处理函数
                                     void *event_handler_arg);//事件处理函数的参数

//将事件处理程序注册到用户事件循环
esp_err_t esp_event_handler_register_with(esp_event_loop_handle_t event_loop,//要注册到的事件循环
                                          esp_event_base_t event_base,//事件类型
                                          int32_t event_id,//事件ID
                                          esp_event_handler_t event_handler,//事件处理函数
                                          void *event_handler_arg);//事件处理函数的参数
//取消注册（系统事件循环）
esp_err_t esp_event_handler_unregister(esp_event_base_t event_base,//事件类型
                                       int32_t event_id,//事件ID
                                       esp_event_handler_t event_handler);//事件处理函数
//取消注册（用户事件循环）
esp_err_t esp_event_handler_unregister_with(esp_event_loop_handle_t event_loop,//要取消注册的事件循环
                                            esp_event_base_t event_base,//事件类型
                                            int32_t event_id,//事件ID
                                            esp_event_handler_t event_handler);//事件处理函数
```

可以使用ESP_EVENT_ANY_BASE 和ESP_EVENT_ANY_ID来取消注册所有事件循环上的事件处理函数

使用以下API来发送事件到事件循环

```c
//发送事件到系统事件循环
esp_err_t esp_event_post(esp_event_base_t event_base,//事件类型
                         int32_t event_id,//事件ID
                         void *event_data,//事件数据
                         size_t event_data_size,//事件数据的大小
                         TickType_t ticks_to_wait);//等待时间

//发送事件到用户事件循环
esp_err_t esp_event_post_to(esp_event_loop_handle_t event_loop,//要发送到的用户事件循环的句柄
                            esp_event_base_t event_base,//事件类型
                            int32_t event_id,//事件ID
                            void *event_data,//事件数据
                            size_t event_data_size,//事件数据的大小
                            TickType_t ticks_to_wait)//等待时间
```

事件循环库函数会保留事件数据的副本并自动控制副本的存活时间