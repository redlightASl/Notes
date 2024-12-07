# 总线协议

## I2C （又称I^2^C、IIC等）

I2C（Integrated Circuit）是**两线**式**半双工串行**总线

由数据线**SDA**和时钟**SCL**构成

一般可达400kbps以上

### 协议栈

#### 底层硬件

SDA和SCL分别上拉到VCC，同时接入设备

主设备操纵SCL，可以接收/发送SDA

从设备可以发送/接收SDA

### 驱动

##### 空闲（释放总线）

SDA=1	SCL=1

##### 起止信号

起始信号：SCL=1	SDA下降沿

停止信号：SCL=1	SDA上升沿

##### 应答信号ACK

发送器**每发送一个字节**，就在时钟9器件释放SDA，由接收器反馈一个应答信号

**0为有效应答**，ACK称为应答位，表示接收器已接收

**1为非应答**，NACK称为非应答位，表示接收器接收该字节没有成功

从设备要求：

在==第9个==时钟脉冲之前的低电平期间==将SDA拉低==，并确保在该时钟高电平期间位稳定的低电平

主设备要求：

在==收到最后一个字节后发送一个NACK信号==以通知被控发送器结束数据发送，并SDA=1（释放SDA），以便从设备发送停止信号P

##### 数据有效性确认

SCL=1期间，SDA上的数据必须保持稳定，只有在SCL=0时，SDA才允许变化

即***数据在SCL上升沿到来前就要准备好，并在下降沿到来前必须稳定***

##### stm32实现

stm32自带I2C不稳定，通常使用GPIO模拟I2C

iic.h

```c
#ifndef __IIC_H
	#define __IIC_H
	#include "sys.h"
	
	//定义模拟线
	#define IIC_SCL GPIO_Pin_8//以PB8、PB9作为I2C模拟线
	#define IIC_SDA GPIO_Pin_9
	
	//设置端口操作
	#define IIC_SCL_WRITE PBout(8)//PB8模拟SCL输出
	#define IIC_SDA_WRITE PBout(9)//PB9模拟SDA输出
	#define IIC_SDA_READ PBin(9)//PB9模拟SDA输入
	
	//设置端口输入输出模式
	#define IIC_SDA_IN() {GPIOB->MODER&=~(3<<(9*2));GPIOB->MODER|=0<<9*2;} //PB9输入模式
	#define IIC_SDA_OUT() {GPIOB->MODER&=~(3<<(9*2));GPIOB->MODER|=1<<9*2;} //PB9输出模式
	
	void IIC_init(void);//产生IIC起始信号
	void IIC_stop(void);//产生IIC停止信号
	u8 IIC_wait_ACK(void);//等待应答信号
	void IIC_ACK(void);//产生ACK应答
	void IIC_NACK(void);//不产生ACK应答
	void IIC_send_byte(u8 txd);//IIC发送一个字节
	u8 IIC_read_byte(unsigned char ACK);//IIC读取一个字节
	
#endif
```

iic.c

```c
#include "iic.h"
#include "delay.h"

//初始化IIC
void IIC_init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB,ENABLE);
	
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_OUT;//普通输出模式
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_Pin=IIC_SCL|IIC_SDA;//模拟IIC
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_UP;//内部上拉
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//100MHz
	//应用设置
	GPIO_Init(GPIOB,&GPIO_InitStructure);

	IIC_SCL_WRITE=1;
	IIC_SDA_WRITE=1;//默认拉高总线
}

//产生IIC起始信号
void IIC_start(void)
{
	IIC_SDA_OUT();//SDA输出
	
	IIC_SDA_WRITE=1;
	IIC_SCL_WRITE=1;
	delay_us(4);

	IIC_SDA_WRITE=0;//开始信号为SDA上升沿
	delay_us(4);
	
	IIC_SCL_WRITE=0;//拉低SCL，准备接收或发送数据
}

//产生IIC停止信号
void IIC_stop(void)
{
	IIC_SDA_OUT();//SDA输出
	
	IIC_SCL_WRITE=0;
	IIC_SDA_WRITE=0;
	delay_us(4);
    
	IIC_SCL_WRITE=1;
	IIC_SDA_WRITE=1;//停止信号为SDA下降沿
	delay_us(4);
}

//等待应答信号
//返回1：接收应答失败
//返回0：接收应答成功
u8 IIC_wait_ACK(void)
{
	u8 Err_time=0;
	IIC_SDA_IN();//SDA输入
	
	IIC_SDA_WRITE=1;//等待接收应答
	delay_us(1);
	IIC_SCL_WRITE=1;
	delay_us(1);
	
	while(IIC_SDA_READ)//获取SDA的信号
	{
		Err_time++;//每读取一次高电平则+1
		if(Err_time>250)//若一直读到高电平则接收应答失败
		{
			IIC_stop();
			return 1;
		}
	}
	
	IIC_SCL_WRITE=0;//一直读到低电平则为有效应答
	return 0;
}

//产生ACK应答
void IIC_ACK(void)
{
	IIC_SDA_OUT();//SDA输出
	
	IIC_SCL_WRITE=0;//SCL上升沿时SDA=0
	IIC_SDA_WRITE=0;
	delay_us(2);
	IIC_SCL_WRITE=1;
    
	delay_us(2);
	IIC_SDA_WRITE=0;
}

//不产生ACK应答
void IIC_NACK(void)
{
	IIC_SDA_OUT();//SDA输出
	
	IIC_SCL_WRITE=0;//SCL上升沿时SDA=1
	IIC_SDA_WRITE=1;
	delay_us(2);
	IIC_SCL_WRITE=1;
    
	delay_us(2);
	IIC_SCL_WRITE=0;
}

//IIC发送一个字节
void IIC_send_byte(u8 txd)
{
	u8 t;

	IIC_SDA_OUT();//SDA输出
	IIC_SCL_WRITE=0;//拉低SCL准备输出

    //发送数据以SDA电平为准
	for(t=0;t<8;t++)
	{
        //SDA早来晚走
		IIC_SDA_WRITE=(txd & 0x80)>>7;//取最高位发送
		txd<<=1;//待发送数据向左移位，次高位变成最高位，获取下一个待发送的位
		delay_us(2);
        
        //SCL晚来早走
		IIC_SCL_WRITE=1;
		delay_us(2);
		IIC_SCL_WRITE=0;
		delay_us(2);
	}
}

//IIC读取一个字节
//ack_flag=1时发送ACK
//ack_flag=0时发送NACK
u8 IIC_read_byte(unsigned char ACK)
{
	unsigned char i,receive=0;
	
	IIC_SDA_IN();//SDA输入

	for(i=0;i<8;i++)
	{
		IIC_SCL_WRITE=0;//SCL上升沿
		delay_us(2);
		IIC_SCL_WRITE=1;
		
		receive<<=1;//读取1位
		
		if(IIC_SDA_READ)
			receive++;
		delay_us(1);
	}
	
	if(!ACK)
		IIC_NACK();
	else
		IIC_ACK();
	
	return receive;
}
```

