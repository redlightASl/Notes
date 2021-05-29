# 嵌套向量中断控制器NVIC

ARM内核标准规定了使用**嵌套向量中断控制器NVIC**控制异常和中断。对于STM32F407的Cortex-M4内核，NVIC具有16个可编程优先级、86个可屏蔽中断通道（ARM标准规定NVIC最多支持240个中断请求、1个不可屏蔽中断NMI、1个systick中断和多个系统异常，STM32只用到了一部分）

为了继续执行被中断的程序，异常流程需要利用一些手段来保存被中断程序的状态（保护现场），并在异常处理完成后自动恢复（恢复现场），这个过程一般有硬件实现，但是也可以由硬件、软件共同操作。**对于M4内核，当异常被接受后，有些寄存器会被自动保存到栈中，并在返回流程中自动回复，因此可以将异常处理写作普通的C函数，这并不会带来额外的软件开销**

这段C函数就被称为**中断服务程序**（中断服务函数）

在STM32中实现了NVIC并设置了专门用于控制外部中断/事件的EXTI外设

### NVIC设备与EXTI设备的概念梳理

NVIC是位于M4核内部的设备，负责处理**来自内核外界的所有中断信号**和**来自内核的异常信号**

这里的异常实际上是狭义的异常概念——广义上异常包括了中断：内部的异常信号称为狭义的异常，外部的异常信号称为中断

根据内核IP厂商的划分，通常会用很多不同的方式称呼这个东西，但是本质上都差不多

EXTI设备则是位于STM32的SoC中，并不在内核上，作为一个专门的外设用来处理来自片外和SoC中的异常、中断、事件信号

这里的三个概念都是狭义的：

异常指来自SoC内部的异常信号，中断指来自SoC外部（一般是GPIO）的异常信号，而事件则是指来自SoC内部或外部的特殊异常，一般是某个外设完成某个任务或某个FIFO已满时发出的中断信号

信号的流向是：外部异常->EXTI->NVIC->内核

内核在接收到NVIC发来的中断请求后自动执行中断处理的硬件程序，而在此之前的操作都归属于NVIC完成

详细的内核中断流程需要参考Cortex-M4内核相关参考手册或教程，这里不再赘述

## 外部中断/事件控制器EXTI

外部中断/事件控制器是NVIC内部专用于控制外部中断的设备，包含23个可用于产生事件/中断请求的边沿检测其，每根输入线都能单独配置、单独屏蔽

EXTI控制器具有以下特性

* 每个中断/事件线上都具有独立的触发和屏蔽
* 每个中断线都具有专用的状态位
* 支持多达 23 个软件事件/中断请求
* 检测脉冲宽度低于 APB2 时钟宽度的外部信号

EXTI控制器结构框图如下

 ![image-20210513091957958](.\STM32F4深入学习_NVIC中断控制.assets\image-20210513091957958.png)

**中断信号的捕获**：输入线可以配置到其他外设（如GPIO），输入信号会先通过边沿检测电路，如果配置了跳变沿触发的外部中断，对应的跳变沿信号会将跳变沿触发选择寄存器置位，此时CPU就可以通过AMBA总线（一般是APB总线）访问EXTI外设中的对应寄存器，进而检测到中断信号

**中断事件屏蔽**：当对中断屏蔽寄存器、软件中断事件寄存器置位时，信号会经过后续逻辑电路的处理：*跳变沿**或**软件中断事件出现*，或门就会输出1到后续的两个与门，*如果事件屏蔽寄存器对应位置1*，就会触发事件到脉冲发生器；*如果中断屏蔽寄存器对应位置1*，就会触发中断挂起请求，挂起请求寄存器置1，这个寄存器会直接被NVIC访问，实现直接对NVIC的中断控制，*CPU可访问该寄存器并清除对应位来恢复中断*

### 配置方法

中断配置方法：

1. 配置并使能中断线

   根据需要的边缘检测设置2个触发寄存器，边沿检测电路就会按照配置进行外部输入信号的检测

2. 在中断屏蔽寄存器要开启的控制位写1来使能中断请求

事件的配置方法和上面一样，只不过需要把中断线改成对应事件线

中断/事件触发后，EXTI会产生中断请求，对应地挂起位会置1

在挂起寄存器的对应位写1会清除对应中断请求，**在中断处理程序的开头一定要记得清除中断请求**，否则中断会一直进行

### 硬件中断/事件选择配置

