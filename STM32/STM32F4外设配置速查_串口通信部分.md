## RS232串口通信

使用简单，参见以下源代码

## 驱动配置


usart.c

```c
#include "sys.h"
#include "usart.h"	


//如果使用ucos,则包括下面的头文件即可.
#if SYSTEM_SUPPORT_OS
	#include "includes.h"					//ucos 使用	  
#endif
//加入以下代码,支持printf函数,而不需要选择use MicroLIB	  
#if 1
	#pragma import(__use_no_semihosting)             
	//标准库需要的支持函数                 
	struct __FILE 
	{ 
		int handle; 
	}; 

	FILE __stdout;       

	//定义_sys_exit()以避免使用半主机模式    
	_sys_exit(int x) 
	{ 
		x = x; 
    } 

	//重定义fputc函数 
	int fputc(int ch, FILE *f)
	{ 	
		while((USART1->SR&0X40)==0);//循环发送,直到发送完毕   
		USART1->DR = (u8) ch;      
		return ch;
	}
#endif


#if EN_USART1_RX//如果使能了接收
	
	//串口1中断服务程序
	//注意,读取USARTx->SR能避免莫名其妙的错误

	u8 USART_RX_BUF[USART_REC_LEN];//接收缓冲,最大USART_REC_LEN个字节.
	
	//接收状态
	//bit15，	接收完成标志
	//bit14，	接收到0x0d
	//bit13~0，	接收到的有效字节数目
	u16 USART_RX_STA=0;//接收状态标记	

	//初始化IO USART1
	//bound:波特率
	void uart_init(u32 bound)
    {
  		GPIO_InitTypeDef GPIO_InitStructure;
		USART_InitTypeDef USART_InitStructure;
        NVIC_InitTypeDef NVIC_InitStructure;
	
        //1. 使能GPIOA时钟
		RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA,ENABLE);
        //2. 使能USART1时钟
		RCC_APB2PeriphClockCmd(RCC_APB2Periph_USART1,ENABLE);

		//3. Usart1对应引脚复用映射
		GPIO_PinAFConfig(GPIOA,GPIO_PinSource9,GPIO_AF_USART1);//GPIOA9复用为USART1
		GPIO_PinAFConfig(GPIOA,GPIO_PinSource10,GPIO_AF_USART1);//GPIOA10复用为USART1
	
		//4. GPIO端口配置
  		GPIO_InitStructure.GPIO_Pin=GPIO_Pin_9|GPIO_Pin_10;//GPIOA9与GPIOA10
		GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AF;//引脚复用
		GPIO_InitStructure.GPIO_Speed=GPIO_Speed_50MHz;//速度50MHz
		GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
		GPIO_InitStructure.GPIO_PuPd= GPIO_PuPd_UP;//内部上拉
        //应用设置
		GPIO_Init(GPIOA,&GPIO_InitStructure);

   		//5. USART1 初始化设置
		USART_InitStructure.USART_BaudRate=bound;//波特率由初始化函数传入参数bound决定
		USART_InitStructure.USART_WordLength=USART_WordLength_8b;//字长为8位数据格式
		USART_InitStructure.USART_StopBits=USART_StopBits_1;//一个停止位
		USART_InitStructure.USART_Parity=USART_Parity_No;//无奇偶校验位
		USART_InitStructure.USART_HardwareFlowControl=USART_HardwareFlowControl_None;//无硬件数据流控制
		USART_InitStructure.USART_Mode=USART_Mode_Rx|USART_Mode_Tx;//收发模式
  		//应用设置
        USART_Init(USART1, &USART_InitStructure);
	
        //6. 使能Usart1
  		USART_Cmd(USART1, ENABLE);
	
		//USART_ClearFlag(USART1, USART_FLAG_TC);
	
	#if EN_USART1_RX//如果未使能串口接收相关配置（无法硬件接收串口通信）
    	//7. 开启Usart相关中断
		USART_ITConfig(USART1,USART_IT_RXNE,ENABLE);

		//8. Usart1中断优先级配置
  		NVIC_InitStructure.NVIC_IRQChannel=USART1_IRQn;//串口1中断通道
		NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=3;//抢占优先级3
		NVIC_InitStructure.NVIC_IRQChannelSubPriority=3;//子优先级3
		NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//IRQ通道使能
        //应用设置
		NVIC_Init(&NVIC_InitStructure);
	#endif
	}

//Usart1中断服务函数
	void USART1_IRQHandler(void)
	{
		u8 Res;
        
        //如果SYSTEM_SUPPORT_OS为真，则需要支持OS
		#if SYSTEM_SUPPORT_OS
			OSIntEnter();    
		#endif
        
        //接收中断
        //即判断串口是否已经接收到了数据(接收到的数据必须是0x0d 0x0a结尾)
        //0x0D为“回车”的ASCII码，0x0A为“换行”的ASCII码
        //接收到数据要求以回车、换行结尾
		if(USART_GetITStatus(USART1,USART_IT_RXNE) != RESET)//判断中断标志位是否接收到了来自串口的中断申请（USART_IT_RXNE类型中断信号）
		{
			Res=USART_ReceiveData(USART1);//(USART1->DR) 即 读取接收到的数据
		
			if((USART_RX_STA&0x8000)==0)//如果接收未完成
			{
				if(USART_RX_STA&0x4000)//且接收到了0x0D
				{
					if(Res!=0x0a)//现在接收到的不是0x0A
                    	USART_RX_STA=0;//那么接收错误,重新开始
					else//现在接收到的是0x0A 
                    	USART_RX_STA|=0x8000;//那么接收完成了 
				}
				else//但没收到0X0D
				{	
					if(Res==0x0d)//如果这次收到的是0x0d
                    	USART_RX_STA|=0x4000;//先标记一下
					else
					{
						USART_RX_BUF[USART_RX_STA&0X3FFF]=Res;//定位到接收数据开头
						USART_RX_STA++;//接收到的有效位+1，往后检查0x0D或0x0A
						if(USART_RX_STA>(USART_REC_LEN-1))
                            USART_RX_STA=0;//接收数据错误,重新开始接收	  
					}		 
				}
			}   		 
  		} 
        
	#if SYSTEM_SUPPORT_OS//如果SYSTEM_SUPPORT_OS为真，则需要支持OS.
		OSIntExit();  											 
	#endif
	} 
#endif	
```

