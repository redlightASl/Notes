## RTC（Real Time Clock）实时时钟

* 独立的BCD定时器/计数器
* 可以提供日历时钟
* 有2个可编程闹钟中断，1个具有中断功能的周期性可编程唤醒标志
* 包含用于管理低功耗模式的自动唤醒单元

2个32位寄存器包含**BCD格式**的second、minute、hour（12/24小时制）、day、week、month、year

还可以提供二进制的亚秒值

系统可自动将月份天数补偿位28、29、30、31天，还可以进行夏令时补偿

**时钟源**：由RTC_CALR精密校准过的LSE（32.768kHz）时钟经过多次分频得到的1Hz时钟；影子寄存器（RTC_SSR)使用第一次分频后得到的256Hz时钟，可精确到亚秒

## RTC日历

1. 使能PWR时钟
2. 使能后备寄存器访问
3. 配置RTC时钟源，使能RTC时钟
4. RTC初始化
5. 设置时间
6. 设置日期

## RTC闹钟

1. RTC初始化
2. 关闭闹钟
3. 配置闹钟参数
4. 开启闹钟
5. 开启配置闹钟中断
6. 编写中断服务函数

## RTC自动唤醒

1. RTC初始化
2. 使能唤醒
3. 配置唤醒时钟系数/来源
4. 设置唤醒自动装载寄存器
5. 使能自动唤醒
6. 开启配置唤醒中断
7. 编写中断服务函数

rtc.c

