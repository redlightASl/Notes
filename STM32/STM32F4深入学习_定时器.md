# 定时器时钟







## 内核定时器SYSTICK

参考《Cortex M3与M4权威指南》内核定时器部分以获取更多信息









## 通用定时器组1

通用定时器由TIM2、TIM3、TIM4、TIM5组成，其中TIM2、5拥有32位自动重载计数器，精度更高；TIM3、4拥有16位自动重载计数器，该计数器由可编程预分频器驱动，**预分频器为16位，分频系数在1到65536之间**

支持以下功能

* 通过输入捕获测量输入信号脉冲宽度
* 可使用外部信号控制定时器
* 可实现多个定时器互连的同步电路
* 四个独立的输入捕获、输出比较和PWM输出、单脉冲输出通道
* 产生DMA请求（触发源包括定时器溢出、初始化、输入捕获、输出比较、触发事件等）
* 支持驱动编码器和霍尔传感器
* 外部时钟触发输入或逐周期电流管理

所有这些定时器互相完全独立，不共享任何资源，可以让任意两个通用定时器同步工作

![image-20210516170041918](F:\Git_repository\Notes\STM32\STM32F4深入学习_定时器.assets\image-20210516170041918.png)

### 时基单元

**定时器的时基单元实际上就是一套用于稳定输出时钟的计数器**，定时器的其他高级功能都是在计数器的基础上实现的

这就是为什么定时器中断、输出PWM、检测输入信号等操作都需要预先设定时基单元

时基单元本身的时钟来自于RCC的TIMxCLK，由APB总线提供；不过也可以设定成由片外电路独立输入，也就是所谓的TIMxETR；甚至也可以用其他定时器触发，这就是“从模式-定时器级联”

时基单元包括：

* **计数器**寄存器 (TIMx_CNT)
* **预分频器**寄存器 (TIMx_PSC)
* **自动重载**寄存器 (TIMx_ARR)

计数器、自动重载寄存器和预分频器寄存器可通过软件进行读写。即使在计数器运行时也可执行读写操作。

自动重载寄存器是预装载的。对自动重载寄存器执行写入或读取操作时会访问预装载寄存器。预装载寄存器的内容既可以直接传送到影子寄存器，也可以在每次发生更新事件 (UEV) 时传送到影子寄存器，这取决于 TIMx_CR1 寄存器中的自动重载预装载使能位 (ARPE)。当 计数器达到上溢值（或者在递减计数时达到下溢值）并且 TIMx_CR1 寄存器中的 UDIS 位为 0 时，将发送更新事件。该更新事件也可由软件产生

计数器由预分频器输出 CK_CNT 提供时钟，仅当 TIMx_CR1 寄存器中的计数器启动位 (CEN) 置 1 时，才会启动计数器（有关计数器使能的更多详细信息，另请参见从模式控制器的相关 说明）。
请注意，真正的计数器使能信号 CNT_EN 在 CEN 置 1 的一个时钟周期后被置 1。

预分频器可对计数器时钟频率进行分频，分频系数介于 1 到 65536 之间。该预分频器基于 16 位/32 位寄存器（TIMx_PSC 寄存器）所控制的 16 位计数器。由于该控制寄存器具有缓 冲功能，因此预分频器可实现实时更改。而新的预分频比将在下一更新事件发生时被采用

![image-20210516170857412](F:\Git_repository\Notes\STM32\STM32F4深入学习_定时器.assets\image-20210516170857412.png)

![image-20210516170948206](F:\Git_repository\Notes\STM32\STM32F4深入学习_定时器.assets\image-20210516170948206.png)

### 定时器计数模式





在递增计数模式下，计数器从 0 计数到自动重载值（TIMx_ARR 寄存器的内容），然后重新 从 0 开始计数并生成计数器上溢事件。
每次发生计数器上溢时会生成更新事件，或将 TIMx_EGR 寄存器中的 UG 位置 1（通过软件 或使用从模式控制器）也可以生成更新事件。
通过软件将 TIMx_CR1 寄存器中的 UDIS 位置 1 可禁止 UEV 事件。这可避免向预装载寄存 器写入新值时更新影子寄存器。在 UDIS 位写入 0 之前不会产生任何更新事件。不过，计数 器和预分频器计数器都会重新从 0 开始计数（而预分频比保持不变）。此外，如果 TIMx_CR1 寄存器中的 URS 位（更新请求选择）已置 1，则将 UG 位置 1 会生成更新事件 UEV，但不会将 UIF 标志置 1（因此，不会发送任何中断或 DMA 请求）。这样一来，如果 在发生捕获事件时将计数器清零，将不会同时产生更新中断和捕获中断。
发生更新事件时，将更新所有寄存器且将更新标志（TIMx_SR 寄存器中的 UIF 位）置 1（取 决于 URS 位）：
● 预分频器的缓冲区中将重新装载预装载值（TIMx_PSC 寄存器的内容）
● 自动重载影子寄存器将以预装载值进行更新







## 通用定时器组2

通用定时器由TIM9到TIM14组成，包含一个16位自动重载计数器，该计数器由可编程预分频器驱动

支持的功能和通用定时器组1完全一致







## 高级定时器

高级定时器由TIM1和TIM8组成，两个定时器共用一个16位自动重载计数器，该计数器由可编程预分频器驱动

支持以下功能

* 通过输入捕获测量输入信号脉冲宽度
* 生成输出比较和PWM波
* 生成带死区插入的互补PWM

高级定时器和通用定时器彼此完全独立，但两个高级定时器会共享资源

高级定时器和通用定时器可以实现同步功能







## 基本定时器

基本定时器由TIM6和TIM7组成，包含一个16位自动重载计数器，该计数器由可编程预分频器驱动

可以用作通用定时器生成时基，也可以专用于驱动DAC——这两个定时器内部直连DAC并能够通过它触发输出驱动DAC，也就是说**TIM6和TIM7可以用作“模拟输出”**

两个定时器彼此完全独立，不共享资源







# STM32的STP定时器库函数

STM32的定时器库函数**非常多**

这里作以下基本梳理（大多是从.c文件开头的注释翻译整理）

## 库函数的基本使用方法

库函数被分成了9组功能，如下所示

### TIM时基管理

ST提供了一些库函数用来管理定时器的基础设置

时基管理的使用方法很简单，如下所示

> 1. 使用RCC_APBxPeriphClockCmd(RCC_APBxPeriph_TIMx, ENABLE)函数开启定时器时钟
> 2. 使用设定好的参数设置定时器初始化结构体
> 3. 使用TIM_TimeBaseInit()函数来应用定时器时基设置
> 4. 如果需要产生TIM更新中断，还需要使能NVIC并进行相关配置
> 5. 使用TIM_ITConfig(TIMx, TIM_IT_Update)函数配置中断服务函数
> 6. 使用TIM_Cmd(ENABLE)函数使能TIM计数器

* 设置/获取分频系数Prescaler

```c
//设置分频系数
void TIM_PrescalerConfig(TIM_TypeDef* TIMx, uint16_t Prescaler, uint16_t TIM_PSCReloadMode)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_PRESCALER_RELOAD(TIM_PSCReloadMode));
  /* Set the Prescaler value */
  TIMx->PSC = Prescaler;
  /* Set or reset the UG Bit */
  TIMx->EGR = TIM_PSCReloadMode;
}
```

* 设置/获取自动重装值Autoreload

