# DHT11传感器

**工作电压范围**：3.3-5.5V		**工作电流**：0.5mA（Typ）

输出：**单总线数字信号**

单个数据引脚端口完成输入输出，输出**未编码的二进制数据**数据包由5Byte（40Bit）组成，数据分小数和整数部分，一次传输40bit，高位先出

数据格式：8bit湿度整数数据+8bit湿度小数数据+8bit温度整数数据+8bit温度小数数据+8bit校验和（**前四个字节相加**）

传感器输出的是未编码的二进制数据，数据之间应该分开处理

##### 计算公式：

$$湿度=byte4 . byte3=45.0$$

$$温度=byte2 . byte1=28.0$$

测量范围：湿度20%-90%RH，温度0-50℃

精度：湿度+-5%，温度+-2%

分辨率：湿度1%，精度1℃

## 时序

1. 主机发送开始信号：主机LOW，保持t1（至少18ms），然后主机HIGH，保持t2（20-40us）
2. DHT11响应：传感器LOW，保持t3（40-50us），传感器再HIGH，保持t4（40-50us）
3. 输出数据
   * 数据0：LOW（12-14us）+HIGH（26-28us）
   * 数据1：LOW（12-14us）+HIGH（116-118us）

总体过程：主机请求-DHT11响应-DHT11发送数据-主机接收数据

## 电路描述

pin1接地，并联滤波电容104，串4.7k电阻到pin2；pin3、pin4接地，pin2接

## 代码

dht11.c

```c
#include "dht11.h"
#include "delay.h"


//初始化
u8 DHT11_init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOG,ENABLE);
	
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_OUT;//普通输出模式
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出模式
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_9;//设定输出IO为PG9
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_UP;//内部上拉
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_50MHz;//50MHz
	//应用设置
	GPIO_Init(GPIOG,&GPIO_InitStructure);

	DHT11_rst();
	
	return DHT11_check();
}


//读取一次温度湿度数据
//温度Temp=[0,50]		湿度Humi=[20%,90%]
//成功读取返回0，读取失败返回1
u8 DHT11_read_data(u8* Temp,u8* Humi)
{
	u8 buff[5];
	u8 i;

	DHT11_rst();
	
	if(DHT11_check()==0)//传感器已正确连接
	{
		for(i=0;i<4+1;i++)//读取40位数据
			buff[i]=DHT11_read_byte();
		
		if((buff[0]+buff[1]+buff[2]+buff[3])==buff[4])
		{
			*Humi=buff[0];//记录湿度
			*Temp=buff[2];//记录温度
		}
	}
	else
		return 1;
	
	return 0;
}


/*********************************驱动部分*********************************/


//复位
void DHT11_rst(void)
{
	DHT11_IO_OUT();//设置输出状态
	
	DHT11_DQ_OUT=0;//拉低DQ
	delay_ms(20);//主机拉低至少18ms
	
	DHT11_DQ_OUT=1;//拉高DQ
	delay_us(30);//主机拉高20-40us
}

//等待回应
u8 DHT11_check(void)
{
	u8 DHT11_retry=0;
	
	DHT11_IO_IN();//设置输入状态

	while(DHT11_DQ_IN && DHT11_retry<100)//等待传感器拉低40-50us
	{
		DHT11_retry++;
		delay_us(1);
	}
	if(DHT11_retry>=100)//判断传感器连接是否正常
		return 1;
	else
		DHT11_retry=0;
	
	while(!DHT11_DQ_IN && DHT11_retry<100)//等待传感器拉高40-50us
	{
		DHT11_retry++;
		delay_us(1);
	}
	if(DHT11_retry>=100)//判断传感器是否工作正常
		return 1;
	
	return 0;
}


//读一个bit数据
//成功读取返回1，失败返回0
u8 DHT11_reda_bit(void)
{
	u8 DHT11_retry=0;
	
	while(DHT11_DQ_IN && DHT11_retry<100)//等待传感器拉低
	{
		DHT11_retry++;
		delay_us(1);
	}
	
	DHT11_retry=0;
	
	while(!DHT11_DQ_IN && DHT11_retry<100)//等待传感器拉高
	{
		DHT11_retry++;
		delay_us(1);
	}
	
	delay_us(40);//等待40us
	
	if(DHT11_DQ_IN)
		return 1;
	else
		return 0;
}

//读一个byte数据
//返回成功读取的数据
u8 DHT11_read_byte(void)
{
	u8 i;
	u8 data=0;

	for(i=0;i<8;i++)
	{
		data<<=1;//data向左移1位
		data|=DHT11_reda_bit();//读入1位
	}
	
	return data;
}


/*********************************基础部分*********************************/
```

dht11.h

```c
#ifndef __DHT11_H
	#define __DHT11_H
	#include "sys.h"
		
	//定义IO方向
	#define DHT11_IO_IN() {GPIOG->MODER&=(3<<(9*2));GPIOG->MODER|=0<<9*2;} //PG9输入模式
	#define DHT11_IO_OUT() {GPIOG->MODER&=(3<<(9*2));GPIOG->MODER|=1<<9*2;} //PG9输出模式

	//定义IO操作函数
	#define DHT11_DQ_OUT PGout(9)
	#define DHT11_DQ_IN PGin(9)
	
	u8 DHT11_init(void);//初始化DHT11 传感器正常工作返回0；异常返回1
	u8 DHT11_read_data(u8* Temp,u8* Humi);//读取温湿度数据 成功读取返回0，读取失败返回1
	
	u8 DHT11_check(void);//检查DHT11是否正常工作 正常返回0；异常返回1
	void DHT11_rst(void);//复位DHT11
	
	u8 DHT11_reda_bit(void);//读位数据 返回读出的数据
	u8 DHT11_read_byte(void);//读字节数据 返回读出的数据
#endif
```

main.c

```c
#include "sys.h"
#include "delay.h"
#include "lcd.h"
#include "dht11.h"

int main(void)
{
    int t=0;
    int temperature=0;
    int humidity=0;
        
    NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//中断优先级分组2
    
    delay_init(168);
    LCD_init();
    
    while(DHT11_init())//等待DHT11初始化，若初始化失败则显示错误信息
    {
        LCD_ShowString(20,130,200,16,16,"DHT11_ERROR");
        delay_ms(200);
        LCD_Fill(30,130,239,130+16,WHITE);
        delay_ms(200);
    }
    
    while(1)
    {
        if(t%10==0)//100ms读取一次
        {
            DHT11_read_data(&temperature,&humidity);//读取温湿度值
            LCD_ShowNum(30+40,150,temperature,2,16);
            LCD_ShowNum(20+40,170,humidity,2,6);
        }
    }
}
```