```c
#include "rtc.h"
#include "led.h"
#include "delay.h"
#include "usart.h" 

NVIC_InitTypeDef NVIC_InitStructure;

/**************************RTC初始化*******************************/

//RTC时间设置函数
//hour,min,sec:时,分,秒设定值
//ampm:@RTC_AM_PM_Definitions:RTC_H12_AM/RTC_H12_PM
//返回值:SUCEE(1),成功；ERROR(0),进入初始化模式失败 
ErrorStatus RTC_Set_Time(u8 hour,u8 min,u8 sec,u8 ampm)
{
	RTC_TimeTypeDef RTC_TimeTypeInitStructure;
	
	RTC_TimeTypeInitStructure.RTC_Hours=hour;
	RTC_TimeTypeInitStructure.RTC_Minutes=min;
	RTC_TimeTypeInitStructure.RTC_Seconds=sec;
	RTC_TimeTypeInitStructure.RTC_H12=ampm;
	
	return RTC_SetTime(RTC_Format_BIN,&RTC_TimeTypeInitStructure);
}

//RTC日期设置函数
//year,month,date:年(0~99),月(1~12),日(0~31)
//week:星期(1~7,0为非法)
//返回值:SUCEE(1),成功
//       ERROR(0),进入初始化模式失败 
ErrorStatus RTC_Set_Date(u8 year,u8 month,u8 date,u8 week)
{
	
	RTC_DateTypeDef RTC_DateTypeInitStructure;
    
	RTC_DateTypeInitStructure.RTC_Date=date;
	RTC_DateTypeInitStructure.RTC_Month=month;
	RTC_DateTypeInitStructure.RTC_WeekDay=week;
	RTC_DateTypeInitStructure.RTC_Year=year;
    
	return RTC_SetDate(RTC_Format_BIN,&RTC_DateTypeInitStructure);
}

//RTC初始化函数
//返回值:0,初始化成功;
//       1,LSE开启失败;
//       2,进入初始化模式失败;
u8 My_RTC_Init(void)
{
    //1. 定义RTC初始化结构体
	RTC_InitTypeDef RTC_InitStructure;
    
	u16 retry=0X1FFF;
    
    //2. 使能PWR时钟 	使能后备寄存器访问 
  	RCC_APB1PeriphClockCmd(RCC_APB1Periph_PWR, ENABLE);
	PWR_BackupAccessCmd(ENABLE);
	
    //读取备份寄存器，备份寄存器作为函数调用的标志，防止重复配置
	if(RTC_ReadBackupRegister(RTC_BKP_DR0)!=0x5050)//如果为第一次配置
	{
		RCC_LSEConfig(RCC_LSE_ON);//3. 那么开启LSE
        //并检查指定的RCC标志位设置是否完毕,等待低速晶振就绪
		while(RCC_GetFlagStatus(RCC_FLAG_LSERDY)==RESET)
			{
				retry++;
				delay_ms(10);
			}
		if(retry==0)//如果等待时间过长
            return 1;//LSE 开启失败. 
			
        //4. 设置RTC时钟(RTCCLK),选择LSE作为RTC时钟 
		RCC_RTCCLKConfig(RCC_RTCCLKSource_LSE);
        
        //5. 使能RTC时钟 
		RCC_RTCCLKCmd(ENABLE);

        //6. 设定RTC分频系数和相关设定
    	RTC_InitStructure.RTC_AsynchPrediv=0x7F;//RTC异步分频系数(1~0X7F)
    	RTC_InitStructure.RTC_SynchPrediv=0xFF;//RTC同步分频系数(0~7FFF)
    	RTC_InitStructure.RTC_HourFormat=RTC_HourFormat_24;//RTC设置为,24小时格式
        //应用设置
    	RTC_Init(&RTC_InitStructure);
 
        //7. 设置时间和日期
		RTC_Set_Time(23,59,56,RTC_H12_AM);
		RTC_Set_Date(14,5,5,1);
	 
        //8. 提示“该标记已经初始化过”
		RTC_WriteBackupRegister(RTC_BKP_DR0,0x5050);
	} 
    //如果不是第一次配置则跳过
	return 0;
}

/**************************RTC初始化*******************************/

/**************************闹钟初始化*******************************/

//设置闹钟时间(按星期闹铃,24小时制)
//week:星期几(1~7) @ref  RTC_Alarm_Definitions
//hour,min,sec:时,分,秒
void RTC_Set_AlarmA(u8 week,u8 hour,u8 min,u8 sec)
{ 
    //1. 设置闹钟相关初始化结构体
	EXTI_InitTypeDef EXTI_InitStructure;
	RTC_AlarmTypeDef RTC_AlarmTypeInitStructure;
	RTC_TimeTypeDef RTC_TimeTypeInitStructure;
	
    //2. 关闭闹钟A 
	RTC_AlarmCmd(RTC_Alarm_A,DISABLE);
	
    //3. RTC初始化
  	RTC_TimeTypeInitStructure.RTC_Hours=hour;//小时
	RTC_TimeTypeInitStructure.RTC_Minutes=min;//分钟
	RTC_TimeTypeInitStructure.RTC_Seconds=sec;//秒
	RTC_TimeTypeInitStructure.RTC_H12=RTC_H12_AM;//上下午
	RTC_AlarmTypeInitStructure.RTC_AlarmDateWeekDay=week;//星期
    
    //4. RTC闹钟初始化
    //按星期闹钟
    RTC_AlarmTypeInitStructure.RTC_AlarmDateWeekDaySel=RTC_AlarmDateWeekDaySel_WeekDay;
	RTC_AlarmTypeInitStructure.RTC_AlarmMask=RTC_AlarmMask_None;//精确匹配星期，时分秒
	RTC_AlarmTypeInitStructure.RTC_AlarmTime=RTC_TimeTypeInitStructure;
    //应用设置
  	RTC_SetAlarm(RTC_Format_BIN,RTC_Alarm_A,&RTC_AlarmTypeInitStructure);
    
    //5. 清除RTC闹钟A的标志
	RTC_ClearITPendingBit(RTC_IT_ALRA);
    //6. 清除LINE17上的中断标志位
  	EXTI_ClearITPendingBit(EXTI_Line17);
    
	//7. 开启闹钟A中断
	RTC_ITConfig(RTC_IT_ALRA,ENABLE);
    //8. 开启闹钟A
	RTC_AlarmCmd(RTC_Alarm_A,ENABLE); 
	
	EXTI_InitStructure.EXTI_Line=EXTI_Line17;//设置中断线17为闹钟中断
  	EXTI_InitStructure.EXTI_Mode=EXTI_Mode_Interrupt;//中断事件
  	EXTI_InitStructure.EXTI_Trigger=EXTI_Trigger_Rising;//上升沿触发 
  	EXTI_InitStructure.EXTI_LineCmd=ENABLE;//使能LINE17
    //应用配置
  	EXTI_Init(&EXTI_InitStructure);

	NVIC_InitStructure.NVIC_IRQChannel = RTC_Alarm_IRQn;
  	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 0x02;//抢占优先级1
  	NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0x02;//子优先级2
  	NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;//使能外部中断通道
    //应用配置
  	NVIC_Init(&NVIC_InitStructure);
}


/**************************闹钟初始化*******************************/

/**************************周期唤醒初始化*******************************/

//周期性唤醒定时器设置
/*wksel:  @ref RTC_Wakeup_Timer_Definitions
#define RTC_WakeUpClock_RTCCLK_Div16        ((uint32_t)0x00000000)
#define RTC_WakeUpClock_RTCCLK_Div8         ((uint32_t)0x00000001)
#define RTC_WakeUpClock_RTCCLK_Div4         ((uint32_t)0x00000002)
#define RTC_WakeUpClock_RTCCLK_Div2         ((uint32_t)0x00000003)
#define RTC_WakeUpClock_CK_SPRE_16bits      ((uint32_t)0x00000004)
#define RTC_WakeUpClock_CK_SPRE_17bits      ((uint32_t)0x00000006)
*/

//cnt:自动重装载值.减到0,产生中断.
void RTC_Set_WakeUp(u32 RTC_wakeup_select,u16 RTC_wakeup_counter)
{ 
    //1. 声明自动唤醒相关中断结构体
	EXTI_InitTypeDef EXTI_InitStructure;
	
    //2. 关闭唤醒
	RTC_WakeUpCmd(DISABLE);
	
    //3. 唤醒时钟选择
	RTC_WakeUpClockConfig(RTC_wakeup_select);
	
    //4. 设置唤醒自动重装载寄存器
	RTC_SetWakeUpCounter(RTC_wakeup_counter);
	
    //5. 清除RTC唤醒的标志
	RTC_ClearITPendingBit(RTC_IT_WUT);
    
    //6. 清除LINE22上的中断标志位 
  	EXTI_ClearITPendingBit(EXTI_Line22);
	 
    //7. 开启唤醒定时器中断
	RTC_ITConfig(RTC_IT_WUT,ENABLE);
    
    //8. 开启唤醒定时器
	RTC_WakeUpCmd( ENABLE);　
	
	EXTI_InitStructure.EXTI_Line=EXTI_Line22;//LINE22
  	EXTI_InitStructure.EXTI_Mode=EXTI_Mode_Interrupt;//中断事件
  	EXTI_InitStructure.EXTI_Trigger=EXTI_Trigger_Rising;//上升沿触发 
  	EXTI_InitStructure.EXTI_LineCmd=ENABLE;//使能LINE22
    //应用设置
  	EXTI_Init(&EXTI_InitStructure);
 
 
	NVIC_InitStructure.NVIC_IRQChannel=RTC_WKUP_IRQn; 
  	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=0x02;//抢占优先级1
  	NVIC_InitStructure.NVIC_IRQChannelSubPriority=0x02;//子优先级2
  	NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//使能外部中断通道
    //应用设置
  	NVIC_Init(&NVIC_InitStructure);
}



/**************************周期唤醒初始化*******************************/
 
/**************************RTC闹钟中断服务函数*******************************/

void RTC_Alarm_IRQHandler(void)
{    
	if(RTC_GetFlagStatus(RTC_FLAG_ALRAF)==SET)//如果存在ALARM A中断
	{
		RTC_ClearFlag(RTC_FLAG_ALRAF);//那么清除中断标志
		printf("ALARM A!\r\n");
        balabalabalabala...
	}   
	EXTI_ClearITPendingBit(EXTI_Line17);//然后清除中断线17的中断标志 											 
}


/**************************RTC闹钟中断服务函数*******************************/

/**************************周期唤醒中断服务函数*******************************/

void RTC_WKUP_IRQHandler(void)
{    
	if(RTC_GetFlagStatus(RTC_FLAG_WUTF)==SET)//如果存在WK_UP中断
	{ 
		RTC_ClearFlag(RTC_FLAG_WUTF);//那么清除中断标志
		LED1=!LED1; 
        balabalabalabala...
	}   
	EXTI_ClearITPendingBit(EXTI_Line22);//然后清除中断线22的中断标志
}
```