```c
//设置定时器自动重装载值
void TIM_SetAutoreload(TIM_TypeDef* TIMx, uint32_t Autoreload)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  
  /* Set the Autoreload Register value */
  TIMx->ARR = Autoreload;
}

//获取定时器自动重装载值
uint16_t TIM_GetPrescaler(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));

  /* Get the Prescaler Register value */
  return TIMx->PSC;
}

//设置定时器计数器寄存器值
void TIM_SetCounter(TIM_TypeDef* TIMx, uint32_t Counter)
{
  /* Check the parameters */
   assert_param(IS_TIM_ALL_PERIPH(TIMx));

  /* Set the Counter Register value */
  TIMx->CNT = Counter;
}

//获取定时器计数器寄存器值
uint32_t TIM_GetCounter(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));

  /* Get the Counter Register value */
  return TIMx->CNT;
}
```

* 计时模式配置

```c
//设置定时器计数器模式
void TIM_CounterModeConfig(TIM_TypeDef* TIMx, uint16_t TIM_CounterMode)
{
  uint16_t tmpcr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_COUNTER_MODE(TIM_CounterMode));

  tmpcr1 = TIMx->CR1;

  /* Reset the CMS and DIR Bits */
  tmpcr1 &= (uint16_t)~(TIM_CR1_DIR | TIM_CR1_CMS);

  /* Set the Counter Mode */
  tmpcr1 |= TIM_CounterMode;

  /* Write to TIMx CR1 register */
  TIMx->CR1 = tmpcr1;
}
```

* 设置时钟分频

```c
void TIM_SetClockDivision(TIM_TypeDef* TIMx, uint16_t TIM_CKD)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_CKD_DIV(TIM_CKD));

  /* Reset the CKD Bits */
  TIMx->CR1 &= (uint16_t)(~TIM_CR1_CKD);

  /* Set the CKD value */
  TIMx->CR1 |= TIM_CKD;
}
```

* 选择单脉冲模式

```c
void TIM_SelectOnePulseMode(TIM_TypeDef* TIMx, uint16_t TIM_OPMode)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_OPM_MODE(TIM_OPMode));

  /* Reset the OPM Bit */
  TIMx->CR1 &= (uint16_t)~TIM_CR1_OPM;

  /* Configure the OPM Mode */
  TIMx->CR1 |= TIM_OPMode;
}
```

* 更新请求配置

```c
//定时器更新中断请求配置
void TIM_UpdateRequestConfig(TIM_TypeDef* TIMx, uint16_t TIM_UpdateSource)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_UPDATE_SOURCE(TIM_UpdateSource));

  if (TIM_UpdateSource != TIM_UpdateSource_Global)
  {
    /* Set the URS Bit */
    TIMx->CR1 |= TIM_CR1_URS;
  }
  else
  {
    /* Reset the URS Bit */
    TIMx->CR1 &= (uint16_t)~TIM_CR1_URS;
  }
}
```

* 更新失能配置

```c
//定时器更新中断失能控制
void TIM_UpdateDisableConfig(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the Update Disable Bit */
    TIMx->CR1 |= TIM_CR1_UDIS;
  }
  else
  {
    /* Reset the Update Disable Bit */
    TIMx->CR1 &= (uint16_t)~TIM_CR1_UDIS;
  }
}
```

* 自动重装载配置

```c
//ARR预装载寄存器配置
void TIM_ARRPreloadConfig(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the ARR Preload Bit */
    TIMx->CR1 |= TIM_CR1_ARPE;
  }
  else
  {
    /* Reset the ARR Preload Bit */
    TIMx->CR1 &= (uint16_t)~TIM_CR1_ARPE;
  }
}
```

* 使能/关闭计数器

```c
void TIM_Cmd(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx)); 
  assert_param(IS_FUNCTIONAL_STATE(NewState));
  
  if (NewState != DISABLE)
  {
    /* Enable the TIM Counter */
    TIMx->CR1 |= TIM_CR1_CEN;
  }
  else
  {
    /* Disable the TIM Counter */
    TIMx->CR1 &= (uint16_t)~TIM_CR1_CEN;
  }
}
```

相关函数如下所示

```c
//取消定时器初始化并关闭时钟
void TIM_DeInit(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx)); 
 
  if (TIMx == TIM1)
  {
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM1, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM1, DISABLE);  
  } 
  else if (TIMx == TIM2) 
  {     
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM2, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM2, DISABLE);
  }  
  else if (TIMx == TIM3)
  { 
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM3, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM3, DISABLE);
  }  
  else if (TIMx == TIM4)
  { 
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM4, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM4, DISABLE);
  }  
  else if (TIMx == TIM5)
  {      
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM5, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM5, DISABLE);
  }  
  else if (TIMx == TIM6)  
  {    
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM6, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM6, DISABLE);
  }  
  else if (TIMx == TIM7)
  {      
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM7, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM7, DISABLE);
  }  
  else if (TIMx == TIM8)
  {      
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM8, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM8, DISABLE);  
  }  
  else if (TIMx == TIM9)
  {      
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM9, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM9, DISABLE);  
   }  
  else if (TIMx == TIM10)
  {      
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM10, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM10, DISABLE);  
  }  
  else if (TIMx == TIM11) 
  {     
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM11, ENABLE);
    RCC_APB2PeriphResetCmd(RCC_APB2Periph_TIM11, DISABLE);  
  }  
  else if (TIMx == TIM12)
  {      
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM12, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM12, DISABLE);  
  }  
  else if (TIMx == TIM13) 
  {       
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM13, ENABLE);
    RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM13, DISABLE);  
  }  
  else
  { 
    if (TIMx == TIM14) 
    {     
      RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM14, ENABLE);
      RCC_APB1PeriphResetCmd(RCC_APB1Periph_TIM14, DISABLE); 
    }   
  }
}

//根据已有设置配置定时器初始化结构体
void TIM_TimeBaseStructInit(TIM_TimeBaseInitTypeDef* TIM_TimeBaseInitStruct)
{
  /* Set the default configuration */
  TIM_TimeBaseInitStruct->TIM_Period = 0xFFFFFFFF;
  TIM_TimeBaseInitStruct->TIM_Prescaler = 0x0000;
  TIM_TimeBaseInitStruct->TIM_ClockDivision = TIM_CKD_DIV1;
  TIM_TimeBaseInitStruct->TIM_CounterMode = TIM_CounterMode_Up;
  TIM_TimeBaseInitStruct->TIM_RepetitionCounter = 0x0000;
}

//根据初始化结构体配置定时器设置
void TIM_TimeBaseInit(TIM_TypeDef* TIMx, TIM_TimeBaseInitTypeDef* TIM_TimeBaseInitStruct)
{
  uint16_t tmpcr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx)); 
  assert_param(IS_TIM_COUNTER_MODE(TIM_TimeBaseInitStruct->TIM_CounterMode));
  assert_param(IS_TIM_CKD_DIV(TIM_TimeBaseInitStruct->TIM_ClockDivision));

  tmpcr1 = TIMx->CR1;  

  if((TIMx == TIM1) || (TIMx == TIM8)||
     (TIMx == TIM2) || (TIMx == TIM3)||
     (TIMx == TIM4) || (TIMx == TIM5)) 
  {
    /* Select the Counter Mode */
    tmpcr1 &= (uint16_t)(~(TIM_CR1_DIR | TIM_CR1_CMS));
    tmpcr1 |= (uint32_t)TIM_TimeBaseInitStruct->TIM_CounterMode;
  }
 
  if((TIMx != TIM6) && (TIMx != TIM7))
  {
    /* Set the clock division */
    tmpcr1 &=  (uint16_t)(~TIM_CR1_CKD);
    tmpcr1 |= (uint32_t)TIM_TimeBaseInitStruct->TIM_ClockDivision;
  }

  TIMx->CR1 = tmpcr1;

  /* Set the Autoreload value */
  TIMx->ARR = TIM_TimeBaseInitStruct->TIM_Period ;
 
  /* Set the Prescaler value */
  TIMx->PSC = TIM_TimeBaseInitStruct->TIM_Prescaler;
    
  if ((TIMx == TIM1) || (TIMx == TIM8))  
  {
    /* Set the Repetition Counter value */
    TIMx->RCR = TIM_TimeBaseInitStruct->TIM_RepetitionCounter;
  }

  /* Generate an update event to reload the Prescaler 
     and the repetition counter(only for TIM1 and TIM8) value immediatly */
  TIMx->EGR = TIM_PSCReloadMode_Immediate;          
}
```

