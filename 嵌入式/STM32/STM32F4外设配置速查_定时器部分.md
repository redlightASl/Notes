## 通用定时器

#### 定时器区别

| 定时器种类               | 位数 | 计数器模式 | 产生DMA请求 | 捕获/比较通道 | 互补输出 | 特殊应用场景                                  |
| ------------------------ | ---- | ---------- | ----------- | ------------- | -------- | --------------------------------------------- |
| 高级定时器（TIM1、TIM8） | 16   | 向上向下   | 可以        | 4             | 有       | 带可编程死区的互补输出                        |
| 通用定时器（TIM2、TIM5） | 32   | 向上向下   | 可以        | 4             | 无       | 通用（定时计数、PWM输出、输入捕获、输出比较） |
| 通用定时器（TIM3、TIM4） | 16   | 向上向下   | 可以        | 4             | 无       | 通用（定时计数、PWM输出、输入捕获、输出比较） |
| 通用定时器（TIM9-TIM14） | 16   | 向上       | 没有        | 2             | 无       | 通用（定时计数、PWM输出、输入捕获、输出比较） |
| 基本定时器（TIM6、TIM7） | 16   | 向上向下   | 可以        | 0             | 无       | 主要用于驱动DAC                               |



通用定时器（TIM2-TIM5）支持各种计数模式、自动装载；由16位可编程（可实时修改）预分频器提供时钟频率，分频系数为1-65535之间的任意数值

有四个独立通道可进行输入捕获、输出比较、PWM生成、单脉冲模式输出

在以下事件发生时**产生中断/DMA请求**，请求由6个独立的IRQ/DMA请求生成器控制：1.更新（计数器溢出、初始化）；2.触发事件（计数器启动/停止/初始化或者由内部、外部触发计数）；3.输入捕获；4.输出比较；5.支持针对定位的增量（正交）编码器和霍尔传感器电路；6.触发输入作为外部时钟或者按周期的电流管理

#### 计数器模式

1. 向上计数

   计数器从0计数到自动加载值（TIMx_ARR），然后重新从0开始计数并产生一个计数器溢出事件

2. 向下计数

   计数器从自动装入的值向下计数到0，然后从自动装入的值重新开始，并产生一个计数器向下溢出事件

3. 中央对齐模式（向上/向下计数）

   计数器从0开始到自动装入的值-1，然后产生一个计数器溢出事件A，然后向下计数到1并且产生一个计数器溢出事件B；然后再从0开始重新计数

#### 定时器中断(使用内部时钟)

定时器溢出时间计算方法：
$$
T_{out}=\frac{(ARR+1)(PSC+1)}{F_t}
$$
$$T_{out}$$单位：秒s

$$F_t$$为定时器工作频率，单位Mhz

ARR：自动重装值

PSC：时钟预分频系数



注意：使用定时器需引用stm32f4xx_tim.c在FWLIB文件夹中

timer.c

```c
#include "timer.h"
#include "led.h"

//通用定时器3中断初始化
//arr：自动重装值。由16位寄存器控制
//psc：时钟预分频数。由16位寄存器控制
void TIM3_Int_Init(u16 arr,u16 psc)
{
    //1. 使能TIM3时钟
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM3,ENABLE); 
	
    //2. 定义定时器初始化结构体
	TIM_TimeBaseInitTypeDef TIM_TimeBaseInitStructure;
    
    //3. 定义NVIC初始化结构体
    NVIC_InitTypeDef NVIC_InitStructure;
    
    //4. 配置定时器设置
  	TIM_TimeBaseInitStructure.TIM_Period=arr;//设置自动重装载值
	TIM_TimeBaseInitStructure.TIM_Prescaler=psc;//设置定时器分频
	TIM_TimeBaseInitStructure.TIM_CounterMode=TIM_CounterMode_Up;//选用向上计数模式
	TIM_TimeBaseInitStructure.TIM_ClockDivision=TIM_CKD_DIV1;//设置定时器分频状态，如果设置不为1的时候默认为2
    //应用设置
	TIM_TimeBaseInit(TIM3,&TIM_TimeBaseInitStructure);
    //TIM_TimeBaseInit参数1为选用哪个定时器，参数2为定时器初始化结构体取址
	
    //5. 开启TIM3定时器中断调用
	TIM_ITConfig(TIM3,TIM_IT_Update,ENABLE);
    //TIM_ITConfig参数1为选用哪个定时器，参数2为定时器状态标志位，参数3为开启
    
    //6. 设置中断优先级
	NVIC_InitStructure.NVIC_IRQChannel=TIM3_IRQn;//调用定时器3中断
	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=0x01;//抢占优先级1
	NVIC_InitStructure.NVIC_IRQChannelSubPriority=0x03;//子优先级3
	NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;
    //应用中断优先级
	NVIC_Init(&NVIC_InitStructure);
	
    //6. 使能定时器3
	TIM_Cmd(TIM3,ENABLE);
}

//7. 编写定时器3中断服务函数
//用TIM_GetITStatus(定时器号,定时器状态标志位)获取定时器状态 来 判断定时器是否溢出
void TIM3_IRQHandler(void)
{
	if(TIM_GetITStatus(TIM3,TIM_IT_Update)==SET)//溢出中断
	{
		LED1=!LED1;//DS1翻转
        
        balabalabala...
	}
    
	TIM_ClearITPendingBit(TIM3,TIM_IT_Update);//清除中断标志位以便进行下一轮计时
}
```

