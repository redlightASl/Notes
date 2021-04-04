# PWM DAC

参考[**定时器输出PWM**](https://blog.csdn.net/qq_40500005/article/details/109581996)与[**DAC**](https://blog.csdn.net/qq_40500005/article/details/110382824)部分内容

PWM波形可用分段函数表示如下：



$$
f(x)=\left\{
    \begin{array}{l}
             V_H,kNT \le t \le nT+kNT\\
             V_L,kNT+nT \le t \le NT+kNT
        \end{array}
\right.
$$

将上式傅里叶级数展开得
$$
f(t)=[\frac{n}{N}(V_H-V_L)+V_L] + 2 \frac{V_H-V_L}{\pi}sin(\frac{n}{N} \pi)cos(\frac{2 \pi}{NT}t- \frac{n \pi}{N}k)+ \sum\limits_{i=2}^{\infin}2 \frac{V_H-V_L}{k \pi} \vert sin(\frac{n \pi}{N} k) \vert cos(\frac{2 \pi}{NT}kt-\frac{n \pi}{N}k)
$$
T代表单片机中计数脉冲的基本周期，等于定时器计数频率的倒数，即$T=\frac{1}{f_t}$

N代表PWM波一个周期的计数脉冲个数，$N=ARR-1$

n代表PWM波一个周期中高电平的计数脉冲个数，$n=CCRx$

$V_H$和$V_L$分别地表PWM波的高低电平电压值

k为谐波次数

t为时间



## 对傅里叶变换的分析

第一项：直流分量

可写成$\frac{V_H-V_L}{N} n+V_L$

与n呈线性关系，且直流分量随n从到N，从$V_L$到$V_L+V_H$之间变化，正是电压输出DAC所需要的

第二项：1次谐波

$2 \frac{V_H-V_L}{\pi}sin(\frac{n}{N} \pi)cos(\frac{2 \pi}{NT}t- \frac{n \pi}{N}k)$

幅度和频率有关，$f=\frac{1}{NT}$就是PWM的输出频率

过滤掉1次和此之后的所有谐波则可以得到从PWM波到电压输出DAC的转换

**如果能把1次谐波很好过滤，高次谐波就基本不存在了**

第三项：n次谐波

...

**结论**：通过一个低通滤波器对PWM波进行解调即可得到DAC所需信号

## 对滤波器的设计

得到

$$分辨率_{PWM-DAC}=log_2 N$$

假设n最小变化为1，则N=256时，分辨率就是8位

在stm32f4的16位定时器下，可以得到更高的分辨率，即可以得到更慢的T

在8位分辨率下，一次谐波电压最大值

$$V_{MAX}=\frac{2*3.3}{\pi}$$

要求RC滤波电路提供衰减至少达到

$$-20lg \frac{2.1}{\frac{3.3}{256}}=-44dB$$

在CLK=84MHz时，PWM频率

$f=\frac{84MHz}{256}=328.125kHz$

对低通一阶RC滤波电路，要求截止频率2.07kHz

对二阶RC滤波电路，要求截止频率26.14kHz

代入二阶RC低通滤波器截止频率计算公式

$f_b=\frac{1}{2 \pi RC}$

其中$R_1*C_1=R_2*C_2=RC$

## 作用

用定时器模拟DAC的功能



# 蓝牙模块HC05

使用HC05蓝牙模块可利用stm32串口进行蓝牙连接

需要配合手机/pc蓝牙助手或相关蓝牙软件进行蓝牙配对

 ## 蓝牙模块介绍

1. 引脚
   * VCC、GND：接3.3-5V电源
   * TXD、RXD：接串口，以串口方式进行通信，需要TTL电平，不能直接连RS232电平
   * LED（STATE）：指示模块工作状态，配对成功输出高电平，否则输出低电平
   * KEY：设置蓝牙模块工作模式（透传/配置），用于进入AT‘状态 ，高电平有效，内部下拉

2. 电气参数
   * 工作电压3.3-5V；工作温度-25℃-75℃
   * 配对中工作电流：30-40mA；配对完毕未通信工作电流1-8mA；通信中工作电流5-20mA
   * TTL电平，兼容3.3V/5V单片机
   * 默认波特率9600，最高可到1382400，最低4800
   * 主从一体，默认为从机，通过指令切换
   * 10-20m工作距离

3. 串口模式

* AT指令模式

   * 串口透传通信模式

   两者波特率可以不一样

   AT指令模式将识别所有输入数据为AT指令，完成对应设置

   串口透传通信模式将所有输入的数据视作串口信息发送出去

4. 模块自带一个状态指示灯STA

   模块有三种状态

   * 模块上电同时及之前，KEY=1，STA慢闪，模块进入AT状态，波特率将固定为38400
   * 模块上电同时，KEY悬空或KEY=0，STA快闪，表示进入可配对状态，如果再将KEY=1，模块也会进入AT状态，但STA依旧保持快闪
   * 模块配对成功后，STA间歇快闪

## AT指令集

注意：**==AT指令不区分大小写，均以\r\n结尾==**

进入AT状态的方法：

1. 上电同时或之前将KEY=1，上电后即可进入AT指令状态，波特率锁定在38400（8位数据为，1位停止位），多用于模块初始化设定
2. 模块上电后，将KEY=1，此时模块进入AT指令状态，波特率与通信波特率一致

## 基本指令

   * | 指令名称         | 指令内容                                 | 响应                                   | 参数               |
     | ---------------- | ---------------------------------------- | -------------------------------------- | ------------------ |
     | 测试             | AT                                       | OK                                     |                    |
     | 模块复位（重启） | AT+RESET                                 | OK                                     |                    |
     | 查询软件版本号   | AT+VERSION？                             | +VERSION:\<Param\> OK                  | Param:软件版本号   |
     | 设置设备名称     | AT+NAME=\<Param\>                        | OK                                     | Param:蓝牙设备名称 |
     | 查询设备名称     | AT+NAME?                                 | 1. +NAME:\<Param\> OK-成功；FAIL-失败  | Param默认为HC-05   |
     | 设置配对码       | AT+PSWD+\<Param\>                        | OK                                     | Param:配对码       |
     | 查询配对码       | AT+PSWD?                                 | +PSWD:\<Param\> OK                     | 默认配对码为1234   |
     | 设置串口波特率   | AT+UART=\<Param1\>,\<Param2\>,\<Param3\> | OK                                     | Param1:波特率      |
     | 查询串口波特率   | AT+UART?                                 | +UART=\<Param1\>,\<Param2\>,\<Param3\> |                    |

**指令结构**

**AT+\<CMD\>\<=Param\>**设置参数格式

**AT+\<CMD\>?**查询参数格式

其中\<CMD\>和\<Param\>都是可选的，但是注意**在结尾发送末尾添加回车符\r\n**，否则模块不会响应

## HC-05的配置与使用

1. 连接硬件设备，注意RX、TX反接
2. 通过KEY=1的方式将模块设置为AT设置状态
3. **发送AT**，检测模块是否正确连接
4. **设置波特率**
5. **设置设备名称和配对码**
6. **检查无误后**结束初始化程序并进行正常串口数据传输
7. 编写串口输出函数
8. 编写串口读取函数（设置10ms定时器，每10ms检测一次缓存区是否为满）
9. 运行模块，开始收发数据、



# 红外遥控器

红外遥控器的编码解码使用定时器输入捕获进行

主流编码为NEC Protocol的PWM（脉冲宽度调制）和Philips RC-5 Protocol的PPM（脉冲位置调制）

这里使用NEC编码的PWM方式

## 硬件配置

红外接收头引脚：面向突出，从左到右依次是 OUT GND 3.3V

可理解为单总线接口

## NEC编码特征

* 8位地址+8位指令长度
* 地址和命令分两次传输，可靠性高
* 使用PWM调制，以发射红外载波的占空比表示0和1
* 载波频率38kHz
* 位时间为1.125ms或2.25ms（以高电平持续时间来区分）

### NEC码位定义

==逻辑1\=560us脉冲（连续载波）+1680us低电平==

==逻辑0\=560us脉冲+560us低电平==

即**接收端收到逻辑1：560usLOW+1680usHIGH；逻辑0：560usLOW+560usHIGH**

### NEC遥控器指令格式

数据格式为

**同步码头**：9msLOW+4.5msHIGH

**地址码**：地址码决定了遥控器控制的是哪一个项目（初始一般设置为0），共8位（8个0）

**地址反码**：对地址码取反

**控制码**：发送的指令

**控制反码**：对控制码取反

反码是为了增加传输可靠性，可用于校验；**上述所有码都为8位数据格式，按照低位在前、高位在后的顺序发送**

上面的基本数据格式持续时间不超过100ms，100ms后，还会收到**连发码**，由9msLOW+2.5msHIGH+0.56msLOW+97.94msHIGH组成

若一帧数据发送完毕后按键仍未松开则发送重复码（即连发码），可以统计连发码的次数来标记按键按下的长短或次数

## 代码实现

1. 开启定时器输入捕获（上升沿捕获、计数频率1MHz、自动装载值10000即溢出时间10ms）
2. 开启定时器输入捕获更新中断和捕获中断
3. 捕获到上升沿时，设置捕获极性为下降沿捕获，为下次捕获下降沿做准备，清空定时器，设置REMOTE_sta为1<<4，标记已经捕获到上升沿
4. 当捕获到下降沿时，将定时器值赋值给REMOTE_DIFF_val，设置捕获极性为上升沿捕获，为下次捕获上升沿做准备，同时判断REMOTE_sta的位4：若为1，说明已捕获过上升沿，接着对REMOTE_DIFF_val判断（1.值在300-800，说明接收到的是数据0；2.值在1400-1800之间，说明接收到的是数据1；2200-2600，说明是连发码；4200-4700，说明是同步码）；为0则说明发生错误
5. 如果发生定时器溢出中断，判断之前是否接收到了同步码，如果接受过且是第一次溢出，则标记完成一次按键信息采集

remote.c

```c
#include "remote.h"

//红外遥控初始化函数
//使用PA8作接收口
void REMOTE_init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	NVIC_InitTypeDef NVIC_InitStructure;
	TIM_TimeBaseInitTypeDef TIM_TimeBaseStructure;
	TIM_ICInitTypeDef TIM_ICInitStructure;
	
  	//使能GPIOA时钟、TIM1时钟
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_TIM1,ENABLE);
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA, ENABLE);
	
	//配置GPIOA8
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_8;//PA8
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AF;//复用功能
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//速度100MHz
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_UP;//内部上拉
  	//应用设置
	GPIO_Init(GPIOF,&GPIO_InitStructure);
	
	//GPIOA8复用为TIM1输入捕获
	GPIO_PinAFConfig(GPIOA,GPIO_PinSource8,GPIO_AF_TIM1);
	
  	//配置TIM1
	TIM_TimeBaseStructure.TIM_Prescaler=167;//定时器分频168
	TIM_TimeBaseStructure.TIM_CounterMode=TIM_CounterMode_Up;//向上计数模式
	TIM_TimeBaseStructure.TIM_Period=9999;//自动重装载值10000
	TIM_TimeBaseStructure.TIM_ClockDivision=TIM_CKD_DIV1;//默认1分频
	//应用设置
	TIM_TimeBaseInit(TIM1,&TIM_TimeBaseStructure);
	
	//配置TIM1输入捕获
	TIM_ICInitStructure.TIM_Channel=TIM_Channel_1;//CC1S=01 选择输入端->IC1映射到TI1上
  	TIM_ICInitStructure.TIM_ICPolarity=TIM_ICPolarity_Rising;//上升沿捕获
  	TIM_ICInitStructure.TIM_ICSelection=TIM_ICSelection_DirectTI;//映射到TI1上
 	TIM_ICInitStructure.TIM_ICPrescaler=TIM_ICPSC_DIV1;//配置输入分频->不分频 
 	TIM_ICInitStructure.TIM_ICFilter=0x03;//设置IC1F=0003 即 8个定时器时钟周期滤波
  	//应用设置
  	TIM_ICInit(TIM1, &TIM_ICInitStructure);
  
	TIM_ITConfig(TIM1,TIM_IT_Update|TIM_IT_CC1,ENABLE);//允许溢出更新中断、允许CC1IE捕获中断
	TIM_Cmd(TIM14, ENABLE);//使能定时器
	
	//设置捕获更新中断服务函数
  	NVIC_InitStructure.NVIC_IRQChannel=TIM1_CC_IRQn;
	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=1;//抢占优先级1
	NVIC_InitStructure.NVIC_IRQChannelSubPriority=3;//子优先级3
	NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//使能IRQ通道
  	//应用设置
	NVIC_Init(&NVIC_InitStructure);
	
	//设置溢出中断服务函数
  	NVIC_InitStructure.NVIC_IRQChannel=TIM1_UP_TIM10_IRQn;
	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=1;//抢占优先级3
	NVIC_InitStructure.NVIC_IRQChannelSubPriority=3;//子优先级2
	NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//使能IRQ通道
  	//应用设置
	NVIC_Init(&NVIC_InitStructure);
}


/*
遥控器接收标志REMOTE_sta状态
位：7		6		5		4		[3		2		1		0]
功能：收到引导码标志	得到一个按键的所有信息	保留	标记上升沿是否已经被捕获		 溢出计时器
*/
u8 REMOTE_sta=0;//按键状态
u8 REMOTE_counter=0;//按键按下次数
u16 REMOTE_DIFF_val;//下降沿时计数器的值
u32 REMOTE_rec=0;//红外接收到的数据

//TIM1 溢出中断服务函数
//处理溢出判断步骤
void TIM1_UP_TIM10_IRQHandler(void)
{ 		 
	if(TIM_GetITStatus(TIM1,TIM_IT_Update)==SET)//发生溢出中断
	{
		if(REMOTE_sta&0x80)//上次有数据被接收到了
		{
			REMOTE_sta=~0x10;//取消上升沿已被捕获标记
			if((REMOTE_sta&0x0f)==0x00)
				REMOTE_sta|=1<<6;//标记已得到按键的所有信息
		
			//对REMOTE_sta标志的溢出计时器进行累加
			if((REMOTE_sta&0x0f)<14)
				REMOTE_sta++;
			else//表示没有按键被按下
			{
				REMOTE_sta&=~(1<<7);//清空引导标识
				REMOTE_sta&=0xf0;//清空计数器
			}
		}
	}
	TIM_ClearITPendingBit(TIM1,TIM_IT_Update);//清除中断标志位
}

/*
遥控器接收标志REMOTE_sta状态
位：7		6		5		4		[3		2		1		0]
功能：收到引导码标志	得到一个按键的所有信息	保留	标记上升沿是否已经被捕获		 溢出计时器
*/
//TIM1 捕获中断服务函数
//处理正常捕获解码步骤
void TIM1_CC_IRQHandler(void)
{
	if(TIM_GetITStatus(TIM1,TIM_IT_CC1)==SET)//接收到捕获(CC1)中断
	{
		if(RDATA)//上升沿捕获
		{
			TIM_OC1PolarityConfig(TIM1,TIM_ICPolarity_Falling);//设置为下降沿捕获
			TIM_SetCounter(TIM1,0);//清空定时器值
			REMOTE_sta|=0x10;//标记上升沿已经被捕获
		}
		else//下降沿捕获
		{
			REMOTE_DIFF_val=TIM_GetCapture1(TIM1);//保存TIM1的当前值
			TIM_OC1PolarityConfig(TIM1,TIM_ICPolarity_Rising);//设置为上升沿捕获
			
			if(REMOTE_sta&0x10)//已经完成过一次高电平捕获
			{
				if(REMOTE_sta&0x80)//判断是否接收到了同步码，如果是，则开始解析
				{
					if(REMOTE_DIFF_val>300 && REMOTE_DIFF_val<800)//捕获到560us低电平
					{
						REMOTE_rec<<=1;//接收到的数据左移一位
						REMOTE_rec|=0;//接收到0
					}
					else if(REMOTE_DIFF_val>1400 && REMOTE_DIFF_val<1800)//捕获到1680us低电平
					{
						REMOTE_rec<<=1;//接收到的数据左移一位
						REMOTE_rec|=1;//接收到1
					}
					else if(REMOTE_DIFF_val>2200 && REMOTE_DIFF_val<2600)//得到连发码 捕获到2500us低电平
					{
						REMOTE_counter++;//按键次数计数器增1
						REMOTE_sta&=0xf0;//清空计时器
					}
				}
				else if(REMOTE_DIFF_val>4200 && REMOTE_DIFF_val<4700)//如果不是，则开始获取同步码 捕获到4500us低电平
				{
					REMOTE_sta|=1<<7;//标记成功接收到同步码
					REMOTE_counter=0;//清除按键次数计数器
				}
			}
			REMOTE_sta&=~(1<<4);
		}
	}
	TIM_ClearITPendingBit(TIM1,TIM_IT_CC1);//清除中断标志位
}

//红外遥控按键扫描
//在所有数据接收完以后进行扫描
u8 REMOTE_scan(void)
{
	u8 sta=0;
	u8 t1,t2;
	
	if(REMOTE_sta&(1<<6))//如果已经得到一个按键的所有信息了
	{
		t1=REMOTE_rec>>24;//获得地址码
		t2=(REMOTE_rec>>16)&0xff;//获取地址反码
		
		if((t1==(u8)~t2) && t1==REMOTE_ID)//检验遥控识别码和地址
		{
			t1=REMOTE_rec>>8;
			t2=REMOTE_rec;
			if(t1==(u8)~t2)
				sta=1;//判断为键值正确
		}
		
		if((sta==0) || ((REMOTE_sta&0x80)==0))//若按键数据错误 或 遥控按键不再按下
		{
			REMOTE_sta&=~(1<<6);//清除接收到的有效按键标识
			REMOTE_counter=0;//清空按键次数计数器
		}
	}
	return sta;
}
```

remote.h

```c
#ifndef __REMOTE_H
	#define __REMOTE_H
	#include "sys.h"
	
	#define RDATA PAin(8)//PA8为红外信号输入端
	
	//红外遥控识别码
	#define REMOTE_ID 0
	
	extern u8 REMOTE_counter;//按键按下次数
	
	void REMOTE_init(void);//红外接收初始化函数
	u8 REMOTE_scan(void);//红外按键扫描函数
#endif
```



