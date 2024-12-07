# 辅助文件

## sys.h

直接ctrl c+ctrl v自正点原子

```c
#ifndef __SYS_H
#define __SYS_H	 
#include "stm32f4xx.h"

//0,不支持ucos
//1,支持ucos
#define SYSTEM_SUPPORT_OS		0		//定义系统文件夹是否支持UCOS
	 
//位带操作,实现51类似的GPIO控制功能
//具体实现思想,参考<<CM3权威指南>>第五章(87页~92页).M4同M3类似,只是寄存器地址变了.
//IO口操作宏定义
#define BITBAND(addr, bitnum) ((addr & 0xF0000000)+0x2000000+((addr &0xFFFFF)<<5)+(bitnum<<2)) 
#define MEM_ADDR(addr)  *((volatile unsigned long  *)(addr)) 
#define BIT_ADDR(addr, bitnum)   MEM_ADDR(BITBAND(addr, bitnum)) 
//IO口地址映射
#define GPIOA_ODR_Addr    (GPIOA_BASE+20) //0x40020014
#define GPIOB_ODR_Addr    (GPIOB_BASE+20) //0x40020414 
#define GPIOC_ODR_Addr    (GPIOC_BASE+20) //0x40020814 
#define GPIOD_ODR_Addr    (GPIOD_BASE+20) //0x40020C14 
#define GPIOE_ODR_Addr    (GPIOE_BASE+20) //0x40021014 
#define GPIOF_ODR_Addr    (GPIOF_BASE+20) //0x40021414    
#define GPIOG_ODR_Addr    (GPIOG_BASE+20) //0x40021814   
#define GPIOH_ODR_Addr    (GPIOH_BASE+20) //0x40021C14    
#define GPIOI_ODR_Addr    (GPIOI_BASE+20) //0x40022014     

#define GPIOA_IDR_Addr    (GPIOA_BASE+16) //0x40020010 
#define GPIOB_IDR_Addr    (GPIOB_BASE+16) //0x40020410 
#define GPIOC_IDR_Addr    (GPIOC_BASE+16) //0x40020810 
#define GPIOD_IDR_Addr    (GPIOD_BASE+16) //0x40020C10 
#define GPIOE_IDR_Addr    (GPIOE_BASE+16) //0x40021010 
#define GPIOF_IDR_Addr    (GPIOF_BASE+16) //0x40021410 
#define GPIOG_IDR_Addr    (GPIOG_BASE+16) //0x40021810 
#define GPIOH_IDR_Addr    (GPIOH_BASE+16) //0x40021C10 
#define GPIOI_IDR_Addr    (GPIOI_BASE+16) //0x40022010 
 
//IO口操作,只对单一的IO口!
//确保n的值小于16!
#define PAout(n)   BIT_ADDR(GPIOA_ODR_Addr,n)  //输出 
#define PAin(n)    BIT_ADDR(GPIOA_IDR_Addr,n)  //输入 

#define PBout(n)   BIT_ADDR(GPIOB_ODR_Addr,n)  //输出 
#define PBin(n)    BIT_ADDR(GPIOB_IDR_Addr,n)  //输入 

#define PCout(n)   BIT_ADDR(GPIOC_ODR_Addr,n)  //输出 
#define PCin(n)    BIT_ADDR(GPIOC_IDR_Addr,n)  //输入 

#define PDout(n)   BIT_ADDR(GPIOD_ODR_Addr,n)  //输出 
#define PDin(n)    BIT_ADDR(GPIOD_IDR_Addr,n)  //输入 

#define PEout(n)   BIT_ADDR(GPIOE_ODR_Addr,n)  //输出 
#define PEin(n)    BIT_ADDR(GPIOE_IDR_Addr,n)  //输入

#define PFout(n)   BIT_ADDR(GPIOF_ODR_Addr,n)  //输出 
#define PFin(n)    BIT_ADDR(GPIOF_IDR_Addr,n)  //输入

#define PGout(n)   BIT_ADDR(GPIOG_ODR_Addr,n)  //输出 
#define PGin(n)    BIT_ADDR(GPIOG_IDR_Addr,n)  //输入

#define PHout(n)   BIT_ADDR(GPIOH_ODR_Addr,n)  //输出 
#define PHin(n)    BIT_ADDR(GPIOH_IDR_Addr,n)  //输入

#define PIout(n)   BIT_ADDR(GPIOI_ODR_Addr,n)  //输出 
#define PIin(n)    BIT_ADDR(GPIOI_IDR_Addr,n)  //输入

//以下为汇编函数
void WFI_SET(void);		//执行WFI指令
void INTX_DISABLE(void);//关闭所有中断
void INTX_ENABLE(void);	//开启所有中断
void MSR_MSP(u32 addr);	//设置堆栈地址 
#endif
```

