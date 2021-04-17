本文章根据stm32f4xx中文参考手册整理，可供学习其他arm内核单片机/stm32系列单片机参考

如果对其中的内容有疑问，可以参考RCC、定时器、中断相关部分的解析

以下内容使用SPL库（标准库）作为代码示例，HAL库是更高层的封装，想HAL库的使用可以查看其他教程

# GPIO电路

每个GPIO端口包括4个32位配置寄存器、2个32位数据寄存器、1个32位置位/复位寄存器、1个32位锁定寄存器和2个32位复用功能寄存器。每个IO端口位均可自由编程，但IO端口寄存器必须按32位字、半字或字节进行访问

基本电路图如下所示：

![image-20210415214054864](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210415214054864.png)

主要分为以下几个部分

## 输入电路

输入部分通过两个**保护二极管**进行钳位，保证GPIO容忍电压对V~SS~为5V，注意这里的V~SS~指的是电源地，而不是V~DD~信号地

输入信号经过可编程的**上拉/下拉电阻**后进入**输入驱动器**。

* 如果使能了ADC等接入外部模拟信号的片上外设，就能从GPIO直接读取模拟信号
* 如果使能了复用功能，外部信号则会通过一个TTL**施密特触发器**，直接缓冲进入相关数字信号外设
* 如果正常使用GPIO的读功能，外部信号会在被施密特触发器变为数字信号后进入**输入数据寄存器**

这里的施密特触发器相当于一个FIFO，能够保存外部模拟信号的快照，以此作为数字量供给片上外设

**引脚配置为输入模式后，输入数据寄存器会每1个AHB1时钟周期捕获以此GPIO外部数据**

## 输出电路

输出部分通过两个MOSFET控制，PMOS、NMOS以图腾柱方式组合，形成**推挽输出**结构。为了保证输出的速度，使用专用的驱动电路控制MOSFET，输出速率就由该驱动电路决定

* 如果正常使用GPIO的写功能，来自CPU的配置数据会先保存在**置位/复位寄存器**，之后转换保存在**输出数据寄存器**中，驱动电路根据输出数据寄存器的值实时控制输出，这就起到了内部时钟和外设操作频率的退耦
* 如果使用了其他能读写GPIO的外设，会由外设直接向输出数据寄存器中写值，这样就简轻了CPU的控制负担
* 如果使能了复用功能，来自复用外设的控制信号会直接绕过输出数据寄存器，直接通过一个两路选择器操作输出控制电路

所有来自MOSFET输出的信号会经过**上/下拉电路**，这就能将片内CMOS电压转换为片外TTL电压进行输出

同样输出也经过钳位二极管保护，防止出现电流倒灌等问题

**引脚配置为输出模式后，写入到输出数据寄存器的值会在GPIO上输出**

## 时序控制电路

大多数GPIO的寄存器都是基于时序电路实现（D触发器、锁存器等）

最重要的就是置位复位寄存器 (GPIOx_BSRR)：这是一个32位寄存器，它允许应用程序在输出数据寄存器(GPIOx_ODR) 中对各个单独的数据位执行置位和复位操作。

> 置位复位寄存器的大小是GPIOx_ODR的二倍，所以GPIOx_ODR中的每个数据位都能对应于GPIOx_BSRR中的两个控制位：BSRR(i) 和
> BSRR(i+SIZE)。当写入1时，BSRR(i)位会置位对应的ODR(i) 位；同时BSRR(i+SIZE) 位会清零ODR(i)对应的位；在GPIOx_BSRR中向任何位写入0都不会对GPIOx_ODR中的对应位产生任何影响。如果在GPIOx_BSRR中同时尝试对某个位执行置位和清零操作，则**置位操作优先**。
>
> 注意使用GPIOx_BSRR寄存器更改GPIOx_ODR中各个位的值是一个“单次”操作，不会锁定GPIOx_ODR位。用户随时都可以直接访问GPIOx_ODR位
>
> 特别地，对GPIOx_ODR进行位操作是原子操作，软件无需禁止中断，且在一次原子AHB1写访问中，可以修改一个或多个位