rtc.h

```c
#ifndef __RTC_H
	#define __RTC_H

	#include "sys.h" 
	u8 My_RTC_Init(void);//RTC初始化函数声明

	ErrorStatus RTC_Set_Time(u8 hour,u8 min,u8 sec,u8 ampm);//RTC时间设置函数声明
	ErrorStatus RTC_Set_Date(u8 year,u8 month,u8 date,u8 week);//RTC日期设置函数声明
	void RTC_Set_AlarmA(u8 week,u8 hour,u8 min,u8 sec);//设置闹钟时间(按星期闹铃,24小时制)函数声明
	void RTC_Set_WakeUp(u32 RTC_wakeup_select,u16 RTC_wakeup_counter);//周期性唤醒定时器设置函数声明
#endif
```

main.c

```c
#include "sys.h"
#include "delay.h"  
#include "usart.h" 

#include "rtc.h"

int main(void)
{ 
    //定义RTC设置结构体
	RTC_TimeTypeDef RTC_TimeStruct;
	RTC_DateTypeDef RTC_DateStruct;

	u8 tbuf[40];
	u8 t=0;
    
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//设置系统中断优先级分组2
	delay_init(168);//初始化延时函数
	uart_init(115200);//初始化串口波特率为115200

	My_RTC_Init();//初始化RTC
 
	RTC_Set_WakeUp(RTC_WakeUpClock_CK_SPRE_16bits,0);//配置唤醒中断,1秒钟中断一次
    
  	while(1) 
	{		
		t++;
        
		if((t%10)==0)	//每100ms更新一次显示数据
		{
			RTC_GetTime(RTC_Format_BIN,&RTC_TimeStruct);//获取RTC时间，保存至Time结构体
			//以成员访问Time结构体，可接显示屏输出
			
			RTC_GetDate(RTC_Format_BIN, &RTC_DateStruct);//获取RTC日期，保存至Date结构体
			//以成员访问Date结构体，可接显示屏输出
		} 
        
		if((t%20)==0)LED0=!LED0;//每200ms,翻转一次LED0 
		delay_ms(10);
	}	
}

```











