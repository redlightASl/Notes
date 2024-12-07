主要为速查关键函数编写，部分内容不规范

## 中断线（EXTI）

stm32f4每个GPIO都可以作为外部中断的输入口，中断控制器支持22个外部中断、事件请求

| 中断线EXTIx | 功能                             |
| ----------- | -------------------------------- |
| 0-15        | GPIO输入中断                     |
| 16          | PVD输出                          |
| 17          | RTC闹钟事件                      |
| 18          | USB OTG FS唤醒事件               |
| 19          | 以太网唤醒事件                   |
| 20          | USB OTG HS（在FS中配置）唤醒事件 |
| 21          | RTC入侵和时间戳事件              |
| 22          | RTC唤醒事件                      |

EXTI~x~分别对应从PA~x~到PF~x~

## 中断服务函数

中断服务函数名称在MDK里事先定义好，不能随意更改

```c
EXTI0_IRQHandler//对应中断线EXTI0
EXTI1_IRQHandler//对应中断线EXTI1
EXTI2_IRQHandler//对应中断线EXTI2
EXTI3_IRQHandler//对应中断线EXTI3
EXTI4_IRQHandler//对应中断线EXTI4
EXTI9_5_IRQHandler//中断线EXTI5-9共用
EXTI15_10_IRQHandler//中断线EXTI10-15共用
```


## 中断管理

1. 中断优先级分组

   将STM32中断分成0-4共5个组

   每个中断有抢占优先级和响应优先级

   ==高抢占优先级可打断第低抢占优先级==

   ==抢占优先级相同的中断，那个响应优先级高哪个先执行==

   ==如果两中断优先级相同，则哪个先发生哪个先执行==

   **分组数字越小，优先级越高**
   **一般代码执行过程中只设置一次中断优先级分组**

2. 利用NVIC_PriorityGroupConfig()函数设置优先级分组

   利用NVIC_Init()函数和NVIC_InitStructure结构体组合设置中断通道、抢占优先级、响应优先级、使能中断

3. 中断优先级设置步骤

   1.设置中断优先级分组

   2.针对每个中断设置抢占优先级和响应优先级

   3.程序途中可使用相关函数查看中断状态

## 外部中断

1. exti.c

