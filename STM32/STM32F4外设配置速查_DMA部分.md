# STM32F4 DMA（直接内存存取）

## DMA原理

DMA即Direct Memory Access 直接存储器访问：将数据从一个地址复制到另一个地址，当CPU初始化DMA控制器后，传输动作**由DMA控制器实现和完成**

优点：**无需**CPU控制 或 中断压栈-出栈过程，让RAM与IO设备间可快速传输数据，减少CPU负载

## stm32f4资源

1. 双AHB总线，一个用于存储器访问，一个用于外设访问

2. 编程接口仅支持32位访问的AHB使用DMA

3. 最多2个DMA控制器，总共2*8=**16个数据流**，每个DMA控制器用于管理一个或多个外设的访问请求，每个数据流总共可以有**8个通道**（或请求），每个通道都有一个**仲裁器**处理DMA优先级

4. 每个数据流都有单独的四级32位FIFO，可用于FIFO模式或直接模式，支持循环缓冲区管理

   * FIFO模式：可通过**软件**将阈值级别选取为FIFO大小的1/4、1/2、3/4

     ==FIFO可视为先入者先出的缓存==

     FIFO下，独立的源和目标传输宽度（字节8bit、半字16bit、字32bit）、源和目标的数据宽度不相等时，DMA自动封装/解封必要的传输数据来优化带宽

   * 直接模式：每个DMA请求立即启动对存储器的传输。

     直接模式下，将DMA请求配置为以存储器到外设模式传输数据时，DMA仅将**一个数据**从存储器预加载进FIFO，一旦外设触发DMA请求时立即传输数据

5. DMA硬件配置：

   * 外设>>存储器

     存储器通过外设端口进行访问，所以外设与存储器可以互相访问

   * 存储器>>外设

   * 存储器>>存储器；

   * 存储器1>>双缓冲区 然后 存储器2>>双缓冲区 同时 双缓冲区（填充了存储器1的数据）>>外设1 然后 双缓冲区（填充了存储器2的数据）>>外设1 同时 存储器1>>双缓冲区 （双缓冲）

     双缓冲模式下有两个存储器指针，==每次传输结束时，DMA从一个存储器目标交换为另一个存储器目标==，软件在处理一个存储器区域的同时，DMA还会填充/使用第二个存储器区域，所以==双缓冲数据流可以双向工作（存储器既可以是源也可以是目标）==

6. 要传输的数据数目由DMA或外设管理
   * DMA流控制器：传输数据数目1到65535，可用软件编程
   * 外设流控制器：传输数据项数目未知，由源或目标外设控制，通过硬件发出传输结束的信号

7. 支持4个、8个、16个节拍的增量突发传输
   
* 突发增量的大小可由软件配置，通常等于外设FIFO大小的1/2
   
8. 循环模式
   * 用于处理循环缓冲区和连续数据流（如ADC扫描模式）
   * 要传输的数据项的数目在数据流配置时自动用DMA设置的初始值加载，持续响应DMA请求
   * 从第0位连续传输n位到n-1位或发生硬件清零后回到第0位，重新传输n位，**循环往复**

## DMA中断

对每个DMA数据流，在

1. 达到半传输
2. 传输完成
3. 传输错误
4. FIFO错误（上溢、下溢、FIFO级别错误）
5. 直接模式错误

时，会产生中断，可使用单独的中断使能位以实现灵活性

* DMA配置流程

1.将先前的数据块DMA传输在状态寄存器中置1的所有数据流专用的位 置0

2.重新使能数据流

3.设置外设端口寄存器地址

4.设置存储器地址

5.配置要传输的数据项总数，每出现一次外设时间或一个节拍的突发传输，该值就会递减

6.选择DMA通道

7.设置外设用作流控制器

8.配置数据流优先级

9.配置FIFO使用情况

10.配置数据传输方向

11.配置外设和存储器模式、突发事件、数据宽度、循环模式、双缓冲区模式、特殊情况中断等

12.使能数据流

只要使能数据流后即可响应连接到数据流的外设发出的任何DMA请求

* DMA库函数配置流程

1.使能DMA时钟

2.初始化DMA通道参数

3.使能串口DMA发送

4.查询DMA的EN位，确保数据流就绪，可以配置

5.设置通道当前剩余数据量

6.使能DMA1通道，启动传输

7.查询DMA传输状态

8.获取/设置通道当前剩余数据量



dma.c