usart.h

```c
#ifndef __USART_H
	#define __USART_H
	#include "stdio.h"	
	#include "stm32f4xx_conf.h"
	#include "sys.h" 

	#define USART_REC_LEN  			200  	//定义最大接收字节数 200
	#define EN_USART1_RX 			1		//使能（1）/禁止（0）串口1接收

	extern u8  USART_RX_BUF[USART_REC_LEN]; //接收缓冲,最大USART_REC_LEN个字节.末字节为换行符 
	extern u16 USART_RX_STA;         		//接收状态标记	
	//如果想串口中断接收，请不要注释以下宏定义

	void uart_init(u32 bound);
#endif
```

key.c

```c
#include "key.h"
#include "delay.h" 

//按键初始化函数
void KEY_Init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;
    
	//1. 使能GPIOA,GPIOE时钟
  	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA|RCC_AHB1Periph_GPIOE, ENABLE);
    
 	//2. 设置一般按钮相关GPIOF
  	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_2|GPIO_Pin_3|GPIO_Pin_4;//设置KEY0 KEY1 KEY2对应引脚
  	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IN;//普通输入模式
  	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//100M
  	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//内部上拉
    //应用GPIO设定
  	GPIO_Init(GPIOE, &GPIO_InitStructure);

    //3. 设置WK_UP按钮相关GPIOA
  	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0;//设置WK_UP对应引脚
  	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_DOWN ;//内部下拉
    //应用GPIO设定
  	GPIO_Init(GPIOA, &GPIO_InitStructure);
} 

//按键处理函数
//返回按键值
//mode==0,不支持连续按;mode==1,支持连续按;
u8 KEY_Scan(u8 mode)
{	 
    
//响应优先级：KEY0>KEY1>KEY2>WK_UP
//0，没有任何按键按下
//1，KEY0按下
//2，KEY1按下
//3，KEY2按下 
//4，WKUP按下 WK_UP
    
	static u8 key_up=1;//按键按松开标志
	if(mode)
        key_up=1;//支持连按		  
    
	if(key_up&&(KEY0==0||KEY1==0||KEY2==0||WK_UP==1))
	{
		delay_ms(10);//按键防抖 
        
		key_up=0;
		if(KEY0==0)
            return 1;
		else if(KEY1==0)
            return 2;
		else if(KEY2==0)
            return 3;
		else if(WK_UP==1)
            return 4;
	}
    else if(KEY0==1&&KEY1==1&&KEY2==1&&WK_UP==0)
        key_up=1;
 	return 0;// 无按键按下
}
```