## SystemInit()函数

用于初始化系统时钟

```c
void SystemInit(void)
{
  /* FPU设置 ------------------------------------------------------------*/
  #if (__FPU_PRESENT == 1) && (__FPU_USED == 1)
    SCB->CPACR |= ((3UL << 10*2)|(3UL << 11*2));  /* set CP10 and CP11 Full Access */
  #endif
  /* 复位RCC ------------*/
  /* Set HSION bit */
  RCC->CR |= (uint32_t)0x00000001;//控制HSI

  /* Reset CFGR register */
  RCC->CFGR = 0x00000000;//控制CLKCFG

  /* Reset HSEON, CSSON and PLLON bits */
  RCC->CR &= (uint32_t)0xFEF6FFFF;//控制HSE、CSS、PLL

  /* Reset PLLCFGR register */
  RCC->PLLCFGR = 0x24003010;//控制PLLCFG

  /* Reset HSEBYP bit */
  RCC->CR &= (uint32_t)0xFFFBFFFF;//控制HSE

  /* 关闭中断 */
  RCC->CIR = 0x00000000;

#if defined (DATA_IN_ExtSRAM) || defined (DATA_IN_ExtSDRAM)
  SystemInit_ExtMemCtl(); 
#endif /* DATA_IN_ExtSRAM || DATA_IN_ExtSDRAM */
         
  /* 设置系统时钟源、PLL倍频/分频器、AHB/APBx分频器和FLASH ----------------------------------*/
  SetSysClock();

  /* 设置向量表地址和偏移地址 ------------------*/
#ifdef VECT_TAB_SRAM
  SCB->VTOR = SRAM_BASE | VECT_TAB_OFFSET; /* 重定位向量表到片上SRAM */
#else
  SCB->VTOR = FLASH_BASE | VECT_TAB_OFFSET; /* 重定位向量表到片上FLASH */
#endif
}
```

## SetSysClock()函数

用于设置系统时钟