timer.h

```c
#ifndef _TIMER_H
	#define _TIMER_H
	#include "sys.h"

	//arr：自动重装值。
	//psc：时钟预分频数
	void TIM3_Int_Init(u16 arr,u16 psc);//定时器初始化函数声明，以ARR、PSC寄存器的值为输入变量
#endif
```

main.c

```c
#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "led.h"

#include "timer.h"//8. 调用timer.h头文件

int main(void)
{ 
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//设置系统中断优先级分组2
	delay_init(168);//初始化延时函数
	LED_Init();//初始化LED端口

    //9. 启用定时器
    //定时器时钟84M，分频系数8400，所以84M/8400=10Khz的计数频率，计数5000次为500ms
 	TIM3_Int_Init(5000-1,8400-1);
    
	while(1)
	{
		LED0=!LED0;//DS0翻转
		delay_ms(200);//延时200ms
	}
}
```

#### 定时器输入输出(使用内部时钟进行PWM输出)

PWM模式1：向上/向下计数时，只要TIMx_CNT<TIMx_CCR1时，通道1为有效电平，否则为无效电平

PWM模式2：向上/向下计数时，只要TIMx_CNT>TIMx_CCR1时，通道1为有效电平，否则为无效电平

“有效电平”极性由CCER寄存器CC1P位决定：0高电平有效；1低电平有效

**频率（周期）由ARR决定，占空比由CCRx决定**

pwm.c

```c
#include "pwm.h"
#include "led.h"
#include "usart.h"

//arr：自动重装值。由16位寄存器控制
//psc：时钟预分频数。由16位寄存器控制
void TIM14_PWM_Init(u32 arr,u32 psc)//定时器PWM输出初始化函数定义
{
    //1. 使能GPIOF时钟
    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOF,ENABLE);
    
	GPIO_InitTypeDef GPIO_InitStructure;//定义GPIO初始化结构体
    
    //2. 配置GPIO
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_9;//GPIOF9
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;//复用功能
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//速度100MHz
	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽复用输出
	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//内部上拉
    //应用设置
	GPIO_Init(GPIOF,&GPIO_InitStructure);
    
    //3. 使能TIM14时钟
    RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM14,ENABLE);
    
	TIM_TimeBaseInitTypeDef TIM_TimeBaseStructure;//定义定时器初始化结构体
  
    //4. 配置定时器14 基本设置
	TIM_TimeBaseStructure.TIM_Prescaler=psc;//定时器分频
	TIM_TimeBaseStructure.TIM_CounterMode=TIM_CounterMode_Up;//向上计数模式
	TIM_TimeBaseStructure.TIM_Period=arr;//自动重装载值
	TIM_TimeBaseStructure.TIM_ClockDivision=TIM_CKD_DIV1;//设置分频状态，如果设置不为1的时候默认为2
	//应用设置
	TIM_TimeBaseInit(TIM14,&TIM_TimeBaseStructure);
	
    TIM_OCInitTypeDef TIM_OCInitStructure;//定义定时器PWM输出初始化结构体
    
	//5. 配置定时器14 PWM输出设置
	TIM_OCInitStructure.TIM_OCMode=TIM_OCMode_PWM1; //选择模式1（TIMx_CNT<TIMx_CCR1有效）
    //6. 使能比较输出
 	TIM_OCInitStructure.TIM_OutputState=TIM_OutputState_Enable;
	TIM_OCInitStructure.TIM_OCPolarity=TIM_OCPolarity_Low;//设置输出极性：低电平为有效电平
    //应用设置
	TIM_OC1Init(TIM14,&TIM_OCInitStructure);
    /*综合上述设置，当TIMx_CNT<TIMx_CCR1时输出低电平，否则输出高电平*/

    //7. 使能TIM14在CCR1上的预装载寄存器
	TIM_OC1PreloadConfig(TIM14,TIM_OCPreload_Enable);
 
    //8. GPIOF9复用映射为定时器14输出口
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource9,GPIO_AF_TIM14);
    
    //9. 使能ARPE
  	TIM_ARRPreloadConfig(TIM14,ENABLE);
	
    //10. 使能TIM14
	TIM_Cmd(TIM14, ENABLE);			  
}  
```