#### 应用

示例程序：I2C驱动24C01（EEPROM）

24C02规格：总容量2K=256B*8

引脚定义如下：【1-A0 2-A1 3-A2】（地址线） 4-GND 【5-SDA 6-SCL】（I2C控制线） 7-WP（写保护） 8-VCC

在此A0=A1=A2=0

SCL\==PB8	SDA\==PB9

**详细内容参考芯片手册即可**

###### 写时序

start->片选->选择地址->wait->传输数据->stop

###### 读时序

 start->片选->选择地址线->start->选择地址线->wait->读取数据->stop

**程序读者自写**

## SPI

SPI（Serial Peripheral interface）串行外围设备接口，是一种**四线**、**高速**、**全双工**、**同步**通信总线

==应用广泛==

四条通信线：

**MISO**：（Master input & Slave output）主设备数据输入、从设备数据输出 即 **从设备->主设备**

**MOSI**：（Master output & Slave input）主设备数据输出、从设备数据输入 即 **主设备->从设备**

**SCLK**：时钟信号，由主设备产生

**CS**：片选信号，由主设备控制

### 协议栈

#### 底层硬件

stm32f4自带SPI接口，相关内容参考芯片手册即可

基本原理

1. 4线总线
2. 主机从机各有一个串行移位寄存器（以下简称SPI寄存器），主机通过向它的SPI寄存器写入一个字节来发起一次传输
3. SPI寄存器通过MOSI线将字节传输给从机，从机也将自己SPI寄存器中的内容通过MISO线返回主机，最终**两个移位寄存器中的内容被交换**
4. **外设读写操作同步完成**，如果**只进行写操作，主机忽略收到数据**即可；若**只进行读操作，需要发送一个空字节来引发从机的传输**

外设SPI的MISO、MOSI、SCLK可直接挂载到总线上，但CS线需要单独连接到stm32的GPIO模拟CS引脚，当对应GPIOxPinx<->CS拉低时表示选中该外设，才可进行通信

#### 驱动

驱动由stm32f4 STL提供，只需调用库函数即可

#### 应用

SPI应用过程

1. 使能SPIx和GPIO时钟
2. 初始化GPIO为复用功能
3. 设置引脚复用为映射
4. 初始化SPIx，设置SPIx工作模式
5. 使能SPIx
6. SPI传输数据
7. 查看SPI传输状态

示例程序：SPI驱动W25Q128

W25Q128规格：**总容量16M**	分成256块64K	每个块分成16扇区，每个扇区4K

擦写周期多达10W次，具有20年的数据保存期限

==支持电压2.7-3.6V==

最小擦除单位为一个扇区，也就是**每次必须擦除4K个字节**

需要给W25Q128开辟一个至少4K的缓存区

支持标准SPI协议，还支持双输出/四输出的SPI，最大SPI时钟可以到80MHz（双输出时相当于160MHz，四输出时相当于320MHz）

引脚定义如下：

1 片选信号CS	2 MISO线SO	3 使能引脚WP#	4 接地GND	5 MOSI线SI	6 SCK线CLK	7 保持位HOLD	8 接电源VCC

##### 代码实现

spi.c