## 应用

main.c

```c
#include "sys.h"
#include "delay.h"
#include "led.h"
#include "beep.h"
#include "key.h"

#include "usart.h"//开启串口必须引用

int main(void)
{
	u8 t;
	u8 len;	
	u16 times=0;  
	
	delay_init(168);//延时初始化
	LED_Init();//初始化LED_GPIO
    
    NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//设置系统中断优先级分组2
    
    //在引用usart.h情况下，调用此函数即可开启串口  
    uart_init(115200);//串口初始化波特率为115200
    
	while(1)
	{
		if(USART_RX_STA&0x8000)
		{					   
			len=USART_RX_STA&0x3fff;//得到此次接收到的数据长度
			printf("\r\n发送的消息:\r\n");
			for(t=0;t<len;t++)
			{
				USART_SendData(USART1, USART_RX_BUF[t]);//向串口1发送数据
				while(USART_GetFlagStatus(USART1,USART_FLAG_TC)!=SET);//等待发送结束
			}
			printf("\r\n\r\n");//插入换行
			USART_RX_STA=0;
		}
        else
		{
			times++;
			if(times%5000==0)
			{
				printf("experimenting\r\n\r\n\r\n");
			}
			if(times%200==0)
                printf("请输入数据,必须以回车键结束\r\n");
			if(times%30==0)LED0=!LED0;//闪烁LED,提示系统正在运行
			delay_ms(10);   
		}
	}
}
```

# RS485串口通信

串口只是**物理层**的一个标准，没有给定接口插件电缆和使用的协议，**只要使用的接口插件电缆符合串口标准就可以在实际中灵活使用**，在串口接口标准上使用各种协议进行通讯和设备控制

典型串口通信标准是RS232和RS485和RS242，只定义了接口电压、阻抗等物理标准，软件协议可以通用

## RS232的缺陷

1. 接口信号电平较高，易损坏接口电路ic
2. 传输速率较低，异步传输波特率为20Kbps
3. 接口使用一根信号线和一根信号返回线构成共地的传输形式，易产生共模干扰，抗噪声干扰性能弱
4. 传输距离有限，实际使用距离仅在50m左右

## RS485优点

1. 接口电平低，不易损坏ic：两线电压差为+(2\~6)V表示逻辑1；两线电压差为-(2\~6)V表示逻辑0、
2. 10米内传输速率可达35Mbps，在1200m时，传输速率达100Kbps
3. 采用平衡驱动器和差分接收器组合，抗共模干扰能力强，抗噪声性能好
4. 传输距离最长可到1200m以上，一般最大支持32个节点

## 硬件使用

RS485一般是用在点对点网络中，不能用于星型、环型网络

