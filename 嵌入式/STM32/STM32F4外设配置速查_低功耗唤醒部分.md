# 低功耗模式

一般在系统或电源复位后，mcu在运行状态下由HCLK为CPU提供时钟，内核执行代码，当CPU不需要运行时可利用多种低功耗模式来节省功耗，等待某事件触发时才唤醒

stm32f4xx有三种低功耗模式

| 睡眠模式 | 仅内核停止，外设如NVIC、systick等仍运行                      |
| -------- | ------------------------------------------------------------ |
| 停止模式 | 所有时钟停止，1.8V内核电源工作，备份寄存器、待机电路等都有供电，寄存器、SRAM数据保留 |
| 待机模式 | 1.8V内核电源关闭，仅有备份寄存器和待机电路维持供电，寄存器、SRAM清空，功耗最低 |

运行模式下，也可通过**降低系统时钟**和**关闭未被使用的外设时钟**来降低功耗

## 调压器

嵌入式线性调压器为除备份域和待机电路外所有数字电路供电，需要连接两个外部电容到专用引脚$V_{CAP\_1}$和$V_{CAP\_2}$为激活和停用调压器，需要将特定引脚连接到VSS或VDD，具体引脚由封装决定

## 低功耗模式开启方法

| 模式 | 进入                               | 唤醒                                                         | 对1.2V域时钟的影响      | 对VDD域时钟的影响 | 调压器               |
| ---- | ---------------------------------- | ------------------------------------------------------------ | ----------------------- | ----------------- | -------------------- |
| 睡眠 | WFI/WFE                            | 任意中断/唤醒事件                                            | CPU CLK关闭，其他无影响 | 无                | 开启                 |
| 停止 | PDDS位和LPDS位+SLEEPDEEP位+WFI/WFE | 任意EXTI线（可在EXTI寄存器中配置，包括内部线和外部线）       | 全部关闭                | HSI、HSE关闭      | 开启或处于低功耗模式 |
| 待机 | PDDS位+SLEEPDEEP位+WFI/WFE         | WKUP引脚上升沿、RTC闹钟（A或B）、RTC唤醒事件、RTC入侵事件、RTC时间戳事件、NRST引脚外部复位、IWDG复位 | 全部关闭                | HSI、HSE关闭      | 关闭                 |

**WFI置位**可用**任意中断**唤醒

**WFE**置位可用**唤醒事件**唤醒

理想状态下，待机模式只需要2.2uA电流，典型电流为350uA

## stm32f4的特别说明

使能了RTC闹钟中断或RTC周期性唤醒等中断时，进入待机模式前，必须进行以下处理：

1. 禁止RTC中断
2. 清零对应中断标志位
3. 清除PWR唤醒（WUF）标志（通过设置PWR_CR->CWUF位实现）
4. 重新使能RTC对应中断
5. 进入低功耗模式

详情参考stm32f4xx芯片手册

## stm32f4xx的待机模式启用-唤醒配置

**注意：使用前需引入stm32f4xx_pwr.c库文件**

进入待机配置步骤：

1. 使能电源时钟
2. 关闭RTC相关中断
3. 设置WK_UP引脚为唤醒源
4. 设置SLEEPDEEP位、PDDS位、执行WFI指令，进入待机模式

wkup.h

```c
#ifndef __WKUP_H
	#define __WKUP_H
	#include "sys.h"
	
	u8 Check_WKUP(void);//检测WKUP脚信号
	void WKUP_enter_standbymode(void);//系统进入待机模式
	void WKUP_init(void);//待机唤醒初始化
	
#endif
```

wkup.c