## GPIO复位

### 调试引脚复位

复位后调试引脚处于复位功能上拉/下拉状态：

* PA15-JTDI上拉
* PA14-JTCK/SWCLK下拉
* PA13-JTMS/SWDAT下拉
* PB4-NJTRST上拉
* PB3-JTDO浮空

### 其他复位

在复位期间及复位刚刚完成后，复用功能尚未激活，GPIO端口被配置为输入浮空模式

完成复位后，所有GPIO都会连接到系统的复用功能 0 (AF0)

# GPIO外设控制寄存器及配置

可通过字节（8 位）、半字（16 位）或字（32 位）对 GPIO 寄存器进行访问

**寄存器地址见参考手册**

GPIOx_MODER模式控制寄存器：选择 I/O 方向与模式

GPIOx_PUPDR上下拉数据寄存器：控制内部上拉/下拉电阻

GPIOx_OTYPER输出类型寄存器：选择输出类型

GPIOx_OSPEEDR输出速度寄存器：选择输出速度

GPIOx_IDR输入数据寄存器：通过 I/O 输入的数据存储到该寄存器，这是个只读寄存器

GPIOx_ODR输出数据寄存器：存储待输出数据，可对其进行读写访问

GPIOx_AFRL复用功能寄存器低8位：根据应用程序的要求将某个复用功能连接到其它某个引脚

GPIOx_AFRH复用功能寄存器高8位：根据应用程序的要求将某个复用功能连接到其它某个引脚

通过将特定的写序列应用到GPIOx_LCKR寄存器，可以冻结GPIO外设控制寄存器

## 配置输入

输入数据寄存器GPIOx_IDR是一个只读的寄存器，在使用时只要将GPIO通过GPIOx_MODER设置为输入模式后访问该寄存器就可以读取到当前采样值，输入数据寄存器会在每个时钟频率对外界信号进行一次采样

所有端口都具有外部中断功能。**要使用外部中断线，必须将端口配置为输入模式**

使用库函数配置如下：

```c
void PA4_PE0_Init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;//这里是stm32库定义的外设初始化结构体，在此进行“例化”
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA|RCC_AHB1Periph_GPIOE, ENABLE);//使能GPIOA,GPIOE时钟

	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_4;//配置P4
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IN;//配置为普通输入模式
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//速度设置为100M
	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_DOWN;//配置为内部下拉
    
	GPIO_Init(GPIOE, &GPIO_InitStructure);//初始化GPIOE4
	 
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0;//修改为Pin0
	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_DOWN;//内部下拉
    
	GPIO_Init(GPIOA, &GPIO_InitStructure);//初始化GPIOE0
} 
```

外部中断的配置可以参考【NVIC中断控制】相关文章，这里不列出

使用下面的函数读取GPIO输入值

```c
uint8_t GPIO_ReadInputDataBit(GPIO_TypeDef* GPIOx, uint16_t GPIO_Pin)
{
  	uint8_t bitstatus = 0x00;

  	/* Check the parameters */
  	assert_param(IS_GPIO_ALL_PERIPH(GPIOx));
  	assert_param(IS_GET_GPIO_PIN(GPIO_Pin));

  	if ((GPIOx->IDR & GPIO_Pin) != (uint32_t)Bit_RESET)
  	{
   	 	bitstatus = (uint8_t)Bit_SET;//通过读取判断寄存器的值来获取当前输入值
  	}
  	else
  	{
    	bitstatus = (uint8_t)Bit_RESET;
  	}
  	return bitstatus;
}
```

## 配置输出

输出数据寄存器 GPIOx_ODR

使用库函数配置如下：