理想状态下RS485需要==2个匹配电阻==，其==阻值要求等于传输电缆的特性阻抗（一般为120Ω）==，否则所有设备都静止时或者没有能量的时候就会产生噪声。同时线移需要双端的电压差，没有终接电阻回使较快速的发送端产生多个数据信号的边缘，导致数据传输出错

接口需要使用**收发器IC SP3485**

Pin1 RO和 Pin4 DI一般连接到MCU串口引脚，Pin6 A和Pin7 B连接到485总线，将232电平转换为485电平

485总线高端线接VCC（上拉），低端线接GND（下拉），保证总线空闲时AB线之间电压差大约200mV，防止总线空闲时逻辑混乱

## 驱动配置

配置RS485之前需要引入库函数stm32f4xx_usart.c文件及其头文件stm32f4xx_usart.h

485.c

```c
#include "485.h"
#include "delay.h"

u8 RS485_TX_EN=0;

#if EN_USART2_RX//如果使能了接收
	u8 RS485_RX_BUF[64];//接收缓冲区，最大64字节
	u8 RS485_RX_CNT=0;//接收到的数据长度
	
	void USART2_IRQAHandler(void)
	{
		u8 res;
		if(USART_GetFlagStatus(USART2,USART_IT_RXNE)!=RESET)//如果接收到数据
		{
			res=USART_ReceiveData(USART2);//读取接收到的数据，从USART2->DR复制至res
			if(RS485_RX_CNT<64)
			{
				RS485_RX_BUF[RS485_RX_CNT]=res;//记录接收到的值
				RS485_RX_CNT++;//接收数据长度+1
			}
		}
	}
#endif

//初始化USART2
//bound表示波特率
void RS485_init(u32 bound)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	USART_InitTypeDef USART_InitStructure;
  	NVIC_InitTypeDef NVIC_InitStructure;
	
  	//1. 使能GPIOA和GPIOG时钟
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA,ENABLE);
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOG,ENABLE);
  	//2. 使能USART2时钟
	RCC_APB2PeriphClockCmd(RCC_APB1Periph_USART2,ENABLE);

	//3. Usart1对应引脚复用映射
	GPIO_PinAFConfig(GPIOA,GPIO_PinSource9,GPIO_AF_USART2);//GPIOA2复用为USART2
	GPIO_PinAFConfig(GPIOA,GPIO_PinSource10,GPIO_AF_USART2);//GPIOA3复用为USART2
	
	//4. 配置PA2、PA3复用为485输出
  	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_2|GPIO_Pin_3;//GPIOA2与GPIOA3
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AF;//引脚复用
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//速度100MHz
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_PuPd= GPIO_PuPd_UP;//内部上拉
  	//应用设置
	GPIO_Init(GPIOA,&GPIO_InitStructure);
	
	//5. 配置PG8推挽输出，控制485接收/发送模式
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_8;//GPIOG8
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_OUT;//输出模式
	//应用设置
	GPIO_Init(GPIOG,&GPIO_InitStructure);

  	//6. USART2 初始化设置
	USART_InitStructure.USART_BaudRate=bound;//波特率由初始化函数传入参数bound决定
	USART_InitStructure.USART_WordLength=USART_WordLength_8b;//字长为8位数据格式
	USART_InitStructure.USART_StopBits=USART_StopBits_1;//一个停止位
	USART_InitStructure.USART_Parity=USART_Parity_No;//无奇偶校验位
	USART_InitStructure.USART_HardwareFlowControl=USART_HardwareFlowControl_None;//无硬件数据流控制
	USART_InitStructure.USART_Mode=USART_Mode_Rx|USART_Mode_Tx;//收发模式
  	//应用设置
  	USART_Init(USART2, &USART_InitStructure);
	
  	//7. 使能Usart1
  	USART_Cmd(USART2, ENABLE);
	//8. 清除USART中断标志位
	USART_ClearFlag(USART2, USART_FLAG_TC);
	
	#if EN_USART2_RX//如果未使能串口接收相关配置（无法硬件接收串口通信）
    //9. 开启Usart2接收中断
		USART_ITConfig(USART2,USART_IT_RXNE,ENABLE);

	//8. Usart2中断优先级配置
  	NVIC_InitStructure.NVIC_IRQChannel=USART2_IRQn;//串口2中断通道
	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=3;//抢占优先级3
	NVIC_InitStructure.NVIC_IRQChannelSubPriority=3;//子优先级3
	NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//IRQ通道使能
    //应用设置
	NVIC_Init(&NVIC_InitStructure);
	#endif
	
	RS485_TX_EN=0;//默认为接收模式
}


//RS485发送len个字节数据
//buf：发送区首地址
//len：发送的字节数（最好不超过64字节）
void RS485_send_data(u8* buf,u8 len)
{
	u8 t;
	RS485_TX_EN=1;//设置为发送模式
	
	for(t=0;t<len;t++)
	{
		while(USART_GetFlagStatus(USART2,USART_FLAG_TC)==RESET)
			;//等待发送结束
		USART_SendData(USART2,buf[t]);
	}
	
	while(USART_GetFlagStatus(USART2,USART_FLAG_TC)==RESET)
		;//等待发送结束
	
	RS485_RX_CNT=0;
	RS485_TX_EN=0;//设置为接收模式
}

//RS485查询接收到的len个字节数据
//buf：接收缓存首地址
//len：读取到的数据长度
void RS485_receive_data(u8* buf,u8* len)
{
	u8 rxlen=RS485_RX_CNT;
	u8 i=0;
	*len=0;//默认读取数据长度为0
	
	delay_ms(10);//等待10ms，连续超过10ms未接收到数据则认为接收结束
	
	if((rxlen==RS485_RX_CNT) && rxlen)//接收到数据 且 接收完成
	{
		for(i=0;i<rxlen;i++)
			buf[i]=RS485_RX_BUF[i];
		*len=RS485_RX_CNT;//记录本次数据长度
		RS485_RX_CNT=0;//计数器清零
	}
}
```