```c
#include "spi.h"
#include "delay.h"

//SPI1初始化，配置为主机
void SPI1_init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	SPI_InitTypeDef SPI_InitStructure;

	//1. 使能GPIOA/GPIOB时钟与SPI1时钟
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA,ENABLE);//w25qxx
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB,ENABLE);//SPI通信
	RCC_AHB1PeriphClockCmd(RCC_APB2Periph_SPI1,ENABLE);
	
	//2. 初始化GPIOF
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AF;//引脚复用
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_3|GPIO_Pin_4|GPIO_Pin_5;//GPIO3、4、5复用输出
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_UP;//内部上拉
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//100MHz
	//应用设置
	GPIO_Init(GPIOB,&GPIO_InitStructure);
	
	//3. GPIOB引脚复用为SPI1输出端
	GPIO_PinAFConfig(GPIOB,GPIO_PinSource3,GPIO_AF_SPI1);
	GPIO_PinAFConfig(GPIOB,GPIO_PinSource4,GPIO_AF_SPI1);
	GPIO_PinAFConfig(GPIOB,GPIO_PinSource5,GPIO_AF_SPI1);
	
	//4. 初始化SPI口
	RCC_APB2PeriphResetCmd(RCC_APB2Periph_SPI1,DISABLE);//复位SPI1
	RCC_APB2PeriphResetCmd(RCC_APB2Periph_SPI1,DISABLE);//停止复位
	
	SPI_InitStructure.SPI_Direction=SPI_Direction_2Lines_FullDuplex;//双线全双工
	SPI_InitStructure.SPI_Mode=SPI_Mode_Master;//主机模式
	SPI_InitStructure.SPI_DataSize=SPI_DataSize_8b;//SPI发送接收8位帧结构
	SPI_InitStructure.SPI_CPOL=SPI_CPOL_High;//SCLK空闲状态为高电平
	SPI_InitStructure.SPI_CPHA=SPI_CPHA_2Edge;//SCLK第二个跳变沿数据被采样
	SPI_InitStructure.SPI_NSS=SPI_NSS_Soft;//NSS信号由硬件（NSS管脚）还是软件（使用SSI位管理）：硬件管理
	SPI_InitStructure.SPI_BaudRatePrescaler=SPI_BaudRatePrescaler_256;//预分频256
	SPI_InitStructure.SPI_FirstBit=SPI_FirstBit_MSB;//指定数据传输从MSB位还是LSB位开始：数据传输从MSB位开始
	SPI_InitStructure.SPI_CRCPolynomial=7;//CRC计算的多项式
	//应用设置
	SPI_Init(SPI1,&SPI_InitStructure);
	
	//5. 使能SPI
	SPI_Cmd(SPI1,ENABLE);
	//6. 主机发送0xff，维持MOSI为高电平，启动SPI传输
	SPI1_RW_byte(0xff);
}

//设置SPI1波特率
//SPI速率=f_{APB2}/分频系数
//f_{APB2}一般为84MHz
//
void SPI1_set_speed(u8 SPI_BaudRatePrescaler)
{
	assert_param(IS_SPI_BAUDRATE_PRESCALER(SPI_BaudRatePrescaler));//判断有效性
	SPI1->CR1 &= 0xFFC7;//位3-5清零，设置波特率
	SPI1->CR1 |= SPI_BaudRatePrescaler;//设置波特率
	SPI_Cmd(SPI1,ENABLE);//使能SPI1
}

//通过SPI1总线读写一个字节
//tx_data：发送字节
//返回接收字节
u8 SPI1_RW_byte(u8 tx_data)
{
	while(SPI_I2S_GetFlagStatus(SPI1,SPI_I2S_FLAG_TXE)==RESET);//等待发送区清空
	SPI_I2S_SendData(SPI1,tx_data);//发送数据
	while(SPI_I2S_GetFlagStatus(SPI1,SPI_I2S_FLAG_RXNE)==RESET)//等待接收完一个字节
	return SPI_I2S_ReceiveData(SPI1);//返回最近接收的数据
}
```

spi.h

```c
#ifndef __SPI_H
	#define __SPI_H
	#include "sys.h"
	
	void SPI1_init(void);//初始化SPI1
	void SPI1_set_speed(u8 SPI_BaudRatePrescaler);//设置SPI1波特率
	u8 SPI1_RW_byte(u8 tx_data);//通过SPI1总线读写一个字节（读写同时进行）
	
#endif
```

W25Q128.c