```c
static void SetSysClock(void)
{
#if defined (STM32F40_41xxx) || defined (STM32F427_437xx) || defined (STM32F429_439xx) || defined (STM32F401xx)
/******************************************************************************/
/*            PLL (clocked by HSE) used as System clock source                */
/******************************************************************************/
  __IO uint32_t StartUpCounter = 0, HSEStatus = 0;
  
  /* 使能HSE */
  RCC->CR |= ((uint32_t)RCC_CR_HSEON);
 
  /* 等待HSE就绪，若超时则退出并复位 */
  do
  {
    HSEStatus = RCC->CR & RCC_CR_HSERDY;
    StartUpCounter++;
  } while((HSEStatus == 0) && (StartUpCounter != HSE_STARTUP_TIMEOUT));

  if ((RCC->CR & RCC_CR_HSERDY) != RESET)
  {
    HSEStatus = (uint32_t)0x01;
  }
  else
  {
    HSEStatus = (uint32_t)0x00;
  }

  if (HSEStatus == (uint32_t)0x01)
  {
    /* 选择电源模式 */
    RCC->APB1ENR |= RCC_APB1ENR_PWREN;
    PWR->CR |= PWR_CR_VOS;

    /* HCLK = SYSCLK */
    RCC->CFGR |= RCC_CFGR_HPRE_DIV1;

#if defined (STM32F40_41xxx) || defined (STM32F427_437xx) || defined (STM32F429_439xx)      
    /* PCLK2 = HCLK/2 */
    RCC->CFGR |= RCC_CFGR_PPRE2_DIV2;
    
    /* PCLK1 = HCLK/4 */
    RCC->CFGR |= RCC_CFGR_PPRE1_DIV4;
#endif /* STM32F40_41xxx || STM32F427_437x || STM32F429_439xx */

#if defined (STM32F401xx)
    /* PCLK2 = HCLK/2 */
    RCC->CFGR |= RCC_CFGR_PPRE2_DIV1;
    
    /* PCLK1 = HCLK/4 */
    RCC->CFGR |= RCC_CFGR_PPRE1_DIV2;
#endif /* 如果是STM32F401系列 */
   
    /* 设置主PLL */
    RCC->PLLCFGR = PLL_M | (PLL_N << 6) | (((PLL_P >> 1) -1) << 16) |
                   (RCC_PLLCFGR_PLLSRC_HSE) | (PLL_Q << 24);

    /* 使能主PLL */
    RCC->CR |= RCC_CR_PLLON;

    /* 等待主PLL就绪 */
    while((RCC->CR & RCC_CR_PLLRDY) == 0)
    {
    }
   
#if defined (STM32F427_437xx) || defined (STM32F429_439xx)//f4的高性能设备
    /* 一！键！超！频！ 频率直达180MHz */
    PWR->CR |= PWR_CR_ODEN;
    while((PWR->CSR & PWR_CSR_ODRDY) == 0)
    {
    }
    PWR->CR |= PWR_CR_ODSWEN;
    while((PWR->CSR & PWR_CSR_ODSWRDY) == 0)
    {
    }      
    /* 配置FLASH预取指、指令缓存、数据缓存 和 等待状态 */
    FLASH->ACR = FLASH_ACR_PRFTEN | FLASH_ACR_ICEN |FLASH_ACR_DCEN |FLASH_ACR_LATENCY_5WS;
#endif /* STM32F427_437x || STM32F429_439xx  */

#if defined (STM32F40_41xxx)     
    /* 配置FLASH预取指、指令缓存、数据缓存 和 等待状态 */
    FLASH->ACR = FLASH_ACR_PRFTEN | FLASH_ACR_ICEN |FLASH_ACR_DCEN |FLASH_ACR_LATENCY_5WS;
#endif /* STM32F40_41xxx  */

#if defined (STM32F401xx)
    /* 配置FLASH预取指、指令缓存、数据缓存 和 等待状态 */
    FLASH->ACR = FLASH_ACR_PRFTEN | FLASH_ACR_ICEN |FLASH_ACR_DCEN |FLASH_ACR_LATENCY_2WS;
#endif /* STM32F401xx */

    /* 选择主PLL作为SYSCLK时钟源 */
    RCC->CFGR &= (uint32_t)((uint32_t)~(RCC_CFGR_SW));
    RCC->CFGR |= RCC_CFGR_SW_PLL;

    /* 等待主PLL配置就绪 */
    while ((RCC->CFGR & (uint32_t)RCC_CFGR_SWS ) != RCC_CFGR_SWS_PLL);
    {
    }
  }
  else
  {
      /* 如果HSE启动出错，应用会进行错误的时钟配置，用户在这里添加解决出错情况的代码 */
  }
    
    
//下面的内容和上面大同小异
    
    
#elif defined (STM32F411xE)
#if defined (USE_HSE_BYPASS) 
/******************************************************************************/
/*            PLL (clocked by HSE) used as System clock source                */
/******************************************************************************/
  __IO uint32_t StartUpCounter = 0, HSEStatus = 0;
  
  /* Enable HSE and HSE BYPASS */
  RCC->CR |= ((uint32_t)RCC_CR_HSEON | RCC_CR_HSEBYP);
 
  /* Wait till HSE is ready and if Time out is reached exit */
  do
  {
    HSEStatus = RCC->CR & RCC_CR_HSERDY;
    StartUpCounter++;
  } while((HSEStatus == 0) && (StartUpCounter != HSE_STARTUP_TIMEOUT));

  if ((RCC->CR & RCC_CR_HSERDY) != RESET)
  {
    HSEStatus = (uint32_t)0x01;
  }
  else
  {
    HSEStatus = (uint32_t)0x00;
  }

  if (HSEStatus == (uint32_t)0x01)
  {
    /* Select regulator voltage output Scale 1 mode */
    RCC->APB1ENR |= RCC_APB1ENR_PWREN;
    PWR->CR |= PWR_CR_VOS;

    /* HCLK = SYSCLK / 1*/
    RCC->CFGR |= RCC_CFGR_HPRE_DIV1;

    /* PCLK2 = HCLK / 2*/
    RCC->CFGR |= RCC_CFGR_PPRE2_DIV1;
    
    /* PCLK1 = HCLK / 4*/
    RCC->CFGR |= RCC_CFGR_PPRE1_DIV2;

    /* Configure the main PLL */
    RCC->PLLCFGR = PLL_M | (PLL_N << 6) | (((PLL_P >> 1) -1) << 16) |
                   (RCC_PLLCFGR_PLLSRC_HSE) | (PLL_Q << 24);
    
    /* Enable the main PLL */
    RCC->CR |= RCC_CR_PLLON;

    /* Wait till the main PLL is ready */
    while((RCC->CR & RCC_CR_PLLRDY) == 0)
    {
    }

    /* Configure Flash prefetch, Instruction cache, Data cache and wait state */
    FLASH->ACR = FLASH_ACR_PRFTEN | FLASH_ACR_ICEN |FLASH_ACR_DCEN |FLASH_ACR_LATENCY_2WS;

    /* Select the main PLL as system clock source */
    RCC->CFGR &= (uint32_t)((uint32_t)~(RCC_CFGR_SW));
    RCC->CFGR |= RCC_CFGR_SW_PLL;

    /* Wait till the main PLL is used as system clock source */
    while ((RCC->CFGR & (uint32_t)RCC_CFGR_SWS ) != RCC_CFGR_SWS_PLL);
    {
    }
  }
  else
  { /* If HSE fails to start-up, the application will have wrong clock
         configuration. User can add here some code to deal with this error */
  }
#else /* HSI will be used as PLL clock source */
  /* Select regulator voltage output Scale 1 mode */
  RCC->APB1ENR |= RCC_APB1ENR_PWREN;
  PWR->CR |= PWR_CR_VOS;
  
  /* HCLK = SYSCLK / 1*/
  RCC->CFGR |= RCC_CFGR_HPRE_DIV1;
  
  /* PCLK2 = HCLK / 2*/
  RCC->CFGR |= RCC_CFGR_PPRE2_DIV1;
  
  /* PCLK1 = HCLK / 4*/
  RCC->CFGR |= RCC_CFGR_PPRE1_DIV2;
  
  /* Configure the main PLL */
  RCC->PLLCFGR = PLL_M | (PLL_N << 6) | (((PLL_P >> 1) -1) << 16) | (PLL_Q << 24); 
  
  /* Enable the main PLL */
  RCC->CR |= RCC_CR_PLLON;
  
  /* Wait till the main PLL is ready */
  while((RCC->CR & RCC_CR_PLLRDY) == 0)
  {
  }
  
  /* Configure Flash prefetch, Instruction cache, Data cache and wait state */
  FLASH->ACR = FLASH_ACR_PRFTEN | FLASH_ACR_ICEN |FLASH_ACR_DCEN |FLASH_ACR_LATENCY_2WS;
  
  /* Select the main PLL as system clock source */
  RCC->CFGR &= (uint32_t)((uint32_t)~(RCC_CFGR_SW));
  RCC->CFGR |= RCC_CFGR_SW_PLL;
  
  /* Wait till the main PLL is used as system clock source */
  while ((RCC->CFGR & (uint32_t)RCC_CFGR_SWS ) != RCC_CFGR_SWS_PLL);
  {
  }
#endif /* USE_HSE_BYPASS */  
#endif /* STM32F40_41xxx || STM32F427_437xx || STM32F429_439xx || STM32F401xx */  
}
```