pwm.h

```c
#ifndef _TIMER_H
	#define _TIMER_H
	#include "sys.h"

	//定时器PWM输出初始化函数声明
	void TIM14_PWM_Init(u32 arr,u32 psc);
#endif
/*与上面的定时器配置一样*/
```

main.c

```c
#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "led.h"

#include "pwm.h"//11. 调用pwm.h头文件

int main(void)
{ 
	u16 led0_TIM14_PWM_val=0;//定义pwm比较值
	u8 dir=1;
    
    //未用到中断，但为保证代码一致性保留此语句，如果需要节省片上内存空间可删去
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//设置系统中断优先级分组2
    
	delay_init(168);//初始化延时函数
    
    //TIM14初始化
    //84M/84=1Mhz的计数频率，重装载值500，所以PWM频率为 1M/500=2Khz
 	TIM14_PWM_Init(500-1,84-1);
    
   	while(1)//比较值从0-300递增，到300后从300-0递减，循环
	{
 		delay_ms(10);
        
		if(dir)
            led0_TIM14_PWM_val++;//dir==1 led0pwmval递增
		else
            led0_TIM14_PWM_val--;	//dir==0 led0pwmval递减 
 		if(led0_TIM14_PWM_val>300)
            dir=0;//led0pwmval到达300后，方向为递减
		if(led0_TIM14_PWM_val==0)
            dir=1;//led0pwmval递减到0后，方向改为递增
 
		TIM_SetCompare1(TIM14,led0_TIM14_PWM_val);//修改比较值，修改占空比
	}
}
```

#### 定时器输入捕获

i_c_.h

```c
#ifndef __TIMERIC_H
	#define __TIMERIC_H
	#include "sys.h"
	
	//定时器PWM输出初始化函数声明
	void TIM14_PWM_Init(u32 arr,u32 psc);
	//定时器输入捕获初始化函数声明
	void TIM5_CH1_Cap_Init(u32 arr,u16 psc);

#endif
```

i_c_.c