```c
void PF9_Init(void)
{    	 
  	GPIO_InitTypeDef GPIO_InitStructure;
  	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOF, ENABLE);//使能GPIOF时钟

  	//GPIOF9初始化设置
  	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_9;//要配置的位是第9位
  	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_OUT;//普通输出模式
  	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出
  	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//速度配置位100MHz
  	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//配置上拉
    
  	GPIO_Init(GPIOF, &GPIO_InitStructure);//对GPIOF按照上面的配置进行初始化
	
    GPIO_SetBits(GPIOF,GPIO_Pin_9 | GPIO_Pin_10);//GPIOF9,F10设置高，灯灭
}
```

库函数的底层都是对寄存器的操作，摘录如下：

时钟控制库函数是对RCC寄存器进行操作

```c
void RCC_APB2PeriphClockCmd(uint32_t RCC_APB2Periph, FunctionalState NewState)
{
  	assert_param(IS_RCC_APB2_PERIPH(RCC_APB2Periph));//这里检查是否使用了正确的参数
  	assert_param(IS_FUNCTIONAL_STATE(NewState));

  	if (NewState != DISABLE)
  	{
    	RCC->APB2ENR |= RCC_APB2Periph;
        //参数设置为ENABLE时就使用上面提供的参数开启RCC寄存器下属APB2使能寄存器中的相关外设时钟控制位
  	}
  	else
  	{
    	RCC->APB2ENR &= ~RCC_APB2Periph;
        //否则关闭相对应的控制位
  	}
}
```

初始化结构体是对GPIO控制寄存器的封装

```c
typedef struct
{
  	uint32_t GPIO_Pin;
  	GPIOMode_TypeDef GPIO_Mode;
  	GPIOSpeed_TypeDef GPIO_Speed;
  	GPIOOType_TypeDef GPIO_OType;
  	GPIOPuPd_TypeDef GPIO_PuPd;
}GPIO_InitTypeDef;

typedef enum
{ 
  	GPIO_Mode_IN   = 0x00, /*!< GPIO Input Mode */
  	GPIO_Mode_OUT  = 0x01, /*!< GPIO Output Mode */
  	GPIO_Mode_AF   = 0x02, /*!< GPIO Alternate function Mode */
  	GPIO_Mode_AN   = 0x03  /*!< GPIO Analog Mode */
}GPIOMode_TypeDef;//对应GPIO_Mode的枚举量

typedef enum
{ 
  	GPIO_OType_PP = 0x00,
  	GPIO_OType_OD = 0x01
}GPIOOType_TypeDef;//对应GPIO_OType的枚举量

typedef enum
{ 
  	GPIO_Low_Speed     = 0x00, /*!< Low speed    */
  	GPIO_Medium_Speed  = 0x01, /*!< Medium speed */
  	GPIO_Fast_Speed    = 0x02, /*!< Fast speed   */
  	GPIO_High_Speed    = 0x03  /*!< High speed   */
}GPIOSpeed_TypeDef;//对应GPIO_Speed的枚举量

#define  GPIO_Speed_2MHz    GPIO_Low_Speed    
#define  GPIO_Speed_25MHz   GPIO_Medium_Speed 
#define  GPIO_Speed_50MHz   GPIO_Fast_Speed 
#define  GPIO_Speed_100MHz  GPIO_High_Speed
//再对枚举量封装一遍，便于直观设置GPIO速度

typedef enum
{ 
  	GPIO_PuPd_NOPULL = 0x00,
  	GPIO_PuPd_UP     = 0x01,
  	GPIO_PuPd_DOWN   = 0x02
}GPIOPuPd_TypeDef;
//对应GPIO_PuPd的枚举量
```

GPIO初始化函数如下：