### TIM输出比较管理

ST提供了有关输出捕获与输出比较的库函数

输出捕获实际上就是对定时器的输出信号进行监测，从而实现PWM等操作

使用方法如下：

> 1. 使用RCC_APBxPeriphClockCmd(RCC_APBxPeriph_TIMx, ENABLE)函数开启定时器时钟
> 2. 配置GPIO为复用模式并配置定时器到GPIO的复用选项
> 3. 使用下面的参数配置定时器时基单元初始化结构体设置
>    * 自动重装载值 = 0xFFFF
>    * 分频系数 = 0x0000
>    * 计数模式：向上计数
>    * 时钟分频：TIM_CKD_DIV1
> 4. 使用下面的参数配置定时器输出捕获初始化结构体设置
>    * 输出比较模式：TIM_OCMode
>    * 输出状态：TIM_OutputState
>    * 定时器脉冲值：TIM_Pulse
>    * 定时器输出比较极性：根据输出比较所需电平有效性选择
> 5. 使用TIM_OCxInit(TIMx, &TIM_OCInitStruct)函数使用合适的配置来设置所需的通道
> 6. 使用TIM_Cmd(ENABLE)使能定时器计数器
> 7. 如果要使用PWM输出，需要额外使能输出捕获预装载寄存器，使用函数TIM_OCxPreloadConfig(TIMx, TIM_OCPreload_ENABLE)
> 8. 可以在输出捕获的基础上使用定时器中断或DMA，只要使用对应库函数TIM_ITConfig(TIMx, TIM_IT_CCx)或TIM_DMA_Cmd(TIMx, TIM_DMA_CCx)提前进行配置即可

输出捕获的最简单用法就是PWM，但是除了这个功能，他还能实现更多更复杂的功能，相关库函数如下：

* 将每个通道独立配置为输出比较

```c
//初始化通道1输入捕获
void TIM_OC1Init(TIM_TypeDef* TIMx, TIM_OCInitTypeDef* TIM_OCInitStruct)
{
  uint16_t tmpccmrx = 0, tmpccer = 0, tmpcr2 = 0;
   
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx)); 
  assert_param(IS_TIM_OC_MODE(TIM_OCInitStruct->TIM_OCMode));
  assert_param(IS_TIM_OUTPUT_STATE(TIM_OCInitStruct->TIM_OutputState));
  assert_param(IS_TIM_OC_POLARITY(TIM_OCInitStruct->TIM_OCPolarity));   

  /* Disable the Channel 1: Reset the CC1E Bit */
  TIMx->CCER &= (uint16_t)~TIM_CCER_CC1E;
  
  /* Get the TIMx CCER register value */
  tmpccer = TIMx->CCER;
  /* Get the TIMx CR2 register value */
  tmpcr2 =  TIMx->CR2;
  
  /* Get the TIMx CCMR1 register value */
  tmpccmrx = TIMx->CCMR1;
    
  /* Reset the Output Compare Mode Bits */
  tmpccmrx &= (uint16_t)~TIM_CCMR1_OC1M;
  tmpccmrx &= (uint16_t)~TIM_CCMR1_CC1S;
  /* Select the Output Compare Mode */
  tmpccmrx |= TIM_OCInitStruct->TIM_OCMode;
  
  /* Reset the Output Polarity level */
  tmpccer &= (uint16_t)~TIM_CCER_CC1P;
  /* Set the Output Compare Polarity */
  tmpccer |= TIM_OCInitStruct->TIM_OCPolarity;
  
  /* Set the Output State */
  tmpccer |= TIM_OCInitStruct->TIM_OutputState;
    
  if((TIMx == TIM1) || (TIMx == TIM8))
  {
    assert_param(IS_TIM_OUTPUTN_STATE(TIM_OCInitStruct->TIM_OutputNState));
    assert_param(IS_TIM_OCN_POLARITY(TIM_OCInitStruct->TIM_OCNPolarity));
    assert_param(IS_TIM_OCNIDLE_STATE(TIM_OCInitStruct->TIM_OCNIdleState));
    assert_param(IS_TIM_OCIDLE_STATE(TIM_OCInitStruct->TIM_OCIdleState));
    
    /* Reset the Output N Polarity level */
    tmpccer &= (uint16_t)~TIM_CCER_CC1NP;
    /* Set the Output N Polarity */
    tmpccer |= TIM_OCInitStruct->TIM_OCNPolarity;
    /* Reset the Output N State */
    tmpccer &= (uint16_t)~TIM_CCER_CC1NE;
    
    /* Set the Output N State */
    tmpccer |= TIM_OCInitStruct->TIM_OutputNState;
    /* Reset the Output Compare and Output Compare N IDLE State */
    tmpcr2 &= (uint16_t)~TIM_CR2_OIS1;
    tmpcr2 &= (uint16_t)~TIM_CR2_OIS1N;
    /* Set the Output Idle state */
    tmpcr2 |= TIM_OCInitStruct->TIM_OCIdleState;
    /* Set the Output N Idle state */
    tmpcr2 |= TIM_OCInitStruct->TIM_OCNIdleState;
  }
  /* Write to TIMx CR2 */
  TIMx->CR2 = tmpcr2;
  
  /* Write to TIMx CCMR1 */
  TIMx->CCMR1 = tmpccmrx;
  
  /* Set the Capture Compare Register value */
  TIMx->CCR1 = TIM_OCInitStruct->TIM_Pulse;
  
  /* Write to TIMx CCER */
  TIMx->CCER = tmpccer;
}

//初始化通道2、通道3、通道4的库函数与初始化通道1库函数不能说一模一样，只能说别无二致，所以在此不列出

//使用默认设置初始化输入捕获初始化结构体
void TIM_OCStructInit(TIM_OCInitTypeDef* TIM_OCInitStruct)
{
  /* Set the default configuration */
  TIM_OCInitStruct->TIM_OCMode = TIM_OCMode_Timing;
  TIM_OCInitStruct->TIM_OutputState = TIM_OutputState_Disable;
  TIM_OCInitStruct->TIM_OutputNState = TIM_OutputNState_Disable;
  TIM_OCInitStruct->TIM_Pulse = 0x00000000;
  TIM_OCInitStruct->TIM_OCPolarity = TIM_OCPolarity_High;
  TIM_OCInitStruct->TIM_OCNPolarity = TIM_OCPolarity_High;
  TIM_OCInitStruct->TIM_OCIdleState = TIM_OCIdleState_Reset;
  TIM_OCInitStruct->TIM_OCNIdleState = TIM_OCNIdleState_Reset;
}

```

* 选择输出比较模式