1. 配置中断线/事件线（各23根）的屏蔽位（EXTI_IMR和EXTI_EMR寄存器）
2. 配置中断/事件线的触发选择位（EXTI_RTSR和EXTI_FTSR寄存器）
3. 如果是配置外部中断，还需要配置到对应外部中断控制器EXTI的NVIC中断通道使能和屏蔽位，使得23个中断线中的请求可以被M4内核正确响应

当然除了硬件中断外也可以单独配置软件中断/事件模式，大体流程和硬件的差不多，STM也提供了库函数（STP库和LL库有，HAL库就没有，当然用HAL库也不在意这些东西）

### 外部中断/事件线映射

详细的映射表可以查阅STM32F4xx参考手册，这里不列出

只需要注意一点：**所有EXTI的映射都是固定的**，千万不要弄错EXTI线与GPIO的端口对应，否则会导致中断用不了！

作者在刚学习STM32的时候曾经犯过这个错误，把RTC的EXTI直接接到了GPIO，然后发现中断没有任何效果，查了好久才明白EXTI线和GPIO的对应关系

## 中断向量表

中断向量表是位于MCU的bootloader代码部分中用于声明中断跳转位置的一段代码

使用中断向量表保证MCU中断跳转不会跑飞

相关内容请参考bootloader相关材料或教程

## EXTI系统事件

### 唤醒事件

STM32可以处理外部或内部事件对内核进行唤醒（WFE）

唤醒的途径有以下两种

* 在外设控制寄存器处使能一个中断，但不在NVIC中使能；同时使能M4内核控制寄存器中的SEVONPEND位

  **在MCU从WFE恢复时，一定要清除对应外设和外设NVIC的中断/中断通道挂起位**

* 配置一个外部或内部EXTI线为事件模式，当CPU从WFE恢复时，因为对应事件线的挂起位没有被置位，所以不必清除相应外设的中断挂起位或NVIC中断通道挂起位

### RTC事件

STM32F4支持来自SoC内部的RTC中断唤醒，通过配置SoC唤醒中断就可以开启这个事件

RTC事件的中断线固定为22号

## NVIC与EXTI外设的库函数

库函数.c文件的前半部分简要说明了外部中断线的映射