```c
#include "dma.h"

//DMA_Streamx表示DMA数据流，只能选择DMA1或DMA2
//chx表示通道数
//par表示外设地址
//mar表示存储器地址
//ndtr表示数据传输量
void DMA_config(DMA_Stream_TypeDef* DMA_streamx,u32 chx,u32 par,u32 mar,u16 ndtr)
{
	DMA_InitTypeDef DMA_InitStructure;
	
	//得到当前stream属于DMA1还是DMA2
	if((u32)DMA_streamx>(u32)DMA2)
		RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_DMA2,ENABLE);
	else
		RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_DMA1,ENABLE);
	
	//1. 将先前的数据块DMA传输在状态寄存器中置1的所有数据流专用的位 置0
	DMA_DeInit(DMA_streamx);
	
	//2. 查询DMA的EN位，确保数据流就绪，等待配置
	while(DMA_GetCmdStatus(DMA_streamx)!=DISABLE){}
		
	//3. 设置DMA属性
	DMA_InitStructure.DMA_Channel=chx;//选择通道
	DMA_InitStructure.DMA_PeripheralBaseAddr=par;//外设地址
	DMA_InitStructure.DMA_Memory0BaseAddr=mar;//DMA 存储器0地址
		
	DMA_InitStructure.DMA_DIR=DMA_DIR_MemoryToPeripheral;//选择模式：存储器mar>>外设par
		
	DMA_InitStructure.DMA_BufferSize=ndtr;//数据传输量
		
	DMA_InitStructure.DMA_PeripheralInc=DMA_PeripheralInc_Disable;//外设增量模式关闭
	DMA_InitStructure.DMA_MemoryInc=DMA_MemoryInc_Enable;;//存储器增量模式开启
	DMA_InitStructure.DMA_MemoryDataSize=DMA_PeripheralDataSize_Byte;//存储器数据长度：字节模式（8位）
		
	DMA_InitStructure.DMA_Mode=DMA_Mode_Normal;//普通模式
		
	DMA_InitStructure.DMA_Priority=DMA_Priority_Medium;//中等优先级
		
	DMA_InitStructure.DMA_FIFOMode=DMA_FIFOMode_Disable;//FIFO模式：不使用FIFO
	DMA_InitStructure.DMA_FIFOThreshold=DMA_FIFOThreshold_Full;//FIFO阈值设置：全满时停止加入FIFO
		
	DMA_InitStructure.DMA_MemoryBurst=DMA_MemoryBurst_Single;//存储器突发单次传输
	DMA_InitStructure.DMA_PeripheralBurst=DMA_PeripheralBurst_Single;//外设突发单次传输
	
	//应用设置
	DMA_Init(DMA_streamx,&DMA_InitStructure);
}


void DMA_enable(DMA_Stream_TypeDef* DMA_streamx,u16 ndtr)
{
	//4. 关闭DMA传输
	DMA_Cmd(DMA_streamx,DISABLE);
	
	//5. 等待DMA可以被设置
	while(DMA_GetCmdStatus(DMA_streamx)!=DISABLE){}

	//6. 设置数据传输量
	DMA_SetCurrDataCounter(DMA_streamx,ndtr);
		
	//7. 开启DMA传输
	DMA_Cmd(DMA_streamx,ENABLE);
}
```

dma.h

```c
#ifndef __DMA_H
	#define __DMA_H
	#include "sys.h"
	
	void DMA_config(DMA_Stream_TypeDef* DMA_streamx,u32 chx,u32 par,u32 mar,u16 ndtr);//DMA配置函数
	void DMA_enable(DMA_Stream_TypeDef* DMA_streamx,u16 ndtr);//DMA使能函数
	
#endif
```

main.c

```c
#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "dac.h"
#include "dht11.h"
#include "dma.h"

#define SEND_BUF_SIZE 8200	//发送数据长度，最好等于sizeof(TEXT_TOSEND)+2的整数倍

u8 send_buff[SEND_BUF_SIZE];
const u8 TEXT_TO_SEND[]={"DMA test!"};

int main(void)
{
	u16 i;
	u8 t=0;
	u8 j,mask=0;
	float process=0;//进度
	
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//设置系统中断优先级分组2
	
	delay_init(168);//初始化延时函数
	uart_init(115200);//初始化串口波特率115200
	LED_init();
	LCD_init();
	KEY_init();
	
	//设置DMA：USART->DR >>DMA_Channel_4>> send_buff
	DMA_config(DMA2_Stream7,DMA_Channel_4,(u32)&USART1->DR,(u32)send_buff,SEND_BUF_SIZE);
	
	j=sizeof(TEXT_TO_SEND)
		
	//填充TEXT_TO_SEND到send_buff[]
	for(i=0;i<SEND_BUF_SIZE;i++)
	{
		if(t>=j)//加入换行符
		{
			if(mask)
			{
				send_buff[i]=0x0a;
				t=0;
			}
			else
			{
				send_buff[i]=0x0d;
				mask++;
			}
		}
		else
		{
			mask=0;
			send_buff[i]=TEXT_TO_SEND[t];
			t++;
		}
	}
	
	i=0;
	while(1)
	{
		t=KEY_scan(0);
		if(t==KEY0_PRES)//KEY0按下
		{
			printf("\r\nDMA DATA:\r\n");
			LCD_ShowString(20,150,200,16,16,"Start Transimit...");
			LCD_ShowString(30,170,200,16,16,"%");//显示进度百分号
		
			//开启一次DMA传输
			USART_DMACmd(USART1,USART_DMAReq_Tx,ENABLE);
		
			//等待DMA传输完成，在此期间可以执行其他任务
			while(1)
			{
				if(DMA_GetCmdStatus(DMA2_Stream7,DMA_FLAG_TCIF7)!=RESET)
				{
					DMA_ClearFlag(DMA2_Stream7,DMA_FLAG_TCIF7);
					break;
				}
			
				process=DMA_GetCurrDataCounter(DMA2_Stream7);//得到当前剩余数据数量
				process=1-process/SEND_BUF_SIZE;//得到百分比
				process*=100;//扩大100倍进行显示
				LCD_ShowNum(30,170,100,3,16);
			}
			
			LCD_ShowNum(30,170,100,3,16);//显示100%
			LCD_ShowString(20,150,200,16,16,"Tansimit Finished!");//提示传输完成
		}
		
		i++;
		delay_ms(10);
		
		if(i==20)
		{
			LED0=!LED0;
			i=0;
		}
	}
}
```