```c
void GPIO_Init(GPIO_TypeDef* GPIOx, GPIO_InitTypeDef* GPIO_InitStruct)
{
  uint32_t pinpos = 0x00, pos = 0x00 , currentpin = 0x00;

  /* Check the parameters */
  assert_param(IS_GPIO_ALL_PERIPH(GPIOx));
  assert_param(IS_GPIO_PIN(GPIO_InitStruct->GPIO_Pin));
  assert_param(IS_GPIO_MODE(GPIO_InitStruct->GPIO_Mode));
  assert_param(IS_GPIO_PUPD(GPIO_InitStruct->GPIO_PuPd));
  
  	for (pinpos = 0x00; pinpos < 0x10; pinpos++)
  	{
    	pos = ((uint32_t)0x01) << pinpos;
    	//从参数获取GPIO引脚位
    	currentpin = (GPIO_InitStruct->GPIO_Pin) & pos;

    	if (currentpin == pos)
    	{
            //配置输入/输出模式参数
      		GPIOx->MODER  &= ~(GPIO_MODER_MODER0 << (pinpos * 2));
      		GPIOx->MODER |= (((uint32_t)GPIO_InitStruct->GPIO_Mode) << (pinpos * 2));

      //如果是输出或复用模式，则可以配置下面几个参数，否则在初始化结构体中无论怎么配置都不会生效
      if ((GPIO_InitStruct->GPIO_Mode == GPIO_Mode_OUT) || (GPIO_InitStruct->GPIO_Mode == GPIO_Mode_AF))
      {
        /* Check Speed mode parameters */
        assert_param(IS_GPIO_SPEED(GPIO_InitStruct->GPIO_Speed));

        //配置速度参数
        GPIOx->OSPEEDR &= ~(GPIO_OSPEEDER_OSPEEDR0 << (pinpos * 2));
        GPIOx->OSPEEDR |= ((uint32_t)(GPIO_InitStruct->GPIO_Speed) << (pinpos * 2));

        /* Check Output mode parameters */
        assert_param(IS_GPIO_OTYPE(GPIO_InitStruct->GPIO_OType));

        //配置输出方式参数
        GPIOx->OTYPER  &= ~((GPIO_OTYPER_OT_0) << ((uint16_t)pinpos)) ;
        GPIOx->OTYPER |= (uint16_t)(((uint16_t)GPIO_InitStruct->GPIO_OType) << ((uint16_t)pinpos));
      }

      	//上拉/下拉寄存器设置
      	GPIOx->PUPDR &= ~(GPIO_PUPDR_PUPDR0 << ((uint16_t)pinpos * 2));
      	GPIOx->PUPDR |= (((uint32_t)GPIO_InitStruct->GPIO_PuPd) << (pinpos * 2));
    	}
  	}
}
```

GPIO输出控制函数

```c
void GPIO_SetBits(GPIO_TypeDef* GPIOx, uint16_t GPIO_Pin)
{
  	/* Check the parameters */
  	assert_param(IS_GPIO_ALL_PERIPH(GPIOx));
  	assert_param(IS_GPIO_PIN(GPIO_Pin));

  	GPIOx->BSRRL = GPIO_Pin;//直接对GPIO引脚置位
}

void GPIO_ResetBits(GPIO_TypeDef* GPIOx, uint16_t GPIO_Pin)
{
  	/* Check the parameters */
  	assert_param(IS_GPIO_ALL_PERIPH(GPIOx));
  	assert_param(IS_GPIO_PIN(GPIO_Pin));

  	GPIOx->BSRRH = GPIO_Pin;
}

void GPIO_WriteBit(GPIO_TypeDef* GPIOx, uint16_t GPIO_Pin, BitAction BitVal)
{
  	/* Check the parameters */
  	assert_param(IS_GPIO_ALL_PERIPH(GPIOx));
  	assert_param(IS_GET_GPIO_PIN(GPIO_Pin));
  	assert_param(IS_GPIO_BIT_ACTION(BitVal));

  	if (BitVal != Bit_RESET)
  	{
    	GPIOx->BSRRL = GPIO_Pin;
  	}
  	else
  	{
    	GPIOx->BSRRH = GPIO_Pin ;
  	}
}

typedef enum
{ 
  	Bit_RESET = 0,
  	Bit_SET
}BitAction;
//对应BitVal的枚举量

//还有一个比较方便的翻转输出值函数
void GPIO_ToggleBits(GPIO_TypeDef* GPIOx, uint16_t GPIO_Pin)
{
  	/* Check the parameters */
  	assert_param(IS_GPIO_ALL_PERIPH(GPIOx));

  	GPIOx->ODR ^= GPIO_Pin;//异或运算，如果和之前的值相同，则反转；可以通过多次使用该函数反转输出
}

//很莽的一个函数，直接设置GPIO端口值
void GPIO_Write(GPIO_TypeDef* GPIOx, uint16_t PortVal)
{
  	/* Check the parameters */
  	assert_param(IS_GPIO_ALL_PERIPH(GPIOx));

  	GPIOx->ODR = PortVal;
}
```