```c
//选择输出比较的通道、使用定时器x、输出比较的模式
void TIM_SelectOCxM(TIM_TypeDef* TIMx, uint16_t TIM_Channel, uint16_t TIM_OCMode)
{
  uint32_t tmp = 0;
  uint16_t tmp1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_CHANNEL(TIM_Channel));
  assert_param(IS_TIM_OCM(TIM_OCMode));

  tmp = (uint32_t) TIMx;
  tmp += CCMR_OFFSET;

  tmp1 = CCER_CCE_SET << (uint16_t)TIM_Channel;

  /* Disable the Channel: Reset the CCxE Bit */
  TIMx->CCER &= (uint16_t) ~tmp1;

  if((TIM_Channel == TIM_Channel_1) ||(TIM_Channel == TIM_Channel_3))
  {
    tmp += (TIM_Channel>>1);

    /* Reset the OCxM bits in the CCMRx register */
    *(__IO uint32_t *) tmp &= CCMR_OC13M_MASK;
   
    /* Configure the OCxM bits in the CCMRx register */
    *(__IO uint32_t *) tmp |= TIM_OCMode;
  }
  else
  {
    tmp += (uint16_t)(TIM_Channel - (uint16_t)4)>> (uint16_t)1;

    /* Reset the OCxM bits in the CCMRx register */
    *(__IO uint32_t *) tmp &= CCMR_OC24M_MASK;
    
    /* Configure the OCxM bits in the CCMRx register */
    *(__IO uint32_t *) tmp |= (uint16_t)(TIM_OCMode << 8);
  }
}
/*
可以使用如下模式：
定时 TIM_OCMode_Timing
启动 TIM_OCMode_Active
翻转 TIM_OCMode_Toggle
PWM模式1 TIM_OCMode_PWM1
PWM模式2 TIM_OCMode_PWM2
强制启动 TIM_ForcedAction_Active
强制停止 TIM_ForcedAction_InActive
*/
```

* 选择每个通道的极性

```c
//设置正极性
void TIM_OC1PolarityConfig(TIM_TypeDef* TIMx, uint16_t TIM_OCPolarity)
{
  uint16_t tmpccer = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_OC_POLARITY(TIM_OCPolarity));

  tmpccer = TIMx->CCER;

  /* Set or Reset the CC1P Bit */
  tmpccer &= (uint16_t)(~TIM_CCER_CC1P);
  tmpccer |= TIM_OCPolarity;

  /* Write to TIMx CCER register */
  TIMx->CCER = tmpccer;
}

//设置负极性
void TIM_OC1NPolarityConfig(TIM_TypeDef* TIMx, uint16_t TIM_OCNPolarity)
{
  uint16_t tmpccer = 0;
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_TIM_OCN_POLARITY(TIM_OCNPolarity));
   
  tmpccer = TIMx->CCER;

  /* Set or Reset the CC1NP Bit */
  tmpccer &= (uint16_t)~TIM_CCER_CC1NP;
  tmpccer |= TIM_OCNPolarity;

  /* Write to TIMx CCER register */
  TIMx->CCER = tmpccer;
}

//两个库函数都有4个不同通道的设置，在此仅列出通道1
```

* 设置/获取输出捕获/比较寄存器的值

```c
//设置输出比较寄存器1、2、3、4的值
//每个输出比较寄存器对应一个通道
void TIM_SetCompare1(TIM_TypeDef* TIMx, uint32_t Compare1)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));

  /* Set the Capture Compare1 Register value */
  TIMx->CCR1 = Compare1;
}

void TIM_SetCompare2(TIM_TypeDef* TIMx, uint32_t Compare2)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));

  /* Set the Capture Compare2 Register value */
  TIMx->CCR2 = Compare2;
}

//3、4的库函数和1、2大同小异，在此不列出

//设置输出捕获寄存器1、2、3、4的值，2、3、4的设置库函数不列出
void TIM_ForcedOC1Config(TIM_TypeDef* TIMx, uint16_t TIM_ForcedAction)
{
  uint16_t tmpccmr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_FORCED_ACTION(TIM_ForcedAction));
  tmpccmr1 = TIMx->CCMR1;

  /* Reset the OC1M Bits */
  tmpccmr1 &= (uint16_t)~TIM_CCMR1_OC1M;

  /* Configure The Forced output Mode */
  tmpccmr1 |= TIM_ForcedAction;

  /* Write to TIMx CCMR1 register */
  TIMx->CCMR1 = tmpccmr1;
}

//设置定时器输出捕获预装载寄存器的值（同样是4个通道）
void TIM_OC1PreloadConfig(TIM_TypeDef* TIMx, uint16_t TIM_OCPreload)
{
  uint16_t tmpccmr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_OCPRELOAD_STATE(TIM_OCPreload));

  tmpccmr1 = TIMx->CCMR1;

  /* Reset the OC1PE Bit */
  tmpccmr1 &= (uint16_t)(~TIM_CCMR1_OC1PE);

  /* Enable or Disable the Output Compare Preload feature */
  tmpccmr1 |= TIM_OCPreload;

  /* Write to TIMx CCMR1 register */
  TIMx->CCMR1 = tmpccmr1;
}
```

* 选择输出比较快速模式（Output Compare Fast mode）

```c
//输出比较快速模式设置（4个通道）
void TIM_OC1FastConfig(TIM_TypeDef* TIMx, uint16_t TIM_OCFast)
{
  uint16_t tmpccmr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_OCFAST_STATE(TIM_OCFast));

  /* Get the TIMx CCMR1 register value */
  tmpccmr1 = TIMx->CCMR1;

  /* Reset the OC1FE Bit */
  tmpccmr1 &= (uint16_t)~TIM_CCMR1_OC1FE;

  /* Enable or Disable the Output Compare Fast Bit */
  tmpccmr1 |= TIM_OCFast;

  /* Write to TIMx CCMR1 */
  TIMx->CCMR1 = tmpccmr1;
}

```

* 选择输出比较强制模式（Output Compare Forced mode）
* 输出比较-预装载模式
* 清空输出比较参考值

```c
//清空输出比较参考值（4通道）
void TIM_ClearOC1Ref(TIM_TypeDef* TIMx, uint16_t TIM_OCClear)
{
  uint16_t tmpccmr1 = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_OCCLEAR_STATE(TIM_OCClear));

  tmpccmr1 = TIMx->CCMR1;

  /* Reset the OC1CE Bit */
  tmpccmr1 &= (uint16_t)~TIM_CCMR1_OC1CE;

  /* Enable or Disable the Output Compare Clear Bit */
  tmpccmr1 |= TIM_OCClear;

  /* Write to TIMx CCMR1 register */
  TIMx->CCMR1 = tmpccmr1;
}
```

* 选择OCREF清空信号
* 使能/失能捕获/比较通道

```c
//控制捕获通道开启/关闭
void TIM_CCxCmd(TIM_TypeDef* TIMx, uint16_t TIM_Channel, uint16_t TIM_CCx)
{
  uint16_t tmp = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx)); 
  assert_param(IS_TIM_CHANNEL(TIM_Channel));
  assert_param(IS_TIM_CCX(TIM_CCx));

  tmp = CCER_CCE_SET << TIM_Channel;

  /* Reset the CCxE Bit */
  TIMx->CCER &= (uint16_t)~ tmp;

  /* Set or reset the CCxE Bit */ 
  TIMx->CCER |=  (uint16_t)(TIM_CCx << TIM_Channel);
}

//控制捕获比较通道开启/关闭
void TIM_CCxNCmd(TIM_TypeDef* TIMx, uint16_t TIM_Channel, uint16_t TIM_CCxN)
{
  uint16_t tmp = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_TIM_COMPLEMENTARY_CHANNEL(TIM_Channel));
  assert_param(IS_TIM_CCXN(TIM_CCxN));

  tmp = CCER_CCNE_SET << TIM_Channel;

  /* Reset the CCxNE Bit */
  TIMx->CCER &= (uint16_t) ~tmp;

  /* Set or reset the CCxNE Bit */ 
  TIMx->CCER |=  (uint16_t)(TIM_CCxN << TIM_Channel);
}
```

### TIM输入捕获管理

ST也提供了定时器输入捕获的库函数

基本使用方法如下：

