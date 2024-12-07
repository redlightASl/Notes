注意：本博文仅关注FreeRTOS的使用方法，尽量不涉及底层的实现

# FreeRTOS中的任务

在FreeRTOS中，使用**任务作为运行的基本单位**，应用程序被看作一系列独立任务的集合，FreeRTOS的调度器是一个抢占式轮询调度器

一个任务的可能状态有四种：

* **运行**：任务占用处理器的正常执行状态
* **就绪**：任务已经满足运行的条件，但因为存在其他任务正在运行而没有真正执行的状态
* **阻塞**：任务等待某个时序或外部中断的状态
* **挂起**：调用API主动进入的不加入调度队列的任务状态

每个任务都会被分配给**优先级**，优先级数值越大就越高，空闲任务的优先级为0，一般将优先级设置为满足使用的最小值即可。多个任务可以使用同一个优先级，处于就绪态的多个相同优先级任务将会以时间片轮转的方式共享处理器

空闲任务是启动RTOS调度器时由内核自动创建的任务，它的唯一功能就是释放RTOS分配给被删除任务的内存，应确保其他任务处于死循环执行状态或者在删除任务后让空闲任务能获得处理器时间。空闲任务还附带一个钩子函数，在FreeRTOSConfig.h中可以设置configUSE_IDLE_HOOK为1来启用，之后在应用程序中定义一个形如以下的函数：

```c
void vApplicationIdleHook(void);
```

在这个函数中的语句会在每个空闲任务周期中被调用。特别地，应该保证这个函数简短，因为钩子函数的执行是阻塞的，这样可以避免占用过多的CPU事件。一个典型用法是用这个钩子函数来设置CPU进入低功耗模式

使用函数

```c
BaseType_t xTaskCreate(TaskFunction_t pvTaskCode, //任务函数入口指针
						const char * const pcName, //任务描述字符串
                        unsigned short usStackDepth, //任务栈大小
                        void *pvParameters, //任务参数
                        UBaseType_t uxPriority, //任务优先级
                        TaskHandle_t * pvCreatedTask); //任务回调句柄
```

来创建任务并加入任务就序列表

其中需要注意：

* **任务栈大小指的并不是字节数**，而是能够支持的堆栈变量数量，实际的任务栈大小按照堆栈位宽来确定
* 任务参数不使用时一般置为NULL
* 在特殊的API中可以使用任务回调句柄来引用这个任务

使用函数

```c
void vTaskDelete(TaskHandle_t xTask);
```

从RTOS内核管理器中删除一个任务。任务删除后将会从就绪、阻塞、暂停和事件列表中移除，**其内存会且仅会被空闲任务释放**

## 任务管理函数

### 延时

FreeRTOS中存在相对延时和绝对延时两种延时函数

```c
void vTaskDelay(portTickType xTicksToDelay); //相对延时
void vTaskDelayUntil( TickType_t *pxPreviousWakeTime, const TickType_t xTimeIncrement); //绝对延时
```

两者最大的区别在于：vTaskDelay()指定的延时时间是从调用vTaskDelay()之后（执行完该函数）开始算起的，但是vTaskDelayUntil()指定的延时时间是一个绝对时间

调用**延时生效后**，**任务**会进入**阻塞**状态，调度器会根据系统节拍来确定延时时间，也就是延时函数中设定延时时间的单位是系统节拍

vTaskDelay()不适应周期性执行任务的场合，因为往往其他任务和中断活动会影响它的调用，影响任务下一次执行的事件；所以对于时间要求较为严格的情况下使用vTaskDelayUntil()来进行固定频率延时。vTaskDelayUntil()指定一个绝对时间，每当时间到达，则解除任务阻塞，任务会**立即**返回；参数中的**pxPreviousWakeTime是一个指向任务最后一次解除阻塞的事件的变量**，需要注意：**第一次使用前，该变量必须初始化为当前时间**，在调用之后这个变量就会在函数里自动更新；xTimeIncrement表示周期循环时间，当时间等于(*pxPreviousWakeTime + xTimeIncrement)时，任务会解除阻塞，转为运行状态，如果不改变xTimeIncrement的值，任务会按照固定频率执行

### 挂起和继续

使用

```c
void vTaskSuspend(TaskHandle_t xTaskToSuspend);
```

挂起任务。被挂起的任务不管具有什么优先级都不会得到处理器时间，*该API调用不可累计*

使用

```c
void vTaskResume(TaskHandle_t xTaskToResume);
```

恢复被挂起的任务

特别地，可以在中断中使用

```c
BaseType_t xTaskResumeFromISR(TaskHandle_t xTaskToResume);
```

在中断中恢复被挂起的任务——显而易见，一般的vTaskResume()不能再中断中使用，不过xTaskResumeFromISR()也不能直接用于中断和任务之间通讯，如果中断恰巧在任务挂起之前到达，就会导致一次中断丢失了

### 控制任务信息

使用以下API控制任务的基本信息，注意TaskHandle_t就是任务句柄类型，不再赘述

```c
UBaseType_t uxTaskPriorityGet(TaskHandle_t xTask); //获取任务优先级
void vTaskPrioritySet(TaskHandle_t xTask, UBaseType_t uxNewPriority ); //改变任务优先级
TaskHandle_t xTaskGetCurrentTaskHandle(void); //获取当前任务句柄
UBaseType_t uxTaskGetStackHighWaterMark(TaskHandle_t xTask); //获取任务栈最大使用深度
eTaskState eTaskGetState(TaskHandle_txTask); //获取任务状态
char *pcTaskGetTaskName(TaskHandle_txTaskToQuery); //获取任务描述内容
volatile TickType_t xTaskGetTickCount(void); //获取当前系统节拍次数
BaseType_t xTaskGetSchedulerState(void); //获取当前调度器状态
UBaseType_t uxTaskGetNumberOfTasks(void); //获取任务总数
void vTaskList(char *pcWriteBuffer); //获取所有任务详情，以表格形式输出，调用该函数会挂起所有任务，仅用于调试
void vTaskGetRunTimeStats(char *pcWriteBuffer); //获取任务运行时间
void vTaskSetApplicationTaskTag(TaskHandle_t xTask, TaskHookFunction_t pxTagValue); //设置任务标签值
TaskHookFunction_t xTaskGetApplicationTaskTag(TaskHandle_t xTask); //获取任务标签值
BaseType_t xTaskCallApplicationTaskHook(TaskHandle_t xTask, void *pvParameter ); //执行任务的应用钩子函数
```

## 任务间通信——事件













## FreeRTOS的编码风格

FreeRTOS源码总体遵循MISRA编码标准指南，但是其中

* 一些API函数有多个返回点
* 为了兼容8、16、20、24、32位总线，不可避免地使用了指针算数运算
* 默认情况下跟踪宏为空语句

不符合MISRA编码标准

FreeRTOS比较好的一点是它不使用任何非C语言标准的特性或语法，唯一的例外是在FreeRTOS/Source/include下有一个叫stdint.readme的文件，如果编译器不提供stdint类型定义，就可以将它重命名为stdint.h

其他的编码风格省略（毕竟我们主要关注FreeRTOS的使用）

## 常用的内核控制API

### 禁止、使能可屏蔽中断宏

```c
taskDISABLE_INTERRUPTS //禁止中断
taskENABLE_INTERRUPTS //使能中断
```

### 启动、停止调度器

```c
void vTaskStartScheduler(void); //启动调度器
void vTaskEndScheduler(void); //停止调度器
void vTaskSuspendAll(void); //挂起调度器，但不禁止中断
BaseType_t xTaskResumeAll(void); //恢复被挂起的调度器
```