### 开漏模式与推挽模式

开漏模式：输出寄存器中置0位可激活连接到V~SS~的N-MOS，而输出寄存器中置1会使端口保持高阻态z，连接到V~DD~的P-MOS始终不会开启，也就是说配置寄存器只会控制GPIO的开漏
推挽模式：输出寄存器中置0位可激活N-MOS，而输出寄存器中置1可激活P-MOS，达到推挽输出的效果

## 模拟配置

一下内容摘自参考手册原文

> 对 I/O 端口进行编程作为模拟配置时
>
> ● 输出缓冲器被禁止
>
> ● 施密特触发器输入停用，I/O 引脚的每个模拟输入的功耗变为零。施密特触发器的输出被强制处理为恒定值 (0)
>
> ● 弱上拉和下拉电阻被关闭
>
> ● 对输入数据寄存器的读访问值为“0”

注意：**在模拟配置中，I/O引脚不能为5V容忍**

## 振荡器引脚和RTC引脚作为GPIO

当LSE振荡器处于关闭状态时，可分别将LSE引脚OSC32_IN和OSC32_OUT用作普通的PC14和PC15引脚

但当LSE开启时，两个引脚只能作为LSE引脚，LSE的优先级是高于GPIO配置的，所以程序中对这两个引脚的GPIO配置会被无效

当HSE振荡器处于关闭状态时，可分别将HSE振荡器引脚OSC_IN和OSC_OUT用作PH0和PH1引脚

但当HSE振荡器处于开启状态时，PH0/PH1只能被配置为OSC_IN/OSC_OUT HSE振荡器引脚，也是优先于GPIO配置

另外还有RTC_AF1和RTC_AF2两个引脚，可以用来检测入侵或时间戳时间、RTC_ALARM或RTC_CALIB RTC输出

设置为RTC_ALARM输出时可用于两个RTC输出或RTC的唤醒，有RTC_CR寄存器中的OSEL[1:0]位配置

其他功能查看参数手册即可

## 锁定GPIO

在库函数中提供了锁定GPIO的函数，摘录如下

```c
void GPIO_PinLockConfig(GPIO_TypeDef* GPIOx, uint16_t GPIO_Pin)
{
  __IO uint32_t tmp = 0x00010000;

  /* Check the parameters */
  assert_param(IS_GPIO_ALL_PERIPH(GPIOx));
  assert_param(IS_GPIO_PIN(GPIO_Pin));

  tmp |= GPIO_Pin;
  /* Set LCKK bit */
  GPIOx->LCKR = tmp;
  /* Reset LCKK bit */
  GPIOx->LCKR =  GPIO_Pin;
  /* Set LCKK bit */
  GPIOx->LCKR = tmp;
  /* Read LCKK bit*/
  tmp = GPIOx->LCKR;
  /* Read LCKK bit*/
  tmp = GPIOx->LCKR;
}
```

直接输入GPIOx和要锁定的引脚就可以进行锁定

# GPIO复用

## GPIO复用器

**每个GPIO引脚都有一个采用16路复用功能输入的复用器**，GPIO通过这些复用器连接到片上外设，这个复用器一次仅允许一个外设的复用功能连接到GPIO引脚，确保共用同一个GPIO引脚的外设之间不会发生冲突