# 外设配置速查

## GPIO

1. gpio.c

```c
#include "led.h" 

//初始化PF9和PF10为输出口.并使能这两个口的时钟
void GPIO_LED_Init(void)//GPIO初始化函数定义
{    	 
    //1. 定义GPIO设定结构体
    GPIO_InitTypeDef  GPIO_InitStructure;
    
	//2. 使能GPIOF时钟
    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOF, ENABLE);

    //GPIO初始化设置
    GPIO_InitStructure.GPIO_Pin = GPIO_Pin_9 | GPIO_Pin_10;//设定初始化的IO口
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_OUT;//普通输出模式
    GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出模式
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//100MHz
    GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//内部上拉
    //应用GPIO配置
    GPIO_Init(GPIOF, &GPIO_InitStructure);
	
	GPIO_SetBits(GPIOF,GPIO_Pin_9 | GPIO_Pin_10);//设置GPIOF9,F10初态（开机状态）
}
```

2. gpio.h

```c
#ifndef __GPIO_H
	#define __GPIO_H
	#include "sys.h"

	//GPIO端口定义
	#define LED0 PFout(9)	// DS0
	#define LED1 PFout(10)	// DS1	

	//GPIO初始化函数声明
	void GPIO_LED_Init(void);
#endif
```

2. main.c