```c
#include "wkup.h"
#include "delay.h"

//检测WKUP脚信号
//返回1：连续按下3s以上；返回0：错误的触发（连按3s以下）
u8 Check_WKUP(void)
{
	u8 t=0;
	u8 tx=0;//记录松开的次数

	while(1)
	{
		if(WKUP_KD)//WKUP已经按下
		{
			t++;
			tx=0;
		}
		else
		{
			tx++;
			if(tx>3)//超过90ms内没有WKUP信号
				return 0;
		}
		
		delay_ms(30);
		
		if(t>=100)//按下超过3s
			return 1;
	}
}
/*此函数效率较低，可使用定时器来重写*/

//系统进入待机模式
void WKUP_enter_standbymode(void)
{
	while(WKUP_KD);//等待WKUP按键松开(在有RTC中断时，必须等WKUP松开再进入待机)

	RCC_AHB1PeriphResetCmd(0x04FF,ENABLE);//复位所有GPIO口
	
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_PWR,ENABLE);//使能电源配置时钟
	PWR_BackupAccessCmd(ENABLE);//使能备份域访问

	RTC_ITConfig(RTC_IT_TS|RTC_IT_WUT|RTC_IT_ALRA|RTC_IT_ALRB,DISABLE);//关闭RTC相关中断
	RTC_ClearITPendingBit(RTC_IT_TS|RTC_IT_WUT|RTC_IT_ALRA|RTC_IT_ALRB);//清除中断标志位
	
	PWR_ClearFlag(PWR_FLAG_WU);//清除WKUP标志
	
	PWR_WakeUpPinCmd(ENABLE);//使能待机唤醒功能
	PWR_EnterSTANDBYMode();//进入待机模式
}

//以PA0为待机唤醒引脚，进行WKUP唤醒初始化
void WKUP_init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	NVIC_InitTypeDef NVIC_InitStructure;
	EXTI_InitTypeDef EXTI_InitStructure;
	
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA,ENABLE);//使能GPIOA时钟
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_SYSCFG,ENABLE);//使能SYSCFG时钟

	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_IN;//输入模式
	GPIO_InitStructure.GPIO_OType=GPIO_OType_OD;//开漏输出模式
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_0;//PA0
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_DOWN;//内部下拉
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//100MHz
	//应用设置
	GPIO_Init(GPIOA,&GPIO_InitStructure);
	
	if(Check_WKUP()==0)//查看是否正常开机
		WKUP_enter_standbymode();//未开机则进入待机模式
	
	SYSCFG_EXTILineConfig(EXTI_PortSourceGPIOA,EXTI_PinSource0);//PA0连接到中断线0
	
	EXTI_InitStructure.EXTI_Line=EXTI_Line0;//中断线0
	EXTI_InitStructure.EXTI_Mode=EXTI_Mode_Interrupt;//中断事件
	EXTI_InitStructure.EXTI_Trigger=EXTI_Trigger_Rising;//上升沿触发
	EXTI_InitStructure.EXTI_LineCmd=ENABLE;//使能Line0
	//应用设置
	EXTI_Init(&EXTI_InitStructure);
	
	NVIC_InitStructure.NVIC_IRQChannel=EXTI0_IRQn;//外部中断0
	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=0x02;//抢占优先级2
	NVIC_InitStructure.NVIC_IRQChannelSubPriority=0x02;//子优先级2
	NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//使能外部中断通道
	//应用设置
	NVIC_Init(&NVIC_InitStructure);
}

//中断线0-PA0中断服务函数
//上升沿触发，用于正常运行状态进入待机模式
void EXTI0_IRQHandler(void)
{
	EXTI_ClearITPendingBit(EXTI_Line0);//清除中断标志位
	if(Check_WKUP())//判断是否有待机按键按下
		WKUP_enter_standbymode();//进入待机模式
}
```

main.c

此程序为待机唤醒的演示

如果用了上面的“长按3s进入待机模式”代码，则main文件内应当放入日常执行的程序

```c
int main(void)
{
	while(1)
	{
		if(KEY_scan(0)==KEY0_PRES)//如果KEY0按下，进入待机模式
		{
			RCC_APB1PeriphClockCmd(RCC_APB1Periph_PWR,ENABLE);//使能电源配置时钟
			PWR_BackupAccessCmd(ENABLE);//使能备份域时钟
			
			RTC_ITConfig(RTC_IT_TS|RTC_IT_WUT|RTC_IT_ALRA|RTC_IT_ALRB,DISABLE);//关闭RTC相关中断
			RTC_ClearITPendingBit(RTC_IT_TS|RTC_IT_WUT|RTC_IT_ALRA|RTC_IT_ALRB);//清除中断标志位
			
			PWR_WakeUpPinCmd(ENABLE);//使能待机唤醒功能
			PWR_EnterSTANDBYMode();
		}
	}
}
```