```c
u16 W25QXX_TYPE;//FLASH型号

//FLASH初始化
void W25QXX_init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;

	//1. 使能GPIOB与GPIOG时钟
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB,ENABLE);//GPIOB
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOG,ENABLE);//GPIOG
	
	//2. 初始化GPIOF
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_OUT;//普通输出
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_14;//PB14输出
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_UP;//内部上拉
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//100MHz
	//应用设置
	GPIO_Init(GPIOB,&GPIO_InitStructure);
	
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_7;//PG7
	//应用设置
	GPIO_Init(GPIOB,&GPIO_InitStructure);
	
	GPIO_SetBits(GPIOG,GPIO_Pin_7);//PG7连接到NRF，会同时连接到SPI，令PG7输出1，防止NRF干扰SPI FLASH通信
	W25QXX_CS=1;//不选中FLASH
	SPI1_init();//初始化SPI
	SPI1_set_speed(SPI_BaudRatePrescaler_2);//1/2分频，时钟频率为42MHz，高速模式
	W25QXX_TYPE=W25QXX_ReadID();//读取FLASH ID
}

//读取FLASH ID
u16  W25QXX_ReadID(void)
{
	u16 ID_Temp=0;
	W25QXX_CS=0;//片选
	SPI1_RW_byte(0x90);//发送读取ID命令
	SPI1_RW_byte(0x00);
	SPI1_RW_byte(0x00);
	SPI1_RW_byte(0x00);
	
	ID_Temp |= SPI1_RW_byte(0xFF)<<8;
	ID_Temp |= SPI1_RW_byte(0xFF);
	W25QXX_CS=0;//取消片选
	
	return ID_Temp;
}

//读取状态寄存器
/*
	BIT 6 	5 	4 	3 	2 	1 	0
	SPR RV TB BP2 BP1 BP0 WEL BUSY

	SPR默认0，状态寄存器保护位，配合WP使用
	TB、BP2、BP1、BP0：FLASH区域写保护设置
	WEL写使能锁定		BUSY忙标记位，1为忙，0为空闲

	默认0
*/
u8 W25QXX_ReadSR(void)
{
	u8 byte=0;
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_ReadStatusReg);//发送读取寄存器命令
	byte=SPI1_RW_byte(0xff);//读取一个字节
	W25QXX_CS=1;//取消片选
	
	return byte;
}

//写状态寄存器
//只能写入SPR、TB、BP2、BP1、BP0(bit 7,5,4,3,2)
void W25QXX_Write_SR(u8 sr)
{
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_WriteStatusReg);//发送写寄存器命令
	SPI1_RW_byte(sr);//读取一个字节
	W25QXX_CS=1;//取消片选
}

//写使能	将WEL置位
void W25QXX_Write_Enable(void)
{
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_WriteEnable);//发送写使能命令
	W25QXX_CS=1;//取消片选
}

//写保护	将WEL清零
void W25QXX_Write_Disable(void)
{
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_WriteDisable);//发送写禁止命令
	W25QXX_CS=1;//取消片选
}

//等待空闲
void W25QXX_Wait_Busy(void)
{
	while((W25QXX_ReadSR()&0x01)==0x01);
}

//进入掉电模式
void W25QXX_PowerDown(void)
{
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_PowerDown);//发送掉电命令
	W25QXX_CS=1;//取消片选
	delay_us(3);//等待TPD
}

//唤醒
void W25QXX_WAKEUP(void)
{
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_ReleasePowerDown);//发送唤醒命令
	W25QXX_CS=1;//取消片选
	delay_us(3);
}


//按页写入FLASH
//在指定地址开始写入最大256字节的数据
void W25QXX_Write_Page(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite)
{
	u16 i;
	
	W25QXX_Write_Enable();//WEL置位
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_PageProgram);//发送写页命令
	SPI1_RW_byte((u8)((WriteAddr)>>16));//发送24位地址
	SPI1_RW_byte((u8)((WriteAddr)>>8));
	SPI1_RW_byte((u8)WriteAddr);
	for(i=0;i<NumByteToWrite;i++)//循环写入
		SPI1_RW_byte(pBuffer[i]);
	W25QXX_CS=1;//取消片选
	W25QXX_Wait_Busy();//等待写入结束
}


//无保护写入FLASH
//必须确保所写地址内数据为0xFF
//可自动换页
//在指定地址开始写入指定长度的数据，但要确保地址不越界
void W25QXX_Write_NoCheck(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite)
{
	u16 page_remain;
	page_remain=256-WriteAddr%256;//单页剩余的字节数
	
	if(NumByteToWrite<=page_remain)//待写入字节不大于单页剩余字节
		page_remain=NumByteToWrite;
		
	while(1)
	{
		W25QXX_Write_Page(pBuffer,WriteAddr,page_remain);
		
		if(NumByteToWrite==page_remain)
			break;//写入结束
		else//若待写入字节数比单页剩余字节数大
		{
			pBuffer+=page_remain;
			WriteAddr+=page_remain;
			
			NumByteToWrite-=page_remain;//减去已经写入的字节数
			
			if(NumByteToWrite>256)//若剩余字节数大于一页字节数
				page_remain=256;//下页能写满
			else//若不够256个字节
				page_remain=NumByteToWrite;//下页不能写满
		}
	}
}


//读取SPI FLASH
//在指定地址读取指定长度的数据
//pBuffer：数据储存区
//ReadAddr：开始读取的地址（24位）
//NumByteToRead：要读取的最大字节数（<=65535）
void W25QXX_Read(u8* pBuffer,u32 ReadAddr,u16 NumByteToRead)
{
	u16 i;
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_ReadData);//发送读取命令
	SPI1_RW_byte((u8)((ReadAddr)>>16));//发送24位地址
	SPI1_RW_byte((u8)((ReadAddr)>>8));
	SPI1_RW_byte((u8)ReadAddr);
	for(i=0;i<NumByteToRead;i++)
		pBuffer[i]=SPI1_RW_byte(0xFF);//循环从FLASH中读数
	
	W25QXX_CS=1;//取消片选
}


//写入FLASH
//在指定地址带擦除地开始写入指定长度的数据
//pBuffer：数据存储区
//ReadAddr：开始写入的地址（24位）
//NumByteToRead：要写入的最大字节数（<=65535）
u8 W25QXX_BUFFER[4096];//缓存：保存芯片内不为空的数据
void W25QXX_Write(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite)
{
	u32 sec_pos;
	u16 sec_off;
	u16 sec_remain;
	u16 i;
	u8* W25QXX_BUF;
	
	W25QXX_BUF=W25QXX_BUFFER;
	
	sec_pos=WriteAddr/4096;//扇区基地址
	sec_off=WriteAddr%4096;//偏移地址
	sec_remain=4096-sec_off;//扇区剩余空间
	
	if(NumByteToWrite<sec_remain)
		sec_remain=NumByteToWrite;//剩余地址不大于4096个字节
	
	while(1)//反复执行直到完成擦除
	{
		W25QXX_Read(W25QXX_BUF,sec_pos*4096,4096);//读出全扇区内容
		for(i=0;i<sec_remain;i++)
		{
			if(W25QXX_BUF[sec_off+i]!=0xFF)//若存在非空地址
				break;//需要擦除
		}
		if(i<sec_remain)//如果需要擦除
		{
			W25QXX_Erase_Sector(sec_pos);//那么擦除这个扇区
			for(i=0;i<sec_remain;i++)
			{
				W25QXX_BUF[sec_off+i]=pBuffer[i];//指针指向地址为扇区基地址+偏移地址
			}
			W25QXX_Write_NoCheck(W25QXX_BUF,sec_pos*4096,4096);//写入需要的部分
		}
		else//如果不需要擦除（检查到的部分都为空）
			W25QXX_Write_NoCheck(W25QXX_BUF,sec_pos*4096,4096);//直接写入扇区区间
		
		if(NumByteToWrite==sec_remain)//若待写字节数等于扇区剩余字节数（写完惹）
			break;//结束写入
		else
		{
			sec_pos++;//扇区地址+1
			sec_off=0;//偏移地址为0，定位到扇区头部
			
			pBuffer+=sec_remain;//指针偏移
			WriteAddr+=sec_remain;//写入地址偏移
			NumByteToWrite-=sec_remain;//待写字节数递减
			
			if(NumByteToWrite>4096)//若待写字节数比一个扇区空间大
				sec_remain=4096;//下个扇区还是写不完
			else
				sec_remain=NumByteToWrite;//下个扇区就可以写完
		}
	}
}

//整片擦除
//注意：等待时间较长
void W25QXX_Erase_Chip(void)
{
	printf("ERASE ALL CHIP!");//显示警告
	
	W25QXX_Write_Enable();//WEL置位并等待
	W25QXX_Wait_Busy();
	
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_ChipErase);
	W25QXX_CS=1;//取消片选
	W25QXX_Wait_Busy();
}


//擦除一个扇区
//Dst_Addr为目标扇区地址
//擦除一个扇区最少用时150ms
void W25QXX_Erase_Sector(u32 Dst_Addr)
{
	printf("%x will be erase!\r\n",Dst_Addr);//显示警告
	
	Dst_Addr*=4096;
	W25QXX_Write_Enable();//WEL置位并等待
	W25QXX_Wait_Busy();
	
	W25QXX_CS=0;//片选
	SPI1_RW_byte(W25X_SectorErase);
	SPI1_RW_byte((u8)((Dst_Addr)>>16));
	SPI1_RW_byte((u8)((Dst_Addr)>>8));
	SPI1_RW_byte((u8)Dst_Addr);
	W25QXX_CS=1;//取消片选
	W25QXX_Wait_Busy();
}
```