> 1. 使用RCC_APBxPeriphClockCmd(RCC_APBxPeriph_TIMx, ENABLE) 函数开启定时器时钟
> 2. 将GPIO配置为合适的输入引脚，设置位复用模式并连接到定时器输入捕获
> 3. 如果需要可以自行配置定时器时基设定，但推荐默认状态为：
>    * 自动重装载值：0xFFFF
>    * 分频值：0x0000
>    * 计数模式：向上计数
>    * 时钟分频：TIM_CKD_DIV1一分频
> 4. 使用以下参数配置定时器输入捕获初始化结构体
>    * 定时器通道：选择合适的通道
>    * 定时器输入捕获选项：根据输入捕获选择
>    * 定时器输入捕获分频：随机应变
>    * 定时器输入捕获屏蔽器值：根据要过滤的捕获信号设置
> 5. 使用TIM_ICInit(TIMx, &TIM_ICInitStruct)函数根据上面的设置配置所需通道，就可以让定时器输入捕获测量输入信号的频率、占空比，或使用TIM_PWMIConfig(TIMx, &TIM_ICInitStruct)函数配置通道来测量输入PWM波的频率和占空比
> 6. 可使用中断或DMA方式读取测量信号，TIM_ITConfig(TIMx, TIM_IT_CCx)和TIM_DMA_Cmd(TIMx, TIM_DMA_CCx)函数都可选
> 7. 使用TIM_Cmd(ENABLE)来开启定时器计数器
> 8. 使用TIM_GetCapturex(TIMx)来读取捕获到的值

* 单独配置每个通道位输入捕获模式

```c
//根据输入捕获初始化结构体配置某个通道为输入捕获模式
void TIM_ICInit(TIM_TypeDef* TIMx, TIM_ICInitTypeDef* TIM_ICInitStruct)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_IC_POLARITY(TIM_ICInitStruct->TIM_ICPolarity));
  assert_param(IS_TIM_IC_SELECTION(TIM_ICInitStruct->TIM_ICSelection));
  assert_param(IS_TIM_IC_PRESCALER(TIM_ICInitStruct->TIM_ICPrescaler));
  assert_param(IS_TIM_IC_FILTER(TIM_ICInitStruct->TIM_ICFilter));
  
  if (TIM_ICInitStruct->TIM_Channel == TIM_Channel_1)
  {
    /* TI1 Configuration */
    TI1_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity,
               TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC1Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
  else if (TIM_ICInitStruct->TIM_Channel == TIM_Channel_2)
  {
    /* TI2 Configuration */
    assert_param(IS_TIM_LIST2_PERIPH(TIMx));
    TI2_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity,
               TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC2Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
  else if (TIM_ICInitStruct->TIM_Channel == TIM_Channel_3)
  {
    /* TI3 Configuration */
    assert_param(IS_TIM_LIST3_PERIPH(TIMx));
    TI3_Config(TIMx,  TIM_ICInitStruct->TIM_ICPolarity,
               TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC3Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
  else
  {
    /* TI4 Configuration */
    assert_param(IS_TIM_LIST3_PERIPH(TIMx));
    TI4_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity,
               TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC4Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
}

//使用默认设置配置输入捕获初始化结构体
void TIM_ICStructInit(TIM_ICInitTypeDef* TIM_ICInitStruct)
{
  /* Set the default configuration */
  TIM_ICInitStruct->TIM_Channel = TIM_Channel_1;
  TIM_ICInitStruct->TIM_ICPolarity = TIM_ICPolarity_Rising;
  TIM_ICInitStruct->TIM_ICSelection = TIM_ICSelection_DirectTI;
  TIM_ICInitStruct->TIM_ICPrescaler = TIM_ICPSC_DIV1;
  TIM_ICInitStruct->TIM_ICFilter = 0x00;
}
```

* 可配置通道1/2处于PWM输入模式，用于获取外部脉冲/测量外部信号频率（如编码器输入、遥控信号输入等）

```c
//配置通道为PWM输入模式
void TIM_PWMIConfig(TIM_TypeDef* TIMx, TIM_ICInitTypeDef* TIM_ICInitStruct)
{
  uint16_t icoppositepolarity = TIM_ICPolarity_Rising;
  uint16_t icoppositeselection = TIM_ICSelection_DirectTI;

  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));

  /* Select the Opposite Input Polarity */
  if (TIM_ICInitStruct->TIM_ICPolarity == TIM_ICPolarity_Rising)
  {
    icoppositepolarity = TIM_ICPolarity_Falling;
  }
  else
  {
    icoppositepolarity = TIM_ICPolarity_Rising;
  }
  /* Select the Opposite Input */
  if (TIM_ICInitStruct->TIM_ICSelection == TIM_ICSelection_DirectTI)
  {
    icoppositeselection = TIM_ICSelection_IndirectTI;
  }
  else
  {
    icoppositeselection = TIM_ICSelection_DirectTI;
  }
  if (TIM_ICInitStruct->TIM_Channel == TIM_Channel_1)
  {
    /* TI1 Configuration */
    TI1_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity, TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC1Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
    /* TI2 Configuration */
    TI2_Config(TIMx, icoppositepolarity, icoppositeselection, TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC2Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
  else
  { 
    /* TI2 Configuration */
    TI2_Config(TIMx, TIM_ICInitStruct->TIM_ICPolarity, TIM_ICInitStruct->TIM_ICSelection,
               TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC2Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
    /* TI1 Configuration */
    TI1_Config(TIMx, icoppositepolarity, icoppositeselection, TIM_ICInitStruct->TIM_ICFilter);
    /* Set the Input Capture Prescaler value */
    TIM_SetIC1Prescaler(TIMx, TIM_ICInitStruct->TIM_ICPrescaler);
  }
}
```

* 设置输入捕获预分频器

```c
//设置输入捕获1、2、3、4通道预分频器的值
void TIM_SetIC1Prescaler(TIM_TypeDef* TIMx, uint16_t TIM_ICPSC)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_IC_PRESCALER(TIM_ICPSC));

  /* Reset the IC1PSC Bits */
  TIMx->CCMR1 &= (uint16_t)~TIM_CCMR1_IC1PSC;

  /* Set the IC1PSC value */
  TIMx->CCMR1 |= TIM_ICPSC;
}
```

* 获取捕获/比较值

```c
//获取输入捕获1、2、3、4的值
uint32_t TIM_GetCapture1(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));

  /* Get the Capture 1 Register value */
  return TIMx->CCR1;
}

uint32_t TIM_GetCapture2(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));

  /* Get the Capture 2 Register value */
  return TIMx->CCR2;
}

uint32_t TIM_GetCapture3(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx)); 

  /* Get the Capture 3 Register value */
  return TIMx->CCR3;
}

uint32_t TIM_GetCapture4(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));

  /* Get the Capture 4 Register value */
  return TIMx->CCR4;
}
```

### 高级定时器（TIM1、TIM8）的特殊控制库函数

STM32F4中具有两个高级定时器，ST也为它们提供了库函数

下面是基本使用方法

> 1. 使用输出比较模式配置定时器通道
> 2. 使用TIM_BDTRInitStruct结构体设置时钟断点极性、死区时间、锁定等级、OSSI/OSSR状态和AOE（自动输出使能）模式
> 3. 使用TIM_BDTRConfig(TIMx, &TIM_BDTRInitStruct)配置定时器的高级功能
> 4. 使用TIM_CtrlPWMOutputs(TIM1, ENABLE)函数使能主输出
> 5. 一旦断点发生，定时器的输出信号就会被置于重置或某个经过TIM_BDTRConfig()设定的状态

* 配置断点输入（Break input）、死区时间、锁定等级、OSSI、OSSR状态、AOE（自动输入使能）