复用器输入从AF0到AF15，通过引脚复用寄存器的低8位GPIOx_AFRL和高8位GPIOx_AFRH分别设置

外设的复用功能映射到AF1至AF13，AF0是悬空状态，AF15则是系统的EVENTOUT接入

### EVENTOUT

参考ARM内核部分内容

## GPIO复用输入输出

在库函数中使用以下方式设置GPIO连接到复用器

```c
GPIO_PinAFConfig(GPIOF,GPIO_PinSource9,GPIO_AF_TIM14);//GPIOF9通过复用器连接到定时器14
GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;//在初始化结构体中配置为复用
//开启GPIO时钟同时也要开启所要复用外设的时钟
//不要忘记使能外设
//GPIO的其他功能按照正常配置即可
```

复用功能设置库函数

```c
void GPIO_PinAFConfig(GPIO_TypeDef* GPIOx, uint16_t GPIO_PinSource, uint8_t GPIO_AF)
{
  	uint32_t temp = 0x00;
  	uint32_t temp_2 = 0x00;
  
  	/* Check the parameters */
  	assert_param(IS_GPIO_ALL_PERIPH(GPIOx));
  	assert_param(IS_GPIO_PIN_SOURCE(GPIO_PinSource));
  	assert_param(IS_GPIO_AF(GPIO_AF));
  
  	temp = ((uint32_t)(GPIO_AF) << ((uint32_t)((uint32_t)GPIO_PinSource & (uint32_t)0x07) * 4)) ;
  	GPIOx->AFR[GPIO_PinSource >> 0x03] &= ~((uint32_t)0xF << ((uint32_t)((uint32_t)GPIO_PinSource & (uint32_t)0x07) * 4)) ;
    //设置复用寄存器
    
  	temp_2 = GPIOx->AFR[GPIO_PinSource >> 0x03] | temp;
  	GPIOx->AFR[GPIO_PinSource >> 0x03] = temp_2;
}
```

在库函数中提供的参考表