W25Q128.h

```c
//前部分略	
	#define W25Q80 	0XEF13
	#define W25Q16 	0XEF14
	#define W25Q32	0XEF15
	#define W25Q64 	0XEF16
	#define W25Q128 0XEF17
	
	/*W35X系列/Q系列芯片列表
	W25Q80 0XEF13
	W25Q16 0XEF14
	W25Q32 0XEF15
	W25Q64 0XEF16
	W25Q128 0XEF17
	*/
	
	extern u16 W25QXX_TYPE;//定义W25QXX芯片型号
	
	#define W25QXX_CS PBout(14)//PB14输出W25QXX片选信号(软件片选)
	
/***************************指令表***************************/
	#define W25X_WriteEnable 			0x06
	#define W25X_WriteDisable 			0x04
	#define W25X_ReadStatusReg 			0x05
	#define W25X_WriteStatusReg 		0x01
	#define W25X_ReadData 				0x03
	#define W25X_FastReadData 			0x0B
	#define W25X_FastReadDual 			0x3B
	#define W25X_PageProgram 			0x02
	#define W25X_BlockErase 			0xD8
	#define W25X_SectorErase 			0x20
	#define W25X_ChipErase 				0xC7
	#define W25X_PowerDown 				0xB9
	#define W25X_ReleasePowerDown 		0xAB
	#define W25X_DeviceID 				0xAB
	#define W25X_ManufactDeviceID 		0x90
	#define W25X_JedecDeviceID 			0x9F
/***************************指令表***************************/

	void W25QXX_init(void);//FLASH初始化
	
	u16  W25QXX_ReadID(void);//读取FLASH ID
	u8 	 W25QXX_ReadSR(void);//读取状态寄存器
	
	void W25QXX_Write_SR(u8 sr);//写状态寄存器
	void W25QXX_Write_Enable(void);//写使能
	void W25QXX_Write_Disable(void);//写保护
	
	void W25QXX_Write_NoCheck(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite);
	void W25QXX_Read(u8* pBuffer,u32 ReadAddr,u16 NumByteToRead);//读取FLASH
	void W25QXX_Write(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite);//写入FLASH
	
	void W25QXX_Erase_Chip(void);//整片擦除
	void W25QXX_Erase_Sector(u32 Dst_Addr);//扇区擦除
	
	void W25QXX_Wait_Busy(void);//等待空闲
	void W25QXX_PowerDown(void);//进入掉电模式
	void W25QXX_WAKEUP(void);//唤醒
```

## CAN

### 协议栈

CAN(Controller Area Network)是ISO国际标准化的串行通信协议，由德国电气商博世公司在1986年率先提出。此后CAN通过ISO11898及ISO11519进行了标准化，**可靠性高**

具有两个标准：

1. ISO11898高速通信标准（速率125Kbps~1Mbps）

2. ISO11519-2低速通信标准（速率125Kbps以下）

特点：

* 多主控制

总线空闲时所有单元都可发送消息，两个以上单元同时发送消息时，根据**标识符**（ID，**不是地址**）决定优先级。对各个消息ID的各个位进行逐个仲裁比较，**仲裁获胜单元可继续发送消息，失利的单元需立刻停止发送而进行接收工作**


* 系统柔软性

连接总线的单元没有类似地址的信息，可以很方便地**添加新单元，不需要改动旧设备**


* 速度快，距离远

速率最高1Mbps（距离<40m），最远可达10km（速率<5kbps）


* 具有错误检测、错误通知和错误恢复功能

**所有单元都能检测错误，检测到错误会立即通知所有其他单元，正在发送消息的单元一旦检测到出错会强制结束发送，并不断反复重新发送此消息直到发送成功**

* 故障封闭功能

可以判断出错误的类型是总线上暂时的数据错误还是持续的数据错误。当总线上发生持续数据错误时，可将引起此故障的单元从总线上隔离出去

* 连接节点多

可同时连接多个单元，理论上没有总数限制，但实际上可连接单元越多，通信速率越慢；通信速率越快，可连接单元数越少

#### 底层硬件

==使用ISO11898标准==

CAN控制器根据CAN_L和CAN_H上的电位差来判断总线电平

发送方通过使总线电平发生变化将消息发送给接收方

* 显性电平对应逻辑0：CAN_H与CAN_L之差在2V左右

* 隐性电平对应逻辑1：CAN_H与CAN_L之差为0V

总线电平必为二者之一，**显性电平具有优先权**，只要一个单元输出显性电平，总线上即为显性电平；只有所有单元都输出隐性电平，总线上才为隐性电平

单元在总线上呈并联，**总线起止端各有一个120Ω的终端电阻**（作用：阻抗匹配，减少回波反射）



stm32f407自带**2个**基本可扩展CAN外设（bxCAN），支持CAN协议2.0A和2.0B主动模式，波特率最高1Mbps，通过GPIO复用2个引脚输出，但需要接入**TJA1050**电平转换ic才能正常接入CAN总线

每个CAN具有3个3级深度（**可同时存储三条有效报文**）发送邮箱，互相独立；2个接收FIFO，最多28个可变筛选器组

**两个CAN分别拥有独立的发送邮箱和接收FIFO，但他们会共用28个筛选器**

##### CAN标识符筛选器

**CAN的标识符**不表示目标地址而是**表示发送优先级**，接收节点根据标识符的值决定是否接受对应信息

STM32 CAN控制器每个筛选器组由2个32位寄存器组成，根据位宽不同，每个筛选器组可提供

