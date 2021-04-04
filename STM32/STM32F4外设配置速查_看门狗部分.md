## 独立看门狗（IWDG）

iwdg.c

```c
#include "iwdg.h"

void IWDG_Init(u8 prer,u16 rlr)//prer为预分频系数，rlr为溢出时间
{
    //1. 取消寄存器写保护
	IWDG_WritrAccessCmd(IWDG_WriteAccess_Enable);
    
    //2. 设置独立看门狗预分频系数
	IWDG_SetPrescaler(prer);
    
    //3. 设置看门狗重装载值，设置溢出时间
	IWDG_SetReload(rlr);
    
    //5. 将设定的溢出时间加载到IWDG
	IWDG_ReloadCounter();
    
    //4. 使能看门狗
	IWDG_Enable();
}
```

溢出时间计算：

$$
Tout=\frac{4*2^{prer}*rlr}{32}	(M4)
$$
iwdg.h

```c
#ifndef __IWDG_H
	#define __IWDG_H
	#include "sys.h"
	void IWDG_Init();
#endif
```

main.c

```c
void main(void)
{
    IWDG_Init();//初始化看门狗
        
    while(1)
    {
        balabalabala...
            
      	//6. 运行程序中途应调用函数及时喂狗
		IWDG_ReloadCounter(prep,rlr);  
        delay(n);
        
		balabalabala...
    }
}
```

## 窗口看门狗（WWDG）

喂狗时间存在上下限（窗口），其中下限固定，上限由相关寄存器控制，喂狗时间不能太早也不能过晚

WWDG种有一个7位的递减计数器T[6:0]，在下列两种情况之一

1. 喂狗时，计数器值大于某一设定数值W[6:0]

2. 计数器数值从0x40减到0x3F（T6跳变为0）时

产生看门狗复位

如果启动了看门狗并允许中断，当递减计数器等于0x40时产生早期唤醒中断（EWI），可以在此设置喂狗函数以避免WWDG复位



看门狗超时公式：
$$
T_{wwdg}=4096*2^{WDGTB}*\frac{T[5:0]+1}{F_{pclk1}}
$$

其中，$$T_{wwdg}$$单位为ms，是WWDG超时时间

$$F_{pclk1}$$单位为kHz，是APB1的时钟频率

$$WDGTB$$是WWDG的预分频系数

$$T[5:0]$$是WWDG计数器低6位

**使用注意**：上窗口值W[6:0]必须大于下窗口值0x40；WWDG时钟来源于PCLK1（APB1总线时钟）的分频

wwdg.c

```c
#include "wwdg.h"
#include "led.h"

//保存WWDG计数器的设置值,默认为最大. 
u8 WWDG_CNT=0X7F;

//tr代表T[6:0],计数器值 
//wr代表W[6:0],窗口值 
//fprer代表分频系数（WDGTB）,仅最低2位有效 
//Fwwdg=PCLK1/(4096*2^fprer). 一般PCLK1=42Mhz
void WWDG_Init(u8 tr,u8 wr,u32 fprer)//初始化WWDG函数
{
    //1. 使能窗口看门狗时钟（来自APB1时钟分频）
    RCC_APB1PeriphClockCmd(RCC_APB1Periph_WWDG,ENABLE); 
    
	//2. 初始化WWDG_CNT寄存器
    //上面已经有了WWDG_CNT=0X7F，将
	WWDG_CNT=tr&WWDG_CNT;
    //大概能写成WWDG_CNT&=tr;
    
    //4. 定义NVIC初始化结构体
	NVIC_InitTypeDef NVIC_InitStructure;
    
    //5. 设置中断优先级
    NVIC_InitStructure.NVIC_IRQChannel=WWDG_IRQn;//调用WWDG中断
	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=0x02;//抢占优先级为2
	NVIC_InitStructure.NVIC_IRQChannelSubPriority=0x03;//子优先级为3
	NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//使能WWDG中断
    //应用中断优先级设置
	NVIC_Init(&NVIC_InitStructure);
    
    //配置WWDG相关参数
	WWDG_SetPrescaler(fprer);//设置分频值
	WWDG_SetWindowValue(wr);//设置窗口值
	WWDG_SetCounter(WWDG_CNT);//设置计数值
    //开启看门狗
	WWDG_Enable(WWDG_CNT);
	
    //6. 初始化前清除提前唤醒中断标志位
	WWDG_ClearFlag();
    
    //3. 开启提前唤醒中断
  	WWDG_EnableIT();
}

//7. 设置WWDG中断服务程序 
void WWDG_IRQHandler(void)
{
    //8. 喂狗（重设WWDG值）
	WWDG_SetCounter(WWDG_CNT);
    
    //9. 清除提前唤醒中断标志位
	WWDG_ClearFlag();
    
    //10. 其他的功能
    balabalabala...
	LED1=!LED1;
}
```

wwdg.h

```c
#ifndef _WWDG_H
	#define _WWDG_H
	#include "sys.h"
 
	//tr代表T[6:0],计数器值 
	//wr代表W[6:0],窗口值 
	//fprer代表分频系数（WDGTB）,仅最低2位有效 
	//Fwwdg=PCLK1/(4096*2^fprer). 一般PCLK1=42Mhz
	void WWDG_Init(u8 tr,u8 wr,u32 fprer);//WWDG初始化函数声明
	void WWDG_IRQHandler(void);//WWDG中断优先级设定函数声明，一般可以去掉，直接在"wwdg.c"里定义
#endif
```

main.c

```c
#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "led.h"
#include "beep.h"
#include "key.h"

//WWDG相关初始化文件
#include "wwdg.h"

int main(void)
{ 
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//设置系统中断优先级分组2
    
	delay_init(168);//初始化延时函数
	LED_Init();//初始化LED端口
	KEY_Init();//初始化按键
    
    LED0=0;//设置LED初值
	delay_ms(300);
    balabalabala...//其他初始化操作
        
    //在其他初始化程序结束后再启用窗口看门狗防止初始化过程中看门狗启动
    //计数器值为7F,窗口寄存器为5F,分频数为8
    WWDG_Init(0x7F,0X5F,WWDG_Prescaler_8);
    
	while(1)
	{
		LED0=1;//熄灭LED灯
        
        balabalabala...//其他操作，喂狗操作自动完成
	}
}
```