```c
void TIM_BDTRConfig(TIM_TypeDef* TIMx, TIM_BDTRInitTypeDef *TIM_BDTRInitStruct)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_TIM_OSSR_STATE(TIM_BDTRInitStruct->TIM_OSSRState));
  assert_param(IS_TIM_OSSI_STATE(TIM_BDTRInitStruct->TIM_OSSIState));
  assert_param(IS_TIM_LOCK_LEVEL(TIM_BDTRInitStruct->TIM_LOCKLevel));
  assert_param(IS_TIM_BREAK_STATE(TIM_BDTRInitStruct->TIM_Break));
  assert_param(IS_TIM_BREAK_POLARITY(TIM_BDTRInitStruct->TIM_BreakPolarity));
  assert_param(IS_TIM_AUTOMATIC_OUTPUT_STATE(TIM_BDTRInitStruct->TIM_AutomaticOutput));

  /* Set the Lock level, the Break enable Bit and the Polarity, the OSSR State,
     the OSSI State, the dead time value and the Automatic Output Enable Bit */
  TIMx->BDTR = (uint32_t)TIM_BDTRInitStruct->TIM_OSSRState | TIM_BDTRInitStruct->TIM_OSSIState |
             TIM_BDTRInitStruct->TIM_LOCKLevel | TIM_BDTRInitStruct->TIM_DeadTime |
             TIM_BDTRInitStruct->TIM_Break | TIM_BDTRInitStruct->TIM_BreakPolarity |
             TIM_BDTRInitStruct->TIM_AutomaticOutput;
}

//使用初始化结构体默认设置
void TIM_BDTRStructInit(TIM_BDTRInitTypeDef* TIM_BDTRInitStruct)
{
  /* Set the default configuration */
  TIM_BDTRInitStruct->TIM_OSSRState = TIM_OSSRState_Disable;
  TIM_BDTRInitStruct->TIM_OSSIState = TIM_OSSIState_Disable;
  TIM_BDTRInitStruct->TIM_LOCKLevel = TIM_LOCKLevel_OFF;
  TIM_BDTRInitStruct->TIM_DeadTime = 0x00;
  TIM_BDTRInitStruct->TIM_Break = TIM_Break_Disable;
  TIM_BDTRInitStruct->TIM_BreakPolarity = TIM_BreakPolarity_Low;
  TIM_BDTRInitStruct->TIM_AutomaticOutput = TIM_AutomaticOutput_Disable;
}
```

* 使能/失能定时器外设主输出

```c
void TIM_CtrlPWMOutputs(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Enable the TIM Main Output */
    TIMx->BDTR |= TIM_BDTR_MOE;
  }
  else
  {
    /* Disable the TIM Main Output */
    TIMx->BDTR &= (uint16_t)~TIM_BDTR_MOE;
  }  
}
```

* 选择通讯事件

```c
//选择通信事件
void TIM_SelectCOM(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the COM Bit */
    TIMx->CR2 |= TIM_CR2_CCUS;
  }
  else
  {
    /* Reset the COM Bit */
    TIMx->CR2 &= (uint16_t)~TIM_CR2_CCUS;
  }
}
```

* 设置/重置捕获比较预装载控制位

```c
//设置捕获比较预装载控制位
void TIM_CCPreloadControl(TIM_TypeDef* TIMx, FunctionalState NewState)
{ 
  /* Check the parameters */
  assert_param(IS_TIM_LIST4_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));
  if (NewState != DISABLE)
  {
    /* Set the CCPC Bit */
    TIMx->CR2 |= TIM_CR2_CCPC;
  }
  else
  {
    /* Reset the CCPC Bit */
    TIMx->CR2 &= (uint16_t)~TIM_CR2_CCPC;
  }
}
```

### 定时器中断、DMA与标志位管理

STM32中的一些定时器是可以触发定时器中断、DMA的，ST也提供了管理库函数

* 使能/失能中断源

```c
//使能或关闭定时器中断
void TIM_ITConfig(TIM_TypeDef* TIMx, uint16_t TIM_IT, FunctionalState NewState)
{  
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_IT(TIM_IT));
  assert_param(IS_FUNCTIONAL_STATE(NewState));
  
  if (NewState != DISABLE)
  {
    /* Enable the Interrupt sources */
    TIMx->DIER |= TIM_IT;
  }
  else
  {
    /* Disable the Interrupt sources */
    TIMx->DIER &= (uint16_t)~TIM_IT;
  }
}

/* 
TIM_IT参数可设置为以下值
TIM_IT_Update:定时器更新中断
TIM_IT_CC1:定时器比较中断4
TIM_IT_CC2:定时器比较中断4
TIM_IT_CC3:定时器比较中断4
TIM_IT_CC4:定时器比较中断4
TIM_IT_COM:定时器通讯中断
TIM_IT_Trigger:定时器触发中断
TIM_IT_Break:定时器暂停中断

TIM6和TIM7只能使用TIM_IT_Update，TIM9和TIM12只能使用TIM_IT_Update，TIM_IT_CC1, TIM_IT_CC2或TIM_IT_Trigger
TIM10、11、13、14只能使用TIM_IT_Update或TIM_IT_CC1
TIM1和TIM8两个高级定时器才被允许使用TIM_IT_COM和TIM_IT_Break
*/

//设置定时器软件事件
void TIM_GenerateEvent(TIM_TypeDef* TIMx, uint16_t TIM_EventSource)
{ 
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_EVENT_SOURCE(TIM_EventSource));
 
  /* Set the event sources */
  TIMx->EGR = TIM_EventSource;
}

/*
TIM_EventSource_Update:定时器更新事件（下面内容和上面中断的内冲差不多，懒得翻译了）
TIM_EventSource_CC1: Timer Capture Compare 1 Event source
TIM_EventSource_CC2: Timer Capture Compare 2 Event source
TIM_EventSource_CC3: Timer Capture Compare 3 Event source
TIM_EventSource_CC4: Timer Capture Compare 4 Event source
TIM_EventSource_COM: Timer COM event source  
TIM_EventSource_Trigger: Timer Trigger Event source
TIM_EventSource_Break: Timer Break event source

其中TIM6、7只能使用定时器更新事件；只有高级定时器TIM1、8才能使用后三个高级事件功能
*/
```

* 获取标志状态

```c
//获取当前中断标志位状态
FlagStatus TIM_GetFlagStatus(TIM_TypeDef* TIMx, uint16_t TIM_FLAG)
{ 
  ITStatus bitstatus = RESET;  
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_GET_FLAG(TIM_FLAG));

  
  if ((TIMx->SR & TIM_FLAG) != (uint16_t)RESET)
  {
    bitstatus = SET;
  }
  else
  {
    bitstatus = RESET;
  }
  return bitstatus;
}
```

* 获取中断状态

```c
//获取当前中断发生状态
ITStatus TIM_GetITStatus(TIM_TypeDef* TIMx, uint16_t TIM_IT)
{
  ITStatus bitstatus = RESET;  
  uint16_t itstatus = 0x0, itenable = 0x0;
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
  assert_param(IS_TIM_GET_IT(TIM_IT));
   
  itstatus = TIMx->SR & TIM_IT;
  
  itenable = TIMx->DIER & TIM_IT;
  if ((itstatus != (uint16_t)RESET) && (itenable != (uint16_t)RESET))
  {
    bitstatus = SET;
  }
  else
  {
    bitstatus = RESET;
  }
  return bitstatus;
}
```

* 清空标志位/挂起标志位

```c
//清空中断标志位
void TIM_ClearFlag(TIM_TypeDef* TIMx, uint16_t TIM_FLAG)
{  
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));
   
  /* Clear the flags */
  TIMx->SR = (uint16_t)~TIM_FLAG;
}

//清空中断挂起标志位
void TIM_ClearITPendingBit(TIM_TypeDef* TIMx, uint16_t TIM_IT)
{
  /* Check the parameters */
  assert_param(IS_TIM_ALL_PERIPH(TIMx));

  /* Clear the IT pending Bit */
  TIMx->SR = (uint16_t)~TIM_IT;
}
```