* 1个32位筛选器，包括STDID[10:0] EXTID[17:0] IDE RTR
* 2个16位筛选器，包括STDID[10:0] IDE RTR EXTID[17:15]

应用程序不用的筛选器组应当保持禁用

筛选器编号从0开始

筛选器可配置为屏蔽位模式和标识符列表模式：

* 屏蔽位模式下，标识符寄存器指定报文标识符哪一位“必须匹配”；屏蔽寄存器指定报文标识符哪一位“不用关心”

  屏蔽寄存器置0的标识寄存器对应位会被忽略

  类似“掩码”操作，一次筛选出**一组**标识符

* 标识符列表模式下，屏蔽寄存器也被当做标识符寄存器用，接受报文标识符的每一位都必须和筛选器标识符相同

  一次过滤出**一个**标识符号

==举例：1个32位筛选器-标识符屏蔽模式，设置CAN_F0R1=0xFFFF0000，CAN_F0R2=0xFF00FF00，则期望收到的id形式为0xFFFF0000，同时必须关心id形式为0xFF00FF00，即标记为F的四个位必须和F0R1中的对应位一模一样，另外的六个位可以一样也可以不一样，即收到的映像必须是0xFF??00??才算是正确的，并不关心标?的位是多少==

#### 驱动

##### CAN通信

* 数据帧：**发送单元**向接收单元**传送数据**

* 遥控帧：**接收单元**向具有相同ID的发送单元**请求数据**
* 错误帧：检测出错时**向其他单元通知错误**
* 过载帧：接收单元通知其**尚未做好接收准备**（标记忙碌状态）
* 间隔帧：将数据帧和遥控帧与前面的帧**分隔**开的帧

**数据帧**和**遥控帧**有**11位ID的标准格式**和**29位ID的拓展格式**

###### 数据帧

由7个段组成，下面是标准格式的实现

1. 帧起始：1位显性电平
2. 仲裁段：11位ID+1位RTR（显性电平）

表示数据优先级。**ID高位在前，低位在后**，**禁止高7位都是隐性**（不能ID=1111111XXXX）

RTR：**远程请求**位——0表示数据帧，1表示远程帧

SRR：**替代远程请求**位——设置为1

IDE：**标识符选择**位——0表示标准标识符，1表示扩展标识符

3. 控制段：1位IDE（显性电平）+1位r0（显性电平）+4位DLC

r0、r1：**保留位**——必须以显性电平发送，但接收可以是隐性电平

DLC：**数据长度码**——0-8表示发送/接收的数据长度（字节）

4. 数据段：0-64位（0-8个字节）的数据

**从最高位开始输出**

5. CRC段：15位+1位RCR界定符（隐性电平）

用于检查帧传输错误

CRC的值计算范围包括：帧起始、仲裁段、控制段、数据段

接收方和发送方以同样的算法计算CRC并进行比较，不一致时会通报错误

6. ACK段：1位ACK槽（发送位为隐性电平，接收位随接收成功与否变化）+1位ACK界定符（隐性电平）

用来确认是否正常接收

**发送单元ACK段发送2个隐性电平**

接收单元ACK段：**接收到正确消息的单元在ACK槽发送显性位**，称之为发送ACK/返回ACK

发送ACK的时既不处于总线关闭态也不处于休眠态的所有接受单元中，接收到正常消息（不含填充错误、格式错误、CRC错误）的单元，**发送单元不会发送ACK**

7. 帧结束：7位EOF（7位隐性电平）

###### 总线仲裁

1. 总线空闲时最先发送的单元优先，一旦发送无法被抢占
2. 多个单元同时发送，连续输出显性电平多的单元优先
3. 先比较ID，若ID相同，就比较RTR、SRR等位

###### 位时序（波特率）

位速率：发送单元在非同步情况下发送的每秒钟位数称为位速率

一个位一般可以分成四段

这些段又由最小时间单位Time Quantum(Tq)组成

1位分4段，1段分多个Tq，即**位时序**

$$位时间=\frac{1}{波特率}$$

可以任意设定位时序，多个单元可同时采样，也可任意设定采样点

* 同步段 SS

多个单元实现时序同步，1Tq

电平边沿跳变最好出现在此段中

* 传播时间段 PTS

吸收网络物理延迟

该段时间=2*(发送单元输出延迟+总线信号传播延迟+接受单元输入延迟)=1~8Tq

* 相位缓冲段1 PBS1

1~8Tq

* 相位缓冲段2 PBS2

2~8Tq

两段负责补偿未被包含在SS段的信号边沿；通过对相位缓冲段加减SJW吸收细微时钟误差，但会导致通信速度下降

* 再同步补偿宽度 SJW

1~4Tq

补偿时钟频率偏差/传输延迟等导致误差的最大值

##### STM32F407的CAN控制器设置

可分为三种模式

* 工作模式，通过CAN_MCR寄存器控制

  INRQ=1,SLEEP=0 初始化工作模式

  INRQ=0,SLEEP=0 ==正常工作==

  SLEEP=1 开启睡眠，降低功耗

* 测试模式，通过CAN_BTR控制

  LBKM=0,SLIM=1 静默，CANtx恒为1（只接收不发送），可以监控总线数据

  LBKM=1,SLIM=0 ==环回==，CANrx被阻塞（只发送不接收）

  LBKM=1,SLIM=1 环回静默，CANrx、CANtx都被阻塞（不接收不发送）

* 调试模式

##### CAN发收流程

###### CAN发送流程

1. 选择空置邮箱（TME=1）
2. 设置标识符（ID）、数据长度、待发送的数据内容
3. 设置CAN_TIxR的TXRQ位为1，请求发送
4. 邮箱挂号，等待成为最高优先级才能够发送
5. 预定发送，等待总线空闲
6. 发送数据
7. 邮箱空置

可随时置ABRQ为1退出发送进入等待，如果发送失败则可以重新等待发送或重启发动流程

###### CAN接收流程