```c
#include "exti.h"
//外部中断设置

#include "xxx1.h" 
#include "xxx2.h" 
#include "xxx3.h"
#include "xxx4.h"
......
//其他外设设置

void EXTIX_Init(void)//外部中断初始化程序,初始化PE2~4,PA0为中断输入
{
    //1. 定义基本结构体
	NVIC_InitTypeDef   NVIC_InitStructure;
	EXTI_InitTypeDef   EXTI_InitStructure;
    
	//2. 初始化GPIO与周边外设
	GPIO_Init();
	PeriphSets_Init();

    //3. 使能SYSCFG时钟
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_SYSCFG, ENABLE);
	    
    //4. 设置IO口与中断线映射关系
	SYSCFG_EXTILineConfig(EXTI_PortSourceGPIOE, EXTI_PinSource2);//PE2 连接到中断线2
	SYSCFG_EXTILineConfig(EXTI_PortSourceGPIOE, EXTI_PinSource3);//PE3 连接到中断线3
	SYSCFG_EXTILineConfig(EXTI_PortSourceGPIOE, EXTI_PinSource4);//PE4 连接到中断线4
	SYSCFG_EXTILineConfig(EXTI_PortSourceGPIOA, EXTI_PinSource0);//PA0 连接到中断线0

    
    //5. 配置中断线0设定
    EXTI_InitStructure.EXTI_Line = EXTI_Line0;//LINE0
  	EXTI_InitStructure.EXTI_Mode = EXTI_Mode_Interrupt;//中断事件
  	EXTI_InitStructure.EXTI_Trigger = EXTI_Trigger_Rising; //上升沿触发 
	EXTI_InitStructure.EXTI_LineCmd = ENABLE;//使能LINE0
    //应用配置
    EXTI_Init(&EXTI_InitStructure);
    
    //配置中断线2、3、4设定
	EXTI_InitStructure.EXTI_Line = EXTI_Line2 | EXTI_Line3 | EXTI_Line4;//LINE2、3、4
  	EXTI_InitStructure.EXTI_Mode = EXTI_Mode_Interrupt;//中断事件
  	EXTI_InitStructure.EXTI_Trigger = EXTI_Trigger_Falling; //下降沿触发
  	EXTI_InitStructure.EXTI_LineCmd = ENABLE;//中断线使能
    //应用配置
  	EXTI_Init(&EXTI_InitStructure);
    
    
    //6.1 配置中断分组（优先级）（NVIC），并使能中断
    //配置中断0优先级设定
	NVIC_InitStructure.NVIC_IRQChannel = EXTI0_IRQn;//外部中断0
  	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 0x00;//抢占优先级0
  	NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0x02;//子优先级2
  	NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;//使能外部中断通道
    //应用配置
    NVIC_Init(&NVIC_InitStructure);

    //配置中断2优先级设定
	NVIC_InitStructure.NVIC_IRQChannel = EXTI2_IRQn;//外部中断2
  	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 0x03;//抢占优先级3
  	NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0x02;//子优先级2
  	NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;//使能外部中断通道、
    //应用配置
  	NVIC_Init(&NVIC_InitStructure);

    //配置中断3优先级设定
	NVIC_InitStructure.NVIC_IRQChannel = EXTI3_IRQn;//外部中断3
  	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 0x02;//抢占优先级2
  	NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0x02;//子优先级2
  	NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;//使能外部中断通道
    //应用配置
  	NVIC_Init(&NVIC_InitStructure);

    //配置中断4优先级设定
	NVIC_InitStructure.NVIC_IRQChannel = EXTI4_IRQn;//外部中断4
  	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 0x01;//抢占优先级1
  	NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0x02;//子优先级2
  	NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;//使能外部中断通道
    //应用配置
  	NVIC_Init(&NVIC_InitStructure);
}


//7. 编写中断服务函数
void EXTI0_IRQHandler(void)//外部中断0服务程序_蜂鸣器
{
	delay_ms(10);//消抖
	if(WK_UP==1)	 
	{
		BEEP=!BEEP;//蜂鸣器翻转
	}
    
    
    //8. 清除LINE0上的中断标志位 
	EXTI_ClearITPendingBit(EXTI_Line0);
}

void EXTI2_IRQHandler(void)//外部中断2服务程序_led0反转
{
	delay_ms(10);//消抖
	if(KEY2==0)	  
	{				 
   		LED0=!LED0; 
	}		 
    
    
    //8. 清除LINE2上的中断标志位 
	EXTI_ClearITPendingBit(EXTI_Line2);
}

void EXTI3_IRQHandler(void)//外部中断3服务程序_led1反转
{
	delay_ms(10);//消抖
	if(KEY1==0)	 
	{
		LED1=!LED1;
	}		 
    
    //8. 清除LINE3上的中断标志位 
	EXTI_ClearITPendingBit(EXTI_Line3); 
}

void EXTI4_IRQHandler(void)//外部中断4服务程序_led0、led1同时反转
{
	delay_ms(10);	//消抖
	if(KEY0==0)	 
	{				 
		LED0=!LED0;	
		LED1=!LED1;	
	}		 
    
    
    //8. 清除LINE4上的中断标志位
	EXTI_ClearITPendingBit(EXTI_Line4);
}
```

2. exti.h

   注意头文件一定加入头文件路径

```c
#ifndef __EXTI_H
	#define __EXTI_H	 
	#include "sys.h"
	void EXTIX_Init(void);	//调用外部中断初始化
#endif
```

3. main.c

```c
#include "sys.h"
#include "delay.h"
#include "usart.h"//串口配置文件
#include "led.h"//led配置文件
#include "beep.h"//蜂鸣器配置文件
#include "key.h"//按键配置文件

#include "exti.h"//外部中断配置文件

void main(void)
{ 
    EXTI_Init();//初始化外部中断输入
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//设置系统中断优先级分组2
    
	delay_init(168);    //初始化延时函数
    
	uart_init(115200); 	//串口初始化
    
	LED_Init();//初始化LED端口
    LED0=0;//先设置灯亮初值
    
	BEEP_Init();//初始化蜂鸣器端口
    
	while(1)
	{
  		printf("OK\r\n");//串口打印OK提示程序运行
		delay_ms(1000);//每隔1s打印一次
        
        balabalabalabala...
	}
}
```