* 使能/失能DMA请求

```c
//使能定时器DMA
void TIM_DMACmd(TIM_TypeDef* TIMx, uint16_t TIM_DMASource, FunctionalState NewState)
{ 
  /* Check the parameters */
  assert_param(IS_TIM_LIST5_PERIPH(TIMx)); 
  assert_param(IS_TIM_DMA_SOURCE(TIM_DMASource));
  assert_param(IS_FUNCTIONAL_STATE(NewState));
  
  if (NewState != DISABLE)
  {
    /* Enable the DMA sources */
    TIMx->DIER |= TIM_DMASource; 
  }
  else
  {
    /* Disable the DMA sources */
    TIMx->DIER &= (uint16_t)~TIM_DMASource;
  }
}
```

* 配置DMA突发传输模式（burst mode）

```c
//配置定时器DMA突发传输模式与相关设置
void TIM_DMAConfig(TIM_TypeDef* TIMx, uint16_t TIM_DMABase, uint16_t TIM_DMABurstLength)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_DMA_BASE(TIM_DMABase)); 
  assert_param(IS_TIM_DMA_LENGTH(TIM_DMABurstLength));

  /* Set the DMA Base and the DMA Burst Length */
  TIMx->DCR = TIM_DMABase | TIM_DMABurstLength;
}
```

* 选择捕获比较DMA请求

```c
//选择捕获比较DMA请求使能
void TIM_SelectCCDMA(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the CCDS Bit */
    TIMx->CR2 |= TIM_CR2_CCDS;
  }
  else
  {
    /* Reset the CCDS Bit */
    TIMx->CR2 &= (uint16_t)~TIM_CR2_CCDS;
  }
}
```

### 定时器时钟管理

这里是关于定时器时钟源的管理库函数

* 选择内部/外部时钟输入

```c
//配置定时器内部时钟
void TIM_InternalClockConfig(TIM_TypeDef* TIMx)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));

  /* Disable slave mode to clock the prescaler directly with the internal clock */
  TIMx->SMCR &=  (uint16_t)~TIM_SMCR_SMS;
}

//配置定时器内部触发作为外部时钟
//可选择TIM_TS_ITR0到3作为内部触发源
void TIM_ITRxExternalClockConfig(TIM_TypeDef* TIMx, uint16_t TIM_InputTriggerSource)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_TIM_INTERNAL_TRIGGER_SELECTION(TIM_InputTriggerSource));

  /* Select the Internal Trigger */
  TIM_SelectInputTrigger(TIMx, TIM_InputTriggerSource);

  /* Select the External clock mode1 */
  TIMx->SMCR |= TIM_SlaveMode_External1;
}

//配置定时器触发器作为外部时钟源
void TIM_TIxExternalClockConfig(TIM_TypeDef* TIMx, uint16_t TIM_TIxExternalCLKSource,
                                uint16_t TIM_ICPolarity, uint16_t ICFilter)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx));
  assert_param(IS_TIM_IC_POLARITY(TIM_ICPolarity));
  assert_param(IS_TIM_IC_FILTER(ICFilter));

  /* Configure the Timer Input Clock Source */
  if (TIM_TIxExternalCLKSource == TIM_TIxExternalCLK1Source_TI2)
  {
    TI2_Config(TIMx, TIM_ICPolarity, TIM_ICSelection_DirectTI, ICFilter);
  }
  else
  {
    TI1_Config(TIMx, TIM_ICPolarity, TIM_ICSelection_DirectTI, ICFilter);
  }
  /* Select the Trigger source */
  TIM_SelectInputTrigger(TIMx, TIM_TIxExternalCLKSource);
  /* Select the External clock mode1 */
  TIMx->SMCR |= TIM_SlaveMode_External1;
}
```

* 选择外部时钟模式为ETR（模式1/模式2）、TIx或ITRx

```c
//配置定时器ETR模式1
void TIM_ETRClockMode1Config(TIM_TypeDef* TIMx, uint16_t TIM_ExtTRGPrescaler,
                            uint16_t TIM_ExtTRGPolarity, uint16_t ExtTRGFilter)
{
  uint16_t tmpsmcr = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_EXT_PRESCALER(TIM_ExtTRGPrescaler));
  assert_param(IS_TIM_EXT_POLARITY(TIM_ExtTRGPolarity));
  assert_param(IS_TIM_EXT_FILTER(ExtTRGFilter));
  /* Configure the ETR Clock source */
  TIM_ETRConfig(TIMx, TIM_ExtTRGPrescaler, TIM_ExtTRGPolarity, ExtTRGFilter);
  
  /* Get the TIMx SMCR register value */
  tmpsmcr = TIMx->SMCR;

  /* Reset the SMS Bits */
  tmpsmcr &= (uint16_t)~TIM_SMCR_SMS;

  /* Select the External clock mode1 */
  tmpsmcr |= TIM_SlaveMode_External1;

  /* Select the Trigger selection : ETRF */
  tmpsmcr &= (uint16_t)~TIM_SMCR_TS;
  tmpsmcr |= TIM_TS_ETRF;

  /* Write to TIMx SMCR */
  TIMx->SMCR = tmpsmcr;
}

//配置ETR模式2
void TIM_ETRClockMode2Config(TIM_TypeDef* TIMx, uint16_t TIM_ExtTRGPrescaler, 
                             uint16_t TIM_ExtTRGPolarity, uint16_t ExtTRGFilter)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_EXT_PRESCALER(TIM_ExtTRGPrescaler));
  assert_param(IS_TIM_EXT_POLARITY(TIM_ExtTRGPolarity));
  assert_param(IS_TIM_EXT_FILTER(ExtTRGFilter));

  /* Configure the ETR Clock source */
  TIM_ETRConfig(TIMx, TIM_ExtTRGPrescaler, TIM_ExtTRGPolarity, ExtTRGFilter);

  /* Enable the External clock mode2 */
  TIMx->SMCR |= TIM_SMCR_ECE;
}
```

### 定时器同步管理

STM32中部分定时器可以实现同步功能，这里是相关的同步管理库函数

基本配置方法如下所示：

> 两个/多个定时器可进行串连、同步、交错等多种配置，需要以下步骤：
>
> 1. 使用下面的两个函数配置主定时器：
>    * TIM_SelectOutputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_TRGOSource)选择输出触发源
>    * TIM_SelectMasterSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_MasterSlaveMode)选择当前定时器模式为主从模式
> 2. 使用下面的函数配置从定时器：
>    * TIM_SelectInputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_InputTriggerSource)选择触发源输入
>    * TIM_SelectSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_SlaveMode)选择当前定时器模式为从模式
> 3. 这样从定时器就会被连接到主定时器的触发器，接收主定时器控制
> 4. 使用TIM_ETRConfig(TIM_TypeDef* TIMx, uint16_t TIM_ExtTRGPrescaler, uint16_t TIM_ExtTRGPolarity, uint16_t ExtTRGFilter)函数配置定时器的外部触发源，可实现由外部信号控制定时器
> 5. 配合TIM_SelectInputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_InputTriggerSource)与TIM_SelectSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_SlaveMode)函数，可以让定时器接收外部信号并作为从模式工作

* 选择输入触发信号