1. FIFO为空
2. 收到有效报文（被正确接收（直到EOF都未出现错误）且通过标识符过滤的报文）
3. 挂号1，存入FIFO的一个邮箱（此步骤由硬件完成）
4. 收到有效报文
5. 挂号2
6. 收到有效报文
7. 挂号3
8. 收到有效报文
9. 溢出，可设置是否锁定，锁定后新数据将被丢弃，不锁定则新数据会替代老数据

通过读取CAN_RFxR的FMP寄存器获取FIFO中当前存储的数据条数，只要不为0则可以读取报文

###### STM32 CAN位时序

$波特率=\frac{1}{正常的位时间}$

$正常的位时间=1*t_q+t_{BS1}+t_{BS2}$

$t_{BS1}=t_q*(TS1[3:0]+1)$

$t_{BS2}=t_q*(TS2[2:0]+1)$

$t_q=(BRP[9:0]+1)*t_{PCLK}$

$t_q$代表1个时间单元，$t_{PCLK}$表示APB时钟的时钟周期

对于stm32f407，设置TS1=6,TS2=5,BRP=5

$波特率=\frac{42000}{[(7+6+1)*6]}=500Kbps$

#### 应用

初始化流程

1. 配置引脚复用
2. 使能CAN控制器时钟
3. 设置CAN工作模式和波特率
4. 设置过滤器
5. CAN自动开始工作

can.c

```c
#include "can.h"
#include <stdio.h>
#include "usart.h"

//CAN1初始化
//使用PA11、PA12引脚输入输出
/***********************************************
	Tsjw：重新同步跳跃时间单元，范围1Tq-4Tq CAN_BS1_1tq-CAN_BS1_16tq
	Tbs2：时间段2的时间单元，范围1Tq-8Tq CAN_BS2_1tq-CAN_BS2_8tq
	Tbs1：时间段1的时间单元，范围1Tq-16Tq
	brp：波特率分频器，范围1-1024	
	计算公式：1个时间单元Tq=(brp)*Tpclk1
	波特率=Fpclk1/(brp*(tbs1+1+tbs2+1+1))
	mode：CAN_Mode_Normal为普通模式，CAN_Mode_LoopBack为回环模式
	
	Fpclk1时钟在初始化时设置为36MHz，
	如果设置sjw=1,bs2=8,bs1=9,brp=4,回环模式，则波特率为36M/((8+9+1)*4)=500Kbps
	
	返回0则正常初始化，返回其他则初始化失败
************************************************/
u8 CAN1_Mode_init(u8 Tsjw,u8 Tbs2,u8 Tbs1,u16 brp,u8 mode)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	CAN_InitTypeDef CAN_InitStruct;
	CAN_FilterInitTypeDef CAN_FilterInitStruct;
	
	//如果使能FIFO消息挂号中断则开启
	#if CAN1_RX0_INT_ENABLE
		NVIC_InitTypeDef NVIC_InitStructure;
	
		CAN_ITConfig(CAN1,CAN_IT_FMP0,ENABLE);//使能FIFO消息挂号中断
		NVIC_InitStructure.NVIC_IRQChannel=CAN1_RX0_IRQn;
		NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority=1;//抢占优先级为1
		NVIC_InitStructure.NVIC_IRQChannelSubPriority=0;//子优先级为0
		NVIC_InitStructure.NVIC_IRQChannelCmd=ENABLE;//使能FIFO消息挂号中断
	#endif

	//1. 使能GPIO和CAN控制器时钟
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA,ENABLE);
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_CAN1,ENABLE);
	
	//2. 初始化PA11、PA12
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AF;//引脚复用
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_11|GPIO_Pin_12;//PA11、PA12
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_UP;//内部上拉
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//100Mhz
	//应用设置
	GPIO_Init(GPIOA,&GPIO_InitStructure);
	
	//2. 设置引脚复用映射
	GPIO_PinAFConfig(GPIOA,GPIO_PinSource11,GPIO_AF_CAN1);//PA11复用为CAN1
	GPIO_PinAFConfig(GPIOA,GPIO_PinSource12,GPIO_AF_CAN1);//PA12复用为CAN1
	
	//3. 设置CAN控制器
		//软件管理设定
	CAN_InitStruct.CAN_TTCM=DISABLE;//非时间触发 通信模式
	CAN_InitStruct.CAN_ABOM=DISABLE;//软件自动离线管理
	CAN_InitStruct.CAN_AWUM=DISABLE;//睡眠模式通过软件唤醒
		//报文相关设定
	CAN_InitStruct.CAN_NART=ENABLE;//禁止报文自动传送
	CAN_InitStruct.CAN_RFLM=DISABLE;//报文不锁定，新报文将覆盖堆积旧报文
	CAN_InitStruct.CAN_TXFP=DISABLE;//优先级由报文标识符决定
		//参数设置
	CAN_InitStruct.CAN_Mode=mode;//模式设置
	CAN_InitStruct.CAN_SJW=Tsjw;//同步跳跃宽度设置
	CAN_InitStruct.CAN_BS1=Tbs1;//Tbs1 设置为CAN_BS1_1tq-CAN_BS1_16tq
	CAN_InitStruct.CAN_BS2=Tbs2;//Tbs2 设置为CAN_BS2_1tq-CAN_BS2_8tq
	CAN_InitStruct.CAN_Prescaler=brp;//分频系数=brp+1
	//应用设置
	CAN_Init(CAN1,&CAN_InitStruct);
	
	//4. 设置标识符过滤器
		//基础设置
	CAN_FilterInitStruct.CAN_FilterNumber=0;//使用过滤器0
	CAN_FilterInitStruct.CAN_FilterMode=CAN_FilterMode_IdMask;//使用标识符屏蔽模式
	CAN_FilterInitStruct.CAN_FilterScale=CAN_FilterScale_32bit;//使用32位寄存器模式
		//32位ID设置
	CAN_FilterInitStruct.CAN_FilterIdHigh=0x0000;
	CAN_FilterInitStruct.CAN_FilterIdLow=0x0000;
		//32位掩码设置
	CAN_FilterInitStruct.CAN_FilterMaskIdHigh=0x0000;
	CAN_FilterInitStruct.CAN_FilterMaskIdLow=0x0000;
		//应用过滤器和FIFO设置
	CAN_FilterInitStruct.CAN_FilterFIFOAssignment=CAN_Filter_FIFO0;//使用FIFO0
	CAN_FilterInitStruct.CAN_FilterActivation=ENABLE;//激活标识符过滤器0
	//应用设置
	CAN_FilterInit(&CAN_FilterInitStruct);
	
	return 0;//完成初始化
}

//如果使能FIFO消息挂号中断则开启，负责接收剩余信息
#if CAN1_RX0_INT_ENABLE
	void CAN1_RX0_IRQHandler(void)
	{
		CanRxMsg CAN_rx_massage;
		int CAN_rx_counter=0;
		
		CAN_Receive(CAN1,0,&CAN_rx_massage);
		for(CAN_rx_counter=0;CAN_rx_counter<8;CAN_rx_counter++)
			printf("rxbuf[%d]:%d\r\n",CAN_rx_counter,CAN_rx_massage.Data[CAN_rx_counter]);
	}
#endif

//CAN发送数据
//固定格式：ID=0x12，标准帧，数据帧
//msg为数据指针，最大8个字节
//len为数据长度	0-8
//返回0表示成功，返回1表示失败
u8 CAN1_tx_msg(u8* msg,u8 len)
{
	u8 mbox;
	u16 i=0;
	CanTxMsg CAN_tx_massage;
	
	CAN_tx_massage.StdId=0x12;//标准标识符为0
	CAN_tx_massage.ExtId=0x12;//设置29位扩展标识符
	CAN_tx_massage.IDE=0;//使用扩展标识符
	CAN_tx_massage.RTR=0;//消息类型：数据帧，1帧8位
	CAN_tx_massage.DLC=len;//发送2帧消息
	
	for(i=0;i<len;i++)
		CAN_tx_massage.Data[i]=msg[i];//发送信息
	
	mbox=CAN_Transmit(CAN1,&CAN_tx_massage);
	
	i=0;
	
	while((CAN_TransmitStatus(CAN1,mbox)==CAN_TxStatus_Failed)&&(i<0xFFF))
		i++;
	if(i>=0xfff)
		return 1;
	return 0;
}

//CAN接收数据
//buf为数据缓存区
//返回0表示无数据被接收到，若接收到数据则返回接收的数据长度
u8 CAN1_rx_msg(u8* buf)
{
	u32 i;
	CanRxMsg CAN_rx_massage;
	
	if(CAN_MessagePending(CAN1,CAN_FIFO0)==0)
		return 0;
	
	CAN_Receive(CAN1,CAN_FIFO0,&CAN_rx_massage);//读取数据
	for(i=0;i<CAN_rx_massage.DLC;i++)
		buf[i]=CAN_rx_massage.Data[i];
	
	return CAN_rx_massage.DLC;//返回接收到的数据长度
}
```