485.h

```c
#ifndef __485_H
	#define __485_H
	#include "sys.h"
	#include "stm32f4xx_usart.h"
	
	#define EN_USART2_RX 1
	extern u8 RS485_TX_EN;
	
	void RS485_init(u32 bound);//初始化USART2
	void RS485_send_data(u8* buf,u8 len);//RS485发送len个字节数据
	void RS485_receive_data(u8* buf,u8* len);//RS485查询接收到的len个字节数据
	
#endif
```

main.c

```c
int main(void)
{
	u8 key,i=0,t=0,cnt=0;
	u8 rs485_buf[5];
	
	delay_init(168);
	LED_init();
	LCD_init();
	KEY_init();
	RS485_init(9600);//初始化波特率9600
	
	while(1)
	{
		KEY_init=KEY_scan(0);
		if(KEY_init==KEY0_PRES)//KEY0按下则发送一次数据
		{
			for(i=0;i<5;i++)
			{
				rs485_buf[i]=cnt+i;//填充发送缓冲区
				LCD_ShowxNum(30+i*32,190,rs485_buf[i],3,16,0x80);//显示数据
			}
			RS485_send_data(rs485_buf,5);
		}
	
		RS485_receive_data(rs485_buf,&key);
		
		if(key)//接收到有数据
		{
			if(key>5)
				key=5;
			for(i=0;i<key;i++)
				LCD_ShowxNum(30+i*32,230,rs485_buf[i],3,16,0x80);//显示数据
		}
		
		t++;
		delay_ms(10);
		
		if(t==20)//提示系统正在运行
		{
			LED0=!LED0;
			t=0;
			cnt++;
			LCD_ShowxNum(20+48,150,cnt,3,16,0x80);;//显示数据
		}
	}
}
```