```c
void TIM_SelectInputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_InputTriggerSource)
{
  uint16_t tmpsmcr = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST1_PERIPH(TIMx)); 
  assert_param(IS_TIM_TRIGGER_SELECTION(TIM_InputTriggerSource));

  /* Get the TIMx SMCR register value */
  tmpsmcr = TIMx->SMCR;

  /* Reset the TS Bits */
  tmpsmcr &= (uint16_t)~TIM_SMCR_TS;

  /* Set the Input Trigger source */
  tmpsmcr |= TIM_InputTriggerSource;

  /* Write to TIMx SMCR */
  TIMx->SMCR = tmpsmcr;
}
```

* 选择输出触发信号

```c
void TIM_SelectOutputTrigger(TIM_TypeDef* TIMx, uint16_t TIM_TRGOSource)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST5_PERIPH(TIMx));
  assert_param(IS_TIM_TRGO_SOURCE(TIM_TRGOSource));

  /* Reset the MMS Bits */
  TIMx->CR2 &= (uint16_t)~TIM_CR2_MMS;
  /* Select the TRGO source */
  TIMx->CR2 |=  TIM_TRGOSource;
}
```

* 选择主从模式

```c
//设置定时器为从模式
void TIM_SelectSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_SlaveMode)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_TIM_SLAVE_MODE(TIM_SlaveMode));

  /* Reset the SMS Bits */
  TIMx->SMCR &= (uint16_t)~TIM_SMCR_SMS;

  /* Select the Slave Mode */
  TIMx->SMCR |= TIM_SlaveMode;
}

//设置定时器为主/从模式
void TIM_SelectMasterSlaveMode(TIM_TypeDef* TIMx, uint16_t TIM_MasterSlaveMode)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_TIM_MSM_STATE(TIM_MasterSlaveMode));

  /* Reset the MSM Bit */
  TIMx->SMCR &= (uint16_t)~TIM_SMCR_MSM;
  
  /* Set or Reset the MSM Bit */
  TIMx->SMCR |= TIM_MasterSlaveMode;
}
```

* 当作为外部触发使用时进行ETR配置

```c
//设置定时器外部触发模式（ETR）
void TIM_ETRConfig(TIM_TypeDef* TIMx, uint16_t TIM_ExtTRGPrescaler,
                   uint16_t TIM_ExtTRGPolarity, uint16_t ExtTRGFilter)
{
  uint16_t tmpsmcr = 0;

  /* Check the parameters */
  assert_param(IS_TIM_LIST3_PERIPH(TIMx));
  assert_param(IS_TIM_EXT_PRESCALER(TIM_ExtTRGPrescaler));
  assert_param(IS_TIM_EXT_POLARITY(TIM_ExtTRGPolarity));
  assert_param(IS_TIM_EXT_FILTER(ExtTRGFilter));

  tmpsmcr = TIMx->SMCR;

  /* Reset the ETR Bits */
  tmpsmcr &= SMCR_ETR_MASK;

  /* Set the Prescaler, the Filter value and the Polarity */
  tmpsmcr |= (uint16_t)(TIM_ExtTRGPrescaler | (uint16_t)(TIM_ExtTRGPolarity | (uint16_t)(ExtTRGFilter << (uint16_t)8)));

  /* Write to TIMx SMCR */
  TIMx->SMCR = tmpsmcr;
}
```

### 定时器特殊结构管理

定时器也可以作为特殊设备的接口使用，ST也提供了这样用法的库函数

* 解码器接口配置

```c
void TIM_EncoderInterfaceConfig(TIM_TypeDef* TIMx, uint16_t TIM_EncoderMode,
                                uint16_t TIM_IC1Polarity, uint16_t TIM_IC2Polarity)
{
  uint16_t tmpsmcr = 0;
  uint16_t tmpccmr1 = 0;
  uint16_t tmpccer = 0;
    
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_TIM_ENCODER_MODE(TIM_EncoderMode));
  assert_param(IS_TIM_IC_POLARITY(TIM_IC1Polarity));
  assert_param(IS_TIM_IC_POLARITY(TIM_IC2Polarity));

  /* Get the TIMx SMCR register value */
  tmpsmcr = TIMx->SMCR;

  /* Get the TIMx CCMR1 register value */
  tmpccmr1 = TIMx->CCMR1;

  /* Get the TIMx CCER register value */
  tmpccer = TIMx->CCER;

  /* Set the encoder Mode */
  tmpsmcr &= (uint16_t)~TIM_SMCR_SMS;
  tmpsmcr |= TIM_EncoderMode;

  /* Select the Capture Compare 1 and the Capture Compare 2 as input */
  tmpccmr1 &= ((uint16_t)~TIM_CCMR1_CC1S) & ((uint16_t)~TIM_CCMR1_CC2S);
  tmpccmr1 |= TIM_CCMR1_CC1S_0 | TIM_CCMR1_CC2S_0;

  /* Set the TI1 and the TI2 Polarities */
  tmpccer &= ((uint16_t)~TIM_CCER_CC1P) & ((uint16_t)~TIM_CCER_CC2P);
  tmpccer |= (uint16_t)(TIM_IC1Polarity | (uint16_t)(TIM_IC2Polarity << (uint16_t)4));

  /* Write to TIMx SMCR */
  TIMx->SMCR = tmpsmcr;

  /* Write to TIMx CCMR1 */
  TIMx->CCMR1 = tmpccmr1;

  /* Write to TIMx CCER */
  TIMx->CCER = tmpccer;
}
```

* 选择Hall Sensor

```c
void TIM_SelectHallSensor(TIM_TypeDef* TIMx, FunctionalState NewState)
{
  /* Check the parameters */
  assert_param(IS_TIM_LIST2_PERIPH(TIMx));
  assert_param(IS_FUNCTIONAL_STATE(NewState));

  if (NewState != DISABLE)
  {
    /* Set the TI1S Bit */
    TIMx->CR2 |= TIM_CR2_TI1S;
  }
  else
  {
    /* Reset the TI1S Bit */
    TIMx->CR2 &= (uint16_t)~TIM_CR2_TI1S;
  }
}
```

### 定时器特殊重映射配置

一些定时器能够被重映射为特殊的配置端口，这里是该功能的管理库函数

```c
//配置定时器重映射端口
void TIM_RemapConfig(TIM_TypeDef* TIMx, uint16_t TIM_Remap)
{
 /* Check the parameters */
  assert_param(IS_TIM_LIST6_PERIPH(TIMx));
  assert_param(IS_TIM_REMAP(TIM_Remap));

  /* Set the Timer remapping configuration */
  TIMx->OR =  TIM_Remap;
}

//配置TI1、2、3、4作为输入，这里仅列出TI1的库函数
static void TI1_Config(TIM_TypeDef* TIMx, uint16_t TIM_ICPolarity, uint16_t TIM_ICSelection,
                       uint16_t TIM_ICFilter)
{
  uint16_t tmpccmr1 = 0, tmpccer = 0;

  /* Disable the Channel 1: Reset the CC1E Bit */
  TIMx->CCER &= (uint16_t)~TIM_CCER_CC1E;
  tmpccmr1 = TIMx->CCMR1;
  tmpccer = TIMx->CCER;

  /* Select the Input and set the filter */
  tmpccmr1 &= ((uint16_t)~TIM_CCMR1_CC1S) & ((uint16_t)~TIM_CCMR1_IC1F);
  tmpccmr1 |= (uint16_t)(TIM_ICSelection | (uint16_t)(TIM_ICFilter << (uint16_t)4));

  /* Select the Polarity and set the CC1E Bit */
  tmpccer &= (uint16_t)~(TIM_CCER_CC1P | TIM_CCER_CC1NP);
  tmpccer |= (uint16_t)(TIM_ICPolarity | (uint16_t)TIM_CCER_CC1E);

  /* Write to TIMx CCMR1 and CCER registers */
  TIMx->CCMR1 = tmpccmr1;
  TIMx->CCER = tmpccer;
}
```