can.h

```c
#ifndef __CAN_H
	#define __CAN_H
	#include "sys.h"

	u8 CAN1_mode_init(u8 Tsjw,u8 Tbs2,u8 Tbs1,u16 brp,u8 mode);//CAN1初始化函数
	u8 CAN1_tx_msg(u8* msg,u8 len);//CAN发送数据
	u8 CAN1_rx_msg(u8* buf);//CAN接收数据

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
#include "stmflash.h"
#include "can.h"

int main(void)
{
	u8 key,res,i=0,t=0,cnt=0;
	u8 CAN_buf[8];
	u8 mode=1;//CAN工作模式：1为环回模式，0为普通模式
	
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//中断优先级分组2
	
	delay_init(168);
	uart_init(115200);//串口波特率115200
	LED_init();
	LCD_init();
	KEY_init();
	CAN1_mode_init(CAN_SJW_1tq,CAN_BS2_6tq,CAN_BS1_7tq,6,CAN_Mode_LoopBack);//初始化为环回模式，波特率500kbps
	
	while(1)
	{
		key=KEY_scan(0);
		if(key==KEY0_PRES)
		{
			for(i=0;i<8;i++)
			{
				CAN_buf[i]=cnt+1;
				if(i<4)
					LCD_ShowxNum(30+i*32,210,CAN_buf[i],3,16,0x80);//显示数据
				else
					LCD_ShowxNum(30+(i-4)*32,230,CAN_buf[i],3,16,0x80);
			}
			
			res=CAN1_tx_msg(CAN_buf,8);//发送8个字节
			
			if(res)
				LCD_ShowString(30+80,190,200,16,16,"Failed");//发送失败
			else
				LCD_ShowString(30+80,190,200,16,16,"OK    ");//发送成功
		}
		else if(KEY_init==WKUP_PRES)
		{
			mode=!mode;
			CAN1_mode_init(CAN_SJW_1tq,CAN_BS2_6tq,CAN_BS1_7tq,6,mode);//初始化为普通模式，波特率500kbps
			
			POINT_COLOR=RED;
			
			if(mode==0)//普通模式，使用两套开发板通信
			{
				LCD_ShowString(30,130,200,16,16,"Normal Mode");
			}
			else//环回模式
			{
				LCD_ShowString(30,130,200,16,16,"LoopBack Mode");
			}
		}
		
		key=CAN1_rx_msg();
		
		if(key)
		{
			LCD_Fill(30,270,160,310,WHITE);
			for(i=0;i<key;i++)
			{
				if(i<4)
					LCD_ShowxNum(30+i*32,270,CAN_buf[i],3,16,0x80);//显示数据
				else
					LCD_ShowxNum(30+(i-4)*32,290,CAN_buf[i],3,16,0x80);
			}
		}
		
		t++;
		delay_ms(10);
		
		if(t==20)
		{
			LED0=!LED0;
			t=0;
			cnt++;
			LCD_ShowxNum(30+48,170,cnt,3,16,0x80);
		}
	}
}
```



