```c
#include "led.h"
#include "usart.h"
#include "i_c_.h"

//TIM14 PWM初始化函数定义
//arr：自动重装值	psc：时钟预分频数
void TIM14_PWM_Init(u32 arr,u32 psc)
{
    //3. 定义GPIO结构体、定时器配置结构体、定时器PWM输出结构体
	GPIO_InitTypeDef GPIO_InitStructure;
	TIM_TimeBaseInitTypeDef TIM_TimeBaseStructure;
	TIM_OCInitTypeDef TIM_OCInitStructure;
	
    //1. 使能TIM14时钟
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM14,ENABLE);
    //2. 使能GPIOF时钟
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOF, ENABLE);
	
    //4. 配置GPIOF9 复用为 TIM14输出
	GPIO_PinAFConfig(GPIOF,GPIO_PinSource9,GPIO_AF_TIM14);
	
    //5.1 配置GPIO
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_9;//GPIOA9 
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;//复用功能
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//速度100MHz
	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽复用输出
	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//内部上拉
    //应用设置
	GPIO_Init(GPIOF,&GPIO_InitStructure);
	
    //5.2 配置TIM14
	TIM_TimeBaseStructure.TIM_Prescaler=psc;//定时器分频由初始化函数传入
	TIM_TimeBaseStructure.TIM_CounterMode=TIM_CounterMode_Up;//向上计数模式
	TIM_TimeBaseStructure.TIM_Period=arr;//自动重装载值由初始化函数传入
	TIM_TimeBaseStructure.TIM_ClockDivision=TIM_CKD_DIV1;
	//应用设置
	TIM_TimeBaseInit(TIM14,&TIM_TimeBaseStructure);
	
	//5.3 配置TIM14 Channel1 PWM模式
	TIM_OCInitStructure.TIM_OCMode=TIM_OCMode_PWM1;//选择定时器模式:TIM脉冲宽度调制模式2
 	TIM_OCInitStructure.TIM_OutputState=TIM_OutputState_Enable;//比较输出使能
	TIM_OCInitStructure.TIM_OCPolarity=TIM_OCPolarity_Low;//设置低电平为有效电平
	TIM_OCInitStructure.TIM_Pulse=0;
    //应用设置
	TIM_OC1Init(TIM14,&TIM_OCInitStructure);

    //6. 使能TIM3在CCR2上的预装载寄存器
	TIM_OC2PreloadConfig(TIM14, TIM_OCPreload_Enable);
 
    //7. 使能ARPE
  	TIM_ARRPreloadConfig(TIM14,ENABLE);
	
    //8. 使能TIM14
	TIM_Cmd(TIM14, ENABLE);
}  

TIM_ICInitTypeDef  TIM5_ICInitStructure;


//TIM5 通道1 IC(input capture)配置
//arr：自动重装值(注意：TIM2,TIM5是32位的)	psc：时钟预分频数
void TIM5_CH1_Cap_Init(u32 arr,u16 psc)
{
    //3. 定义GPIO结构体、定时器配置结构体、NVIC配置结构体
	GPIO_InitTypeDef GPIO_InitStructure;
	TIM_TimeBaseInitTypeDef TIM_TimeBaseStructure;
	NVIC_InitTypeDef NVIC_InitStructure;

	//1. 使能TIM5时钟
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM5,ENABLE);
    
    //2. 使能GPIOA时钟
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA, ENABLE);
	
    //3. 设置GPIO
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0;//选用引脚GPIOA0
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;//设置引脚为复用功能
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//速度100MHz
	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽复用输出
	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_DOWN;//内部下拉	未按下时置低电平
    //应用设置
	GPIO_Init(GPIOA,&GPIO_InitStructure);

    //4. 映射GPIOA0复用为定时器5输出引脚
	GPIO_PinAFConfig(GPIOA,GPIO_PinSource0,GPIO_AF_TIM5);
  
    //5. 配置TIM5
	TIM_TimeBaseStructure.TIM_Prescaler=psc;//定时器分频值由函数传入
	TIM_TimeBaseStructure.TIM_CounterMode=TIM_CounterMode_Up;//向上计数模式
	TIM_TimeBaseStructure.TIM_Period=arr;//自动重装载值由函数传入
	TIM_TimeBaseStructure.TIM_ClockDivision=TIM_CKD_DIV1;
	//应用设置
	TIM_TimeBaseInit(TIM5,&TIM_TimeBaseStructure);
	
	//6. 初始化TIM5输入捕获参数
	TIM5_ICInitStructure.TIM_Channel=TIM_Channel_1;//6.3 CC1S=01 选择输入端->IC1映射到TI1上
  	TIM5_ICInitStructure.TIM_ICPolarity=TIM_ICPolarity_Rising;//6.2上升沿捕获
  	TIM5_ICInitStructure.TIM_ICSelection=TIM_ICSelection_DirectTI;//6.4 映射到TI1上
  	TIM5_ICInitStructure.TIM_ICPrescaler=TIM_ICPSC_DIV1;//6.5 配置输入分频->不分频 
  	TIM5_ICInitStructure.TIM_ICFilter=0x00;//6.1 设置IC1F=0000 即 配置输入滤波器->不滤波
    //应用设置
  	TIM_ICInit(TIM5, &TIM5_ICInitStructure);
		
    //7.1 允许 更新中断 
    //7.2 允许 CC1IE捕获中断
	TIM_ITConfig(TIM5,TIM_IT_Update|TIM_IT_CC1,ENABLE);	
	
    //8. 使能定时器5
  	TIM_Cmd(TIM5,ENABLE);

    //9. 设置中断服务函数
  	NVIC_InitStructure.NVIC_IRQChannel=TIM5_IRQn;
	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=2;//抢占优先级3
	NVIC_InitStructure.NVIC_IRQChannelSubPriority=0;//子优先级3
	NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//使能IRQ通道
    //应用设置
	NVIC_Init(&NVIC_InitStructure);
}


/*
捕获状态
[7]:0,没有成功捕获;1,成功捕获到一次
[6]:0,还没捕获到低电平;1,已经捕获到低电平
[5:0]:捕获低电平后溢出的次数(对于32位定时器来说,1us计数器加1,溢出时间:4294秒)
*/
u8  TIM5CH1_CAPTURE_STA=0;//输入捕获状态		    				
u32	TIM5CH1_CAPTURE_VAL;//输入捕获值(TIM2/TIM5是32位)

//TIM5 中断服务函数
void TIM5_IRQHandler(void)
{ 		    
 	if((TIM5CH1_CAPTURE_STA&0X80)==0)//如果还未成功捕获（标志位为空）
	{
		if(TIM_GetITStatus(TIM5,TIM_IT_Update)!=RESET)//且发生TIM5溢出 即 TIM_IT_Update
		{	     
			if(TIM5CH1_CAPTURE_STA&0X40)//且已经捕获到高电平
			{
				if((TIM5CH1_CAPTURE_STA&0X3F)==0X3F)//说明高电平太长了（按键时间太长，定时器溢出）
				{
					TIM5CH1_CAPTURE_STA|=0X80;//标记“成功捕获了一次”
					TIM5CH1_CAPTURE_VAL=0XFFFFFFFF;//标记高电平值
				}
                else
                    TIM5CH1_CAPTURE_STA++;
			}	 
		}
		if(TIM_GetITStatus(TIM5,TIM_IT_CC1)!=RESET)//且TIM5发生捕获事件
		{	
			if(TIM5CH1_CAPTURE_STA&0X40)//且如果捕获到一个下降沿 		
			{	  			
				TIM5CH1_CAPTURE_STA|=0X80;//那么标记成功捕获到一次高电平脉宽
			  	TIM5CH1_CAPTURE_VAL=TIM_GetCapture1(TIM5);//并获取当前的捕获值
	 			TIM_OC1PolarityConfig(TIM5,TIM_ICPolarity_Rising);//CC1P=0设置为上升沿捕获
                //为下一次捕获做准备
			}
            else//但还未捕获到下降沿,第一次捕获上升沿
			{
			 	TIM5CH1_CAPTURE_STA=0;//那么清空标志位
				TIM5CH1_CAPTURE_VAL=0;//清空取值位
				TIM5CH1_CAPTURE_STA|=0X40;//然后标记捕获到了上升沿
				TIM_Cmd(TIM5,DISABLE );//关闭TIM5
	 			TIM_SetCounter(TIM5,0);//重新设置TIM5计时
	 			TIM_OC1PolarityConfig(TIM5,TIM_ICPolarity_Falling);//CC1P=1设置为下降沿捕获
				TIM_Cmd(TIM5,ENABLE ); 	//使能定时器5
			}		    
		}			     	    					   
 	}
	TIM_ClearITPendingBit(TIM5, TIM_IT_CC1|TIM_IT_Update);//最后清除中断标志位
}
```

