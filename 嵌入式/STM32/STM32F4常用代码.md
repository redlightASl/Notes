### 检查单击、长按、双击


```c
//key_read表示读取的按钮引脚，以GPIO_ReadInputDataBit(GPIOX,GPIO_Pin_x)形式输入
//limit_time表示长按限制时间，表示n ms
//double_click_time表示双击间隔时间，表示n ms
u8 key_driver(uint8_t key_read,unsigned int limit_time,unsigned int double_click_time)
{
	static uint8_t key_state=0;
	static unsigned int press_time=0;
	unsigned int check_double_press_time=0;
	u8 click=0;
	
	if(key_read==0)//如果检测到按钮按下
	{
		while((key_read!=0)&&(press_time<limit_time))//按钮松开 或 到达长按时间 后 停止计数 
		{
			press_time++;
			delay_ms(1);
		}
		if(press_time>=limit_time)//如果为长按
		{
			return 2;//2表示长按
			while(!key_read);//等待按钮松开
		}
		else
		{
			for(check_double_press_time=0;check_double_press_time<double_click_time;check_double_press_time++)//是否连续点击两次
			{
				delay_ms(1);
				if(key_read==0)
				{
					click=1;//双击才会使click=1触发
					return 1;//1表示双击
					while(!key_read);//等待按钮松开
				}
			}
			if(click==0)//检查单击
			{
				return 0;//0代表单击
			}
			click=0;
			press_time=0;
		}
	}
}
```

# TIM延迟函数

tim_delay.h

```c
#ifndef _TIMER_H
	#define _TIMER_H
	#include "sys.h"
	
	void TIM2_init(void);
	void TIM3_init(void);
	void TIM2_delay_ms(u32 num);//由TIM2延迟ms
	void TIM_delay_min(u32 num);//级联延迟分钟
        
#endif
```

tim_delay.c

```c
#include "tim_delay.h"

//通用定时器2初始化
//arr：自动重装值。由16位寄存器控制
//psc：时钟预分频数。由16位寄存器控制
void TIM2_init(u16 arr,u16 psc)
{
	TIM_TimeBaseInitTypeDef TIM_TimeBaseInitStructure;
 	NVIC_InitTypeDef NVIC_InitStructure;
  
	//使能TIM2时钟
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM2,ENABLE);
	
  	//配置定时器设置
  	TIM_TimeBaseInitStructure.TIM_Period=arr;//设置自动重装载值
	TIM_TimeBaseInitStructure.TIM_Prescaler=psc;//设置定时器分频
	TIM_TimeBaseInitStructure.TIM_CounterMode=TIM_CounterMode_Up;//选用向上计数模式
	TIM_TimeBaseInitStructure.TIM_ClockDivision=TIM_CKD_DIV1;//设置定时器分频状态，如果设置不为1的时候默认为2
  	//应用设置
	TIM_TimeBaseInit(TIM2,&TIM_TimeBaseInitStructure);
  	//TIM_TimeBaseInit参数1为选用哪个定时器，参数2为定时器初始化结构体取址
	
  	//使能定时器2
	TIM_Cmd(TIM2,ENABLE);
}
```

# system配置

HAL库版本

```c
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /* 配置主电源域电压 */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);
  /* 初始化RCC晶振 */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLM = 8;
  RCC_OscInitStruct.PLL.PLLN = 168;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
  RCC_OscInitStruct.PLL.PLLQ = 4;
  
  /** 初始化CPU、AHB总线、APB总线时钟
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV4;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV2;
}
```

STL库版本

```c
void SystemInit(void)
{
  	/* FPU settings ------------------------------------------------------------*/
 	#if (__FPU_PRESENT == 1) && (__FPU_USED == 1)
    	SCB->CPACR |= ((3UL << 10*2)|(3UL << 11*2));  /* set CP10 and CP11 Full Access */
  	#endif
  	/* Reset the RCC clock configuration to the default reset state ------------*/
  	/* Set HSION bit */
  	RCC->CR |= (uint32_t)0x00000001;

  	/* Reset CFGR register */
  	RCC->CFGR = 0x00000000;

  	/* Reset HSEON, CSSON and PLLON bits */
  	RCC->CR &= (uint32_t)0xFEF6FFFF;

  	/* Reset PLLCFGR register */
  	RCC->PLLCFGR = 0x24003010;

  	/* Reset HSEBYP bit */
  	RCC->CR &= (uint32_t)0xFFFBFFFF;

  	/* Disable all interrupts */
  	RCC->CIR = 0x00000000;
    
  	SetSysClock();
}

static void SetSysClock(void)
{
    /* Enable HSE */
  	RCC->CR |= ((uint32_t)RCC_CR_HSEON);
 
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

#if defined (STM32F40_41xxx) || defined (STM32F427_437xx) || defined (STM32F429_439xx)      
    /* PCLK2 = HCLK / 2*/
    RCC->CFGR |= RCC_CFGR_PPRE2_DIV2;
    
    /* PCLK1 = HCLK / 4*/
    RCC->CFGR |= RCC_CFGR_PPRE1_DIV4;
#endif /* STM32F40_41xxx || STM32F427_437x || STM32F429_439xx */
    RCC->PLLCFGR = PLL_M | (PLL_N << 6) | (((PLL_P >> 1) -1) << 16) |
                   (RCC_PLLCFGR_PLLSRC_HSE) | (PLL_Q << 24);

    /* Enable the main PLL */
    RCC->CR |= RCC_CR_PLLON;

    /* Wait till the main PLL is ready */
    while((RCC->CR & RCC_CR_PLLRDY) == 0)
    {
    }
      
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
}

```