```c
/* GPIO_AFSelection: 选择被用于复用的引脚
  *          This parameter can be one of the following values:
  *            @arg GPIO_AF_RTC_50Hz: Connect RTC_50Hz pin to AF0 (default after reset) 
  *            @arg GPIO_AF_MCO: Connect MCO pin (MCO1 and MCO2) to AF0 (default after reset) 
  *            @arg GPIO_AF_TAMPER: Connect TAMPER pins (TAMPER_1 and TAMPER_2) to AF0 (default after reset) 
  *            @arg GPIO_AF_SWJ: Connect SWJ pins (SWD and JTAG)to AF0 (default after reset) 
  *            @arg GPIO_AF_TRACE: Connect TRACE pins to AF0 (default after reset)
  *            @arg GPIO_AF_TIM1: Connect TIM1 pins to AF1
  *            @arg GPIO_AF_TIM2: Connect TIM2 pins to AF1
  *            @arg GPIO_AF_TIM3: Connect TIM3 pins to AF2
  *            @arg GPIO_AF_TIM4: Connect TIM4 pins to AF2
  *            @arg GPIO_AF_TIM5: Connect TIM5 pins to AF2
  *            @arg GPIO_AF_TIM8: Connect TIM8 pins to AF3
  *            @arg GPIO_AF_TIM9: Connect TIM9 pins to AF3
  *            @arg GPIO_AF_TIM10: Connect TIM10 pins to AF3
  *            @arg GPIO_AF_TIM11: Connect TIM11 pins to AF3
  *            @arg GPIO_AF_I2C1: Connect I2C1 pins to AF4
  *            @arg GPIO_AF_I2C2: Connect I2C2 pins to AF4
  *            @arg GPIO_AF_I2C3: Connect I2C3 pins to AF4
  *            @arg GPIO_AF_SPI1: Connect SPI1 pins to AF5
  *            @arg GPIO_AF_SPI2: Connect SPI2/I2S2 pins to AF5
  *            @arg GPIO_AF_SPI4: Connect SPI4 pins to AF5 
  *            @arg GPIO_AF_SPI5: Connect SPI5 pins to AF5 
  *            @arg GPIO_AF_SPI6: Connect SPI6 pins to AF5
  *            @arg GPIO_AF_SAI1: Connect SAI1 pins to AF6 for STM32F42xxx/43xxx devices.       
  *            @arg GPIO_AF_SPI3: Connect SPI3/I2S3 pins to AF6
  *            @arg GPIO_AF_I2S3ext: Connect I2S3ext pins to AF7
  *            @arg GPIO_AF_USART1: Connect USART1 pins to AF7
  *            @arg GPIO_AF_USART2: Connect USART2 pins to AF7
  *            @arg GPIO_AF_USART3: Connect USART3 pins to AF7
  *            @arg GPIO_AF_UART4: Connect UART4 pins to AF8
  *            @arg GPIO_AF_UART5: Connect UART5 pins to AF8
  *            @arg GPIO_AF_USART6: Connect USART6 pins to AF8
  *            @arg GPIO_AF_UART7: Connect UART7 pins to AF8
  *            @arg GPIO_AF_UART8: Connect UART8 pins to AF8
  *            @arg GPIO_AF_CAN1: Connect CAN1 pins to AF9
  *            @arg GPIO_AF_CAN2: Connect CAN2 pins to AF9
  *            @arg GPIO_AF_TIM12: Connect TIM12 pins to AF9
  *            @arg GPIO_AF_TIM13: Connect TIM13 pins to AF9
  *            @arg GPIO_AF_TIM14: Connect TIM14 pins to AF9
  *            @arg GPIO_AF_OTG_FS: Connect OTG_FS pins to AF10
  *            @arg GPIO_AF_OTG_HS: Connect OTG_HS pins to AF10
  *            @arg GPIO_AF_ETH: Connect ETHERNET pins to AF11
  *            @arg GPIO_AF_FSMC: Connect FSMC pins to AF12 
  *            @arg GPIO_AF_FMC: Connect FMC pins to AF12 for STM32F42xxx/43xxx devices.   
  *            @arg GPIO_AF_OTG_HS_FS: Connect OTG HS (configured in FS) pins to AF12
  *            @arg GPIO_AF_SDIO: Connect SDIO pins to AF12
  *            @arg GPIO_AF_DCMI: Connect DCMI pins to AF13
  *            @arg GPIO_AF_LTDC: Connect LTDC pins to AF14 for STM32F429xx/439xx devices. 
  *            @arg GPIO_AF_EVENTOUT: Connect EVENTOUT pins to AF15
*/
```

# 使用GPIO的步骤

1. 系统功能

   复位后GPIO自动连接AF0，然后会根据寄存器配置进行初始化，在这个阶段会进行JTAG/SWD、RTC参考输入、MCO1、MCO2等系统功能的引脚初始化

2. GPIO输入输出配置

   在GPIOx_MODER寄存器中将所需 I/O 配置为输出或输入即可进行独立的输入输出

   注意需要打开GPIO时钟！

3. 外设复用使能

   对于ADC和DAC，需要在GPIOx_MODER寄存器中将所需 I/O 配置为模拟输入/输出

   对其他外设则需要在GPIOx_MODER寄存器中使能复用

4. 其他选项

   通过GPIOx_OTYPER、GPIOx_PUPDR和GPIOx_OSPEEDER寄存器，分别选择类型、上拉/下拉以及输出速度

   在GPIOx_AFRL或GPIOx_AFRH寄存器中选择连接的具体复用外设

   外设能复用的GPIO是唯一的，应该使用CubeMX或查阅芯片参考手册来设置

5. 配置EVENTOUT

   通过将复用器连接到AF15来配置用于输出Cortex-M4内核EVENTOUT信号的GPIO引脚

   注意：对于stm32f407，EVENTOUT不会映射到PC13、PC14、PC15、PH0、PH1、PI8引脚