mian.c

```c
#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "led.h"
#include "i_c_.h"

extern u8  TIM5CH1_CAPTURE_STA;//输入捕获状态		    				
extern u32	TIM5CH1_CAPTURE_VAL;//输入捕获值  

int main(void)
{ 
	long long temp=0;
    
    //设置系统中断优先级分组2
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);
    
	delay_init(168);//初始化延时函数
	uart_init(115200);//初始化串口波特率为115200
	
    //84M/84=1Mhz的计数频率计数到500,PWM频率为1M/500=2Khz 
    //初始化TIM14 PWM
 	TIM14_PWM_Init(500-1,84-1);
    
    //初始化TIM5 IC ，以1Mhz的频率计数 ，最大化计数时间
 	TIM5_CH1_Cap_Init(0XFFFFFFFF,84-1);
    
   	while(1)
	{
        //PWM输出比较
 		delay_ms(10);
		TIM_SetCompare1(TIM14,TIM_GetCapture1(TIM14)+1); 
		if(TIM_GetCapture1(TIM14)==300)TIM_SetCompare1(TIM14,0);
            
        
 		if(TIM5CH1_CAPTURE_STA&0X80)//如果成功捕获到了一次高电平
		{
			temp=TIM5CH1_CAPTURE_STA&0X3F;//设置TIM5IC初始状态
			temp*=0XFFFFFFFF;//溢出时间总和
			temp+=TIM5CH1_CAPTURE_VAL;//对每次高电平时间求和，得到总的高电平时间
			
            printf("HIGH:%lld us\r\n",temp);//串口打印总的高电平时间
            
			TIM5CH1_CAPTURE_STA=0;//开启下一次捕获
		}
	}
}
```