```c
#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "gpio.h"

/*通过 库函数 操作实现IO口控制*/
int main(void)
{ 
    //初始化延时函数
	delay_init(168);
    
    //调用GPIO初始化函数
	GPIO_LED_Init();
	
	while(1)
	{
	GPIO_ResetBits(GPIOF,GPIO_Pin_9);//LED0对应引脚GPIOF.9拉低，亮  等同LED0=0;
	GPIO_SetBits(GPIOF,GPIO_Pin_10);//LED1对应引脚GPIOF.10拉高，灭 等同LED1=1;
	delay_ms(500);//延时
	GPIO_SetBits(GPIOF,GPIO_Pin_9);//LED0对应引脚GPIOF.0拉高，灭  等同LED0=1;
	GPIO_ResetBits(GPIOF,GPIO_Pin_10);//LED1对应引脚GPIOF.10拉低，亮 等同LED1=0;
	delay_ms(500);//延时
	}
}

/*通过 位带 操作实现IO口控制*/
int main(void)
{ 
    //初始化延时函数
	delay_init(168);
    
    //调用GPIO初始化函数
	GPIO_LED_Init();
    
  	while(1)
	{
    /*参见之前的GPIO端口定义
	#define LED0 PFout(9)	// DS0
	#define LED1 PFout(10)	// DS1
	*/
        LED0=0;//LED0亮
	   	LED1=1;//LED1灭
		delay_ms(500);
		LED0=1;//LED0灭
		LED1=0;//LED1亮
		delay_ms(500);
    }
}

/*通过 直接操作寄存器 方式实现IO口控制*/
int main(void)
{ 
 	//初始化延时函数
	delay_init(168);
    
    //调用GPIO初始化函数
	GPIO_LED_Init();
    
	while(1)
	{
     	GPIOF->BSRRH=GPIO_Pin_9;//LED0亮
	   	GPIOF->BSRRL=GPIO_Pin_10;//LED1灭
		delay_ms(500);
     	GPIOF->BSRRL=GPIO_Pin_9;//LED0灭
	  	GPIOF->BSRRH=GPIO_Pin_10;//LED1亮
		delay_ms(500);
	 }
 }	 
```

## 延时定时器

delay.c