> [..] External interrupt/event lines are mapped as following:
>    (#) All available GPIO pins are connected to the 16 external 
>        interrupt/event lines from EXTI0 to EXTI15.
>    (#) EXTI line 16 is connected to the PVD Output
>    (#) EXTI line 17 is connected to the RTC Alarm event
>    (#) EXTI line 18 is connected to the USB OTG FS Wakeup from suspend event
>    (#) EXTI line 19 is connected to the Ethernet Wakeup event
>    (#) EXTI line 20 is connected to the USB OTG HS (configured in FS) Wakeup event 
>    (#) EXTI line 21 is connected to the RTC Tamper and Time Stamp events
>    (#) EXTI line 22 is connected to the RTC Wakeup event
>
> 外部中断线如下映射：
>
> * 所有GPIO引脚连接到从EXTI0到EXTI15的外部中断/事件线
> * EXTI16连接到PVD输出
> * EXTI17连接到RTC闹钟事件
> * EXTI18连接到USB OTG FS唤醒事件
> * EXTI19连接到以太网唤醒事件
> * EXTI20连接到USB OTG HS唤醒事件
> * EXTI21连接到RTC检测和时间戳事件
> * EXTI22连接到RTC唤醒事件

配置步骤如下：

1. 使用`RCC_APB2PeriphClockCmd(RCC_APB2Periph_SYSCFG, ENABLE)`开启EXTI外设时钟
2. 使用`GPIO_Init()`函数配置GPIO为输入模式
3. 使用`SYSCFG_EXTILineConfig()`配置输入源连接到对应的EXTI线
4. 使用EXTI外设配置结构体设置模式、触发选项，并使用`EXTI_Init()`应用设置
5. 使用`NVIC_Init()`函数开启EXTI连接到NVIC中断通道

### EXTI库函数参考

1. 将EXTI配置寄存器置0

```c
void EXTI_DeInit(void)
{
  EXTI->IMR = 0x00000000;
  EXTI->EMR = 0x00000000;
  EXTI->RTSR = 0x00000000;
  EXTI->FTSR = 0x00000000;
  EXTI->PR = 0x007FFFFF;
}
```

2. 初始化EXTI初始化结构体和配置寄存器

```c
void EXTI_StructInit(EXTI_InitTypeDef* EXTI_InitStruct) //初始化EXTI配置结构体
{
  EXTI_InitStruct->EXTI_Line = EXTI_LINENONE;
  EXTI_InitStruct->EXTI_Mode = EXTI_Mode_Interrupt;
  EXTI_InitStruct->EXTI_Trigger = EXTI_Trigger_Falling;
  EXTI_InitStruct->EXTI_LineCmd = DISABLE;
}

void EXTI_Init(EXTI_InitTypeDef* EXTI_InitStruct) //初始化EXTI配置寄存器（应用设置）
{
  uint32_t tmp = 0;

  /* Check the parameters */
  assert_param(IS_EXTI_MODE(EXTI_InitStruct->EXTI_Mode));
  assert_param(IS_EXTI_TRIGGER(EXTI_InitStruct->EXTI_Trigger));
  assert_param(IS_EXTI_LINE(EXTI_InitStruct->EXTI_Line));  
  assert_param(IS_FUNCTIONAL_STATE(EXTI_InitStruct->EXTI_LineCmd));

  tmp = (uint32_t)EXTI_BASE;
     
  if (EXTI_InitStruct->EXTI_LineCmd != DISABLE)
  {
    /* Clear EXTI line configuration */
    EXTI->IMR &= ~EXTI_InitStruct->EXTI_Line;
    EXTI->EMR &= ~EXTI_InitStruct->EXTI_Line;
    
    tmp += EXTI_InitStruct->EXTI_Mode;

    *(__IO uint32_t *) tmp |= EXTI_InitStruct->EXTI_Line;

    /* Clear Rising Falling edge configuration */
    EXTI->RTSR &= ~EXTI_InitStruct->EXTI_Line;
    EXTI->FTSR &= ~EXTI_InitStruct->EXTI_Line;
    
    /* Select the trigger for the selected external interrupts */
    if (EXTI_InitStruct->EXTI_Trigger == EXTI_Trigger_Rising_Falling)
    {
      /* Rising Falling edge */
      EXTI->RTSR |= EXTI_InitStruct->EXTI_Line;
      EXTI->FTSR |= EXTI_InitStruct->EXTI_Line;
    }
    else
    {
      tmp = (uint32_t)EXTI_BASE;
      tmp += EXTI_InitStruct->EXTI_Trigger;

      *(__IO uint32_t *) tmp |= EXTI_InitStruct->EXTI_Line;
    }
  }
  else
  {
    tmp += EXTI_InitStruct->EXTI_Mode;

    /* Disable the selected external lines */
    *(__IO uint32_t *) tmp &= ~EXTI_InitStruct->EXTI_Line;
  }
}
```

3. 在选定的中断线上生成软件中断

```c
void EXTI_GenerateSWInterrupt(uint32_t EXTI_Line)
{
  /* Check the parameters */
  assert_param(IS_EXTI_LINE(EXTI_Line));
  
  EXTI->SWIER |= EXTI_Line;
}
```

4. 获取当前中断状态、清除中断标志位

```c
FlagStatus EXTI_GetFlagStatus(uint32_t EXTI_Line) //获取当前中断标志位状态
{
  FlagStatus bitstatus = RESET;
  /* Check the parameters */
  assert_param(IS_GET_EXTI_LINE(EXTI_Line));
  
  if ((EXTI->PR & EXTI_Line) != (uint32_t)RESET)
  {
    bitstatus = SET;
  }
  else
  {
    bitstatus = RESET;
  }
  return bitstatus;
}

ITStatus EXTI_GetITStatus(uint32_t EXTI_Line) //获取当前中断状态
{
  FlagStatus bitstatus = RESET;
  /* Check the parameters */
  assert_param(IS_GET_EXTI_LINE(EXTI_Line));
  
  if ((EXTI->PR & EXTI_Line) != (uint32_t)RESET)
  {
    bitstatus = SET;
  }
  else
  {
    bitstatus = RESET;
  }
  return bitstatus;
}

void EXTI_ClearFlag(uint32_t EXTI_Line) //清除中断标志位
{
  /* Check the parameters */
  assert_param(IS_EXTI_LINE(EXTI_Line));
  
  EXTI->PR = EXTI_Line;
}

void EXTI_ClearITPendingBit(uint32_t EXTI_Line) //清除中断挂起标志
{
  /* Check the parameters */
  assert_param(IS_EXTI_LINE(EXTI_Line));
  
  EXTI->PR = EXTI_Line;
}
```

下面是一些定义在STP库头文件中结构体和宏函数的简述

```c
//选择事件触发还是中断触发
typedef enum
{
  EXTI_Mode_Interrupt = 0x00,
  EXTI_Mode_Event = 0x04
}EXTIMode_TypeDef;

#define IS_EXTI_MODE(MODE) (((MODE) == EXTI_Mode_Interrupt) || ((MODE) == EXTI_Mode_Event))

//EXTI触发状态
typedef enum
{
  EXTI_Trigger_Rising = 0x08,
  EXTI_Trigger_Falling = 0x0C,  
  EXTI_Trigger_Rising_Falling = 0x10
}EXTITrigger_TypeDef;

#define IS_EXTI_TRIGGER(TRIGGER) (((TRIGGER) == EXTI_Trigger_Rising) || \
                                  ((TRIGGER) == EXTI_Trigger_Falling) || \
                                  ((TRIGGER) == EXTI_Trigger_Rising_Falling))

//EXTI配置结构体
typedef struct
{
  uint32_t EXTI_Line; //中断线号
  EXTIMode_TypeDef EXTI_Mode; //EXTI模式选择
  EXTITrigger_TypeDef EXTI_Trigger; //EXTI触发状态
  FunctionalState EXTI_LineCmd; //中断线使能
}EXTI_InitTypeDef;

//下面是中断线的宏定义
#define EXTI_Line0       ((uint32_t)0x00001)     /*!< External interrupt line 0 */
#define EXTI_Line1       ((uint32_t)0x00002)     /*!< External interrupt line 1 */
#define EXTI_Line2       ((uint32_t)0x00004)     /*!< External interrupt line 2 */
#define EXTI_Line3       ((uint32_t)0x00008)     /*!< External interrupt line 3 */
#define EXTI_Line4       ((uint32_t)0x00010)     /*!< External interrupt line 4 */
#define EXTI_Line5       ((uint32_t)0x00020)     /*!< External interrupt line 5 */
#define EXTI_Line6       ((uint32_t)0x00040)     /*!< External interrupt line 6 */
#define EXTI_Line7       ((uint32_t)0x00080)     /*!< External interrupt line 7 */
#define EXTI_Line8       ((uint32_t)0x00100)     /*!< External interrupt line 8 */
#define EXTI_Line9       ((uint32_t)0x00200)     /*!< External interrupt line 9 */
#define EXTI_Line10      ((uint32_t)0x00400)     /*!< External interrupt line 10 */
#define EXTI_Line11      ((uint32_t)0x00800)     /*!< External interrupt line 11 */
#define EXTI_Line12      ((uint32_t)0x01000)     /*!< External interrupt line 12 */
#define EXTI_Line13      ((uint32_t)0x02000)     /*!< External interrupt line 13 */
#define EXTI_Line14      ((uint32_t)0x04000)     /*!< External interrupt line 14 */
#define EXTI_Line15      ((uint32_t)0x08000)     /*!< External interrupt line 15 */
#define EXTI_Line16      ((uint32_t)0x10000)     /*!< External interrupt line 16 Connected to the PVD Output */
#define EXTI_Line17      ((uint32_t)0x20000)     /*!< External interrupt line 17 Connected to the RTC Alarm event */
#define EXTI_Line18      ((uint32_t)0x40000)     /*!< External interrupt line 18 Connected to the USB OTG FS Wakeup from suspend event */                                    
#define EXTI_Line19      ((uint32_t)0x80000)     /*!< External interrupt line 19 Connected to the Ethernet Wakeup event */
#define EXTI_Line20      ((uint32_t)0x00100000)  /*!< External interrupt line 20 Connected to the USB OTG HS (configured in FS) Wakeup event  */
#define EXTI_Line21      ((uint32_t)0x00200000)  /*!< External interrupt line 21 Connected to the RTC Tamper and Time Stamp events */                                               
#define EXTI_Line22      ((uint32_t)0x00400000)  /*!< External interrupt line 22 Connected to the RTC Wakeup event */                                               
                                          
#define IS_EXTI_LINE(LINE) ((((LINE) & (uint32_t)0xFF800000) == 0x00) && ((LINE) != (uint16_t)0x00))

#define IS_GET_EXTI_LINE(LINE) (((LINE) == EXTI_Line0) || ((LINE) == EXTI_Line1) || \
                                ((LINE) == EXTI_Line2) || ((LINE) == EXTI_Line3) || \
                                ((LINE) == EXTI_Line4) || ((LINE) == EXTI_Line5) || \
                                ((LINE) == EXTI_Line6) || ((LINE) == EXTI_Line7) || \
                                ((LINE) == EXTI_Line8) || ((LINE) == EXTI_Line9) || \
                                ((LINE) == EXTI_Line10) || ((LINE) == EXTI_Line11) || \
                                ((LINE) == EXTI_Line12) || ((LINE) == EXTI_Line13) || \
                                ((LINE) == EXTI_Line14) || ((LINE) == EXTI_Line15) || \
                                ((LINE) == EXTI_Line16) || ((LINE) == EXTI_Line17) || \
                                ((LINE) == EXTI_Line18) || ((LINE) == EXTI_Line19) || \
                                ((LINE) == EXTI_Line20) || ((LINE) == EXTI_Line21) ||\
                                ((LINE) == EXTI_Line22))
```

### 使用库函数配置NVIC

在配置完EXTI后，还需要开启NVIC才能使用外部中断/事件；即使不使用外部中断，systick等SoC内部乃至内核异常都需要使能NVIC配置才行，ARM（这回不是ST了）提供了配置NVIC的库函数，保存在misc.c文件中

整套库函数都被包括在CMSIS标准中，这套标准可以在所有使用了ARM内核处理器的设备中通用，上到A53下到Cortex-M0都可以使用

因为这里主要讲述STM32F4相关的中断控制，对移植的操作不再赘述

软件配置NVIC主要是对中断优先级进行配置

**中断优先级分为抢占优先级和子优先级，抢占优先级高的中断可以对抢占优先级低的中断形成中断嵌套；如果抢占优先级相等，则子优先级更高的先执行；若两个中断优先级完全一致，则哪个先发生哪个先执行；数字越小，优先级越高**

使用库函数`NVIC_Init()`来配置中断优先级

```c
void NVIC_Init(NVIC_InitTypeDef* NVIC_InitStruct)
{
  uint8_t tmppriority = 0x00, tmppre = 0x00, tmpsub = 0x0F;
  
  /* Check the parameters */
  assert_param(IS_FUNCTIONAL_STATE(NVIC_InitStruct->NVIC_IRQChannelCmd));
  assert_param(IS_NVIC_PREEMPTION_PRIORITY(NVIC_InitStruct->NVIC_IRQChannelPreemptionPriority));  
  assert_param(IS_NVIC_SUB_PRIORITY(NVIC_InitStruct->NVIC_IRQChannelSubPriority));
    
  if (NVIC_InitStruct->NVIC_IRQChannelCmd != DISABLE)
  {
    /* Compute the Corresponding IRQ Priority --------------------------------*/    
    tmppriority = (0x700 - ((SCB->AIRCR) & (uint32_t)0x700))>> 0x08;
    tmppre = (0x4 - tmppriority);
    tmpsub = tmpsub >> tmppriority;

    tmppriority = NVIC_InitStruct->NVIC_IRQChannelPreemptionPriority << tmppre;
    tmppriority |=  (uint8_t)(NVIC_InitStruct->NVIC_IRQChannelSubPriority & tmpsub);
        
    tmppriority = tmppriority << 0x04;
        
    NVIC->IP[NVIC_InitStruct->NVIC_IRQChannel] = tmppriority;
    
    /* Enable the Selected IRQ Channels --------------------------------------*/
    NVIC->ISER[NVIC_InitStruct->NVIC_IRQChannel >> 0x05] =
      (uint32_t)0x01 << (NVIC_InitStruct->NVIC_IRQChannel & (uint8_t)0x1F);
  }
  else
  {
    /* Disable the Selected IRQ Channels -------------------------------------*/
    NVIC->ICER[NVIC_InitStruct->NVIC_IRQChannel >> 0x05] =
      (uint32_t)0x01 << (NVIC_InitStruct->NVIC_IRQChannel & (uint8_t)0x1F);
  }
}
```

需要特别注意的是：中断需要配置中断向量表才能使用——中断发生时处理器会根据中断向量表进行跳转

```c
void NVIC_SetVectorTable(uint32_t NVIC_VectTab, uint32_t Offset)
{ 
  /* Check the parameters */
  assert_param(IS_NVIC_VECTTAB(NVIC_VectTab));
  assert_param(IS_NVIC_OFFSET(Offset));  
   
  SCB->VTOR = NVIC_VectTab | (Offset & (uint32_t)0x1FFFFF80);
}
```

设置中断向量表的库函数一般不常用，中断向量表都会直接以汇编代码的形式写在bootloader中

ARM内核还具有中断分组机制，将所有中断分为0到4共5组

misc.c的描述如下：

| NVIC分组 | 抢占优先级数目 | 子优先级数目 | 抢占优先级位数 | 子优先级位数 |
| -------- | -------------- | ------------ | -------------- | ------------ |
| 0        | 0              | 0-15         | 0              | 4            |
| 1        | 0-1            | 0-7          | 1              | 3            |
| 2        | 0-3            | 0-3          | 2              | 2            |
| 3        | 0-7            | 0-1          | 3              | 1            |
|          | 0-15           | 0            | 4              | 0            |

设置分组的原因是用户需求不同，但NVIC优先级控制寄存器位数有限，需要使用类似网络子网掩码的方式形成抢占优先级和子优先级分割，用户可以根据自己的需要选择合适的NVIC分组

使用库函数`NVIC_PriorityGroupConfig()`来配置中断分组

```c
void NVIC_PriorityGroupConfig(uint32_t NVIC_PriorityGroup)
{
  /* Check the parameters */
  assert_param(IS_NVIC_PRIORITY_GROUP(NVIC_PriorityGroup));
  
  /* Set the PRIGROUP[10:8] bits according to NVIC_PriorityGroup value */
  SCB->AIRCR = AIRCR_VECTKEY_MASK | NVIC_PriorityGroup;
}
```

NVIC还支持低功耗唤醒的配置，使用下面的库函数配置低功耗唤醒源

```c
void NVIC_SystemLPConfig(uint8_t LowPowerMode, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_NVIC_LP(LowPowerMode));
  assert_param(IS_FUNCTIONAL_STATE(NewState));  
  
  if (NewState != DISABLE)
  {
    SCB->SCR |= LowPowerMode;
  }
  else
  {
    SCB->SCR &= (uint32_t)(~(uint32_t)LowPowerMode);
  }
}
```

NVIC配置结构体

```c
typedef struct
{
  uint8_t NVIC_IRQChannel; //NVIC通道
  uint8_t NVIC_IRQChannelPreemptionPriority; //抢占优先级
  uint8_t NVIC_IRQChannelSubPriority; //子优先级
  FunctionalState NVIC_IRQChannelCmd; //NVIC中断使能状态
} NVIC_InitTypeDef;
```

下面是一些关于中断的宏定义

```c
//中断向量表基地址
#define NVIC_VectTab_RAM             ((uint32_t)0x20000000)
#define NVIC_VectTab_FLASH           ((uint32_t)0x08000000)
#define IS_NVIC_VECTTAB(VECTTAB) (((VECTTAB) == NVIC_VectTab_RAM) || \
                                  ((VECTTAB) == NVIC_VectTab_FLASH))

//抢占优先级分组
#define NVIC_PriorityGroup_0         ((uint32_t)0x700) /*!< 0 bits for pre-emption priority
                                                            4 bits for subpriority */
#define NVIC_PriorityGroup_1         ((uint32_t)0x600) /*!< 1 bits for pre-emption priority
                                                            3 bits for subpriority */
#define NVIC_PriorityGroup_2         ((uint32_t)0x500) /*!< 2 bits for pre-emption priority
                                                            2 bits for subpriority */
#define NVIC_PriorityGroup_3         ((uint32_t)0x400) /*!< 3 bits for pre-emption priority
                                                            1 bits for subpriority */
#define NVIC_PriorityGroup_4         ((uint32_t)0x300) /*!< 4 bits for pre-emption priority
                                                            0 bits for subpriority */

#define IS_NVIC_PRIORITY_GROUP(GROUP) (((GROUP) == NVIC_PriorityGroup_0) || \
                                       ((GROUP) == NVIC_PriorityGroup_1) || \
                                       ((GROUP) == NVIC_PriorityGroup_2) || \
                                       ((GROUP) == NVIC_PriorityGroup_3) || \
                                       ((GROUP) == NVIC_PriorityGroup_4))

#define IS_NVIC_PREEMPTION_PRIORITY(PRIORITY)  ((PRIORITY) < 0x10)

#define IS_NVIC_SUB_PRIORITY(PRIORITY)  ((PRIORITY) < 0x10)

#define IS_NVIC_OFFSET(OFFSET)  ((OFFSET) < 0x000FFFFF)
```

misc中还有一些其他关于内核低功耗、systick时钟的库函数，这一部分不属于本文讨论范围，不再说明