```c
/*不用ucos时*/

//延时nus
//nus为要延时的us数.	
//注意:nus的值,不要大于798915us(最大值即2^24/fac_us@fac_us=21)
void delay_us(u32 nus)
{		
	u32 temp;	    	 
    
	SysTick->LOAD=nus*fac_us; 				//时间加载	  		 
	SysTick->VAL=0x00;        				//清空计数器
	SysTick->CTRL|=SysTick_CTRL_ENABLE_Msk ; //开始倒数 	
    
	do
	{
		temp=SysTick->CTRL;
	}while((temp&0x01)&&!(temp&(1<<16)));	//等待时间到达   
    
	SysTick->CTRL&=~SysTick_CTRL_ENABLE_Msk; //关闭计数器
	SysTick->VAL =0X00;       				//清空计数器 
}

//延时nms
//注意nms的范围
//SysTick->LOAD为24位寄存器,所以,最大延时为:
//nms<=0xffffff*8*1000/SYSCLK
//SYSCLK单位为Hz,nms单位为ms
//对168M条件下,nms<=798ms 
void delay_xms(u16 nms)
{	 		  	  
	u32 temp;		   
    
	SysTick->LOAD=(u32)nms*fac_ms;//时间加载(SysTick->LOAD为24bit)
	SysTick->VAL =0x00;//清空计数器
	SysTick->CTRL|=SysTick_CTRL_ENABLE_Msk;//开始倒数 
    
	do
	{
		temp=SysTick->CTRL;
	}
    while((temp&0x01) && !(temp&(1<<16)));
    //监控CTRL直到其全为1且只有高15位为0时
    //等待时间到达 
    
	SysTick->CTRL&=~SysTick_CTRL_ENABLE_Msk;//关闭计数器
	SysTick->VAL =0X00;//清空计数器	  	    
} 

//延时nms 
//nms:0~65535
void delay_ms(u16 nms)
{	 	 
	u8 repeat=nms/540;						
	//这里用540,是考虑到某些客户可能超频使用,
	//比如超频到248M的时候,delay_xms最大只能延时541ms左右了
	u16 remain=nms%540;
    
	while(repeat)
	{
		delay_xms(540);
		repeat--;
	}
	if(remain)
        delay_xms(remain);
} 
```

delay.h

```c
#ifndef __DELAY_H
	#define __DELAY_H 			   
	#include <sys.h>	  
 
	void delay_init(u8 SYSCLK);//延时函数初始化函数声明

	void delay_ms(u16 nms);//毫秒延时函数声明
	void delay_us(u32 nus);//微秒延时函数声明

#endif
```

main.c

```c
delay_init(168);//初始化延时函数
```

## systick定时器

**24位倒计数定时器**，从RELOAD寄存器中自动重装载定时初值，只要不把它的控制位和状态位清除就**永不停息**

会产生SYSTICK异常，捆绑在NVIC，中断优先级可以设置

4个SysTick寄存器

| CTRL | 控制和状态寄存器 |      |      |
|-----|----|----|----|
| LOAD  | 自动重装载寄存器 | 自动对其中的值执行-1 | 可调用库函数装载寄存器 |
| VAL   | 当前值寄存器     | 存储当前systick值 | 可调用库函数进行查询 |
| CALIB | 校准值寄存器 | 引入外部校准值 |      |

时钟源：HCLK（AHB总线时钟）或其1/8分频

使用**SysTick_CLKSourceConfig**配置时钟源

初始化并开启中断**SysTick_Config(uint32_t ticks)**

中断服务函数**SysTick_Handler()**

# USMART调试

过程：串口发送指令给MCU，MCU收到指令后调用单片机内对应函数并执行

操作方式类似shell，可移植到大多数stm32开发平台上

多用于修改函数入口参数、查看运行效果的情况

## 使用步骤

1. 将USMART包添加到工程、且包含到path
2. 添加需要调用的函数到usmart_config.c
3. 主函数调用usmart_dev.init()函数初始化usmart
4. 通过串口发送命令，可调用在usmart注册过的函数







