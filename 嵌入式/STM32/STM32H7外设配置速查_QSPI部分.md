# QSPI协议

QSPI是Queued SPI（队列串行外围接口）的缩写，是由摩托罗拉公司推出的SPI协议的一个扩展，比SPI应用更加广泛，现在的FLASH、SRAM等存储器大多支持QSPI协议——QSPI是一种==专用==的通信接口，可连接单、双或四线SPI存储器

QSPI在SPI协议的基础上增加了**队列传输机制**。

STM32将Queued SPI协议接口实现为QUADSPI接口。QSPI的实现和SPI基本相似，有部分不同点，在下面列出。

## 物理连接

QSPI是标准的四信号线SPI，MCU与外设之间由六根线连接：NSS、IO0、IO1、IO2、IO3、SCLK，其中IO0-3是数据线；NSS又称CS，是片选信号线；SCLK又称SCK，是SPI/QSPI的同步时钟线

## 通信规则

### 读写命令

**有且仅有一条数据线工作**

### 读写数据

**四条数据线同时工作**

读写地址位时四条数据线发送不同的地址，从机自行分辨，引导向各自的地址；读写具体数据时根据对应的地址读写

# STM32F1中的SPI特性

* 三线全双工同步传输
* 双线/三线单工同步传输
* 8位/16位传输帧格式选择
* 主从操作、支持多主模式
* 8个主模式波特率分频系数（最高可达$f_{PCLK}/2$）
* 硬件/软件可调的SS（CS片选信号）管理
* 相关底层配置可编程
* 可触发中断的发送/接收标志
* SPI总线忙碌标志位
* 支持硬件CRC校验
* 支持DMA

# STM32F4中的SPI实现

## 特性

* 支持SPI的TI模式（主要是片选信号差异，用于TI系的IC）

* 支持F1的全部功能

与F1的功能基本一致，满足SPI接口的使用需要

## 硬件实现

1. 寄存器配置SPI设置
2. 波特率发生器配置SCLK
3. MOSI、MISO通过移位寄存器进行收发数据，接收数据即将数据从移位寄存器中复制到RxFIFO；发送数据即将数据放入TxFIFO后送入移位寄存器
4. 主控制逻辑电路和通信控制电路调配相关收发过程

## HAL库实现

直接**将收发数据封装为库函数**

# STM32F7中的SPI特点

* 支持F4的所有功能
* 可调传输帧格式4位到16位（对应原来的8位/16位传输帧格式选择）

* 具有DMA功能的两个32位内置Rx、Tx FIFO缓存

# STM32H7中的SPI实现

## 特性

* 支持F7的所有功能
* 数据帧格式大小可从4位到32位
* **双时钟域**，外设内核时钟可以独立于PCLK
* 更高的主频，8个主模式波特率预分频器（没有改动），主从模式频率均最高可达内核频率的1/2（$f_{FCLK}/2$）
* 保护配置和设置
* 数据之间的最小延时、SS与数据流之间的最小延时均可调
* 底层配置可编程，支持SS信号极性、时序可编程和MISOxMOSI交互功能
* 可调节的主器件接收器采样时间
* 配备停止模式（不向外设IP提供时钟）
* 具有停止模式下从器件发送/接收功能和低功耗唤醒功能
* 可编程的FIFO阈值（数据打包）
* 可编程的传输数据量
* 具有DMA功能的Rx、Tx FIFO容量扩大到16x8位或8x8位且可选
* 从模式下，下溢条件可配置，支持级联循环缓冲区

H7的SPI控制器比之前版本的控制器自由度更高（但大部分情况下用不上）

## 硬件实现

与之前的SPI控制器基本相同，但多了双时钟域的功能块：时钟寄存器控制时钟发生器工作，可以由SPI_PCLK或SPI_KER_CK提供时钟，SPI_KER_CK时钟直接提供给时钟发生器，进而用于SCK或MCK

## 软件配置

1. 在CubeMX中根据外设IC配置GPIO复用和SPI相关设定
2. CubeMX会使能外设时钟、配置SPI模式、地址、速率等参数并使能SPI外设；模式设定与f4设定基本类似，可参考【STM32F4外设配置速查总线协议部分】
3. 编写对应外设IC的驱动程序
4. 设置检验程序，上电后检验驱动程序及外设连接情况
5. 编写应用程序

# STM32F7/H7中的QSPI实现

QUADSPI主要用于控制SPI FLASH器件（只要满足QSPI时序就可以控制其他器件），工作在以下三种模式：

1. 间接模式：使用QUADSPI寄存器执行全部操作
2. **状态轮询模式**：周期性轮询外部FLASH状态寄存器，如果为1（擦除/烧写完毕）则引发中断
3. **内存映射模式**：外部FLASH映射到MCU片上SRAM地址空间，系统将其视作**内部FLASH**存储器进行操作（==内部FLASH只读==）

特别地，采用双闪存模式时，将**同时访问两个QSPI FLASH，吞吐量和容量*2**

## 特性

* 双闪存模式：并行访问两块FLASH，同时收发8位数据
* 支持SDR和DDR模式
* 集成接收/发送FIFO
* 允许8、16、32位数据访问
* 间接模式下可使用DMA
* 可使能的FIFO溢出、超时、操作完成、访问错误中断（异常）

## 硬件实现

可以实现单线、双线、四线SPI功能

与SPI控制器的不同点主要在于：FIFO和外设寄存器直接接入AHB总线

双闪存模式下，外设引脚复用可选择一个CS信号线或两个CS信号线

其他内容可参考MCU数据手册

## 软件配置

1. 基本配置同上

外部SPI FLASH驱动代码如下，与上面的代码差别不大

```c
/* W25Q256.h文件的函数声明 */
void NORFLASH_Init(void);													//初始化W25QXX
void NORFLASH_Qspi_Enable(void);											//使能QSPI模式
void NORFLASH_Qspi_Disable(void);											//关闭QSPI模式
u16  NORFLASH_ReadID(void);													//读取FLASH ID
u8 	 NORFLASH_ReadSR(u8 regno);												//读取状态寄存器 
void NORFLASH_4ByteAddr_Enable(void);										//使能4字节地址模式
void NORFLASH_Write_SR(u8 regno,u8 sr);										//写状态寄存器
void NORFLASH_Write_Enable(void);  											//写使能 
void NORFLASH_Write_Disable(void);											//写保护
void NORFLASH_Write_NoCheck(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite);	//写flash,不校验
void NORFLASH_Read(u8* pBuffer,u32 ReadAddr,u16 NumByteToRead);   			//读取flash
void NORFLASH_Write(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite);			//写入flash
void NORFLASH_Erase_Chip(void);    	  										//整片擦除
void NORFLASH_Erase_Sector(u32 Dst_Addr);									//扇区擦除
void NORFLASH_Wait_Busy(void);           									//等待空闲

/* W25Q256.c文件全部内容 */
#include "norflash.h"
#include "qspi.h"
#include "delay.h"
#include "usart.h" 

u16 NORFLASH_TYPE=W25Q256;	//使用W25Q256
u8 NORFLASH_QPI_MODE=0;		//QSPI模式标志:0,SPI模式;1,QSPI模式

/**
 * 4Kbytes为一个Sector（扇区）
 * 16个扇区为1个Block（块）
 * W25Q64容量为8M字节,共有128个Block,2048个Sector，W25Q256刚好是它的4倍
 */

//初始化SPI FLASH的IO口
void NORFLASH_Init(void)
{ 
	u8 temp;
	QSPI_Init();						//初始化QSPI
 	NORFLASH_Qspi_Enable();				//使能QSPI模式
	NORFLASH_TYPE=NORFLASH_ReadID();	//读取FLASH ID
	if(NORFLASH_TYPE==W25Q64)
	{
		NORFLASH_Write_Enable();		//写使能
		QSPI_Send_CMD(W25X_SetReadParam,0,(3<<6)|(0<<4)|(0<<2)|(3<<0),0);
        //QSPI设置读参数指令,地址为0,4线传数据_8位地址_无地址_4线传输指令,无空周期,1个字节数据
		temp=3<<4;						//设置P4&P5=11,8个dummy clocks,104M
		QSPI_Transmit(&temp,1);			//发送1个字节
	}
	printf("ID:%x\r\n",NORFLASH_TYPE);	//打印FLASH参数
}  

//W25QXX进入QSPI模式 
void NORFLASH_Qspi_Enable(void)
{
	u8 stareg2=0;
	stareg2=NORFLASH_ReadSR(2);			//先读出状态寄存器2的原始值 
	//printf("stareg2:%x\r\n",stareg2);	//打印参数
	if((stareg2&0X02)==0)				//QE位未使能
	{ 
		NORFLASH_Write_Enable();		//写使能 
		stareg2|=1<<1;					//使能QE位		
		NORFLASH_Write_SR(2,stareg2);	//写状态寄存器2
	}
	QSPI_Send_CMD(W25X_EnterQPIMode,0,(0<<6)|(0<<4)|(0<<2)|(1<<0),0);
    //写command指令,地址为0,无数据_8位地址_无地址_单线传输指令,无空周期,0个字节数据
	NORFLASH_QPI_MODE=1;				//标记QSPI模式
}

//W25QXX退出QSPI模式
void NORFLASH_Qspi_Disable(void)
{ 
	QSPI_Send_CMD(W25X_ExitQPIMode,0,(0<<6)|(0<<4)|(0<<2)|(3<<0),0);
    //写command指令,地址为0,无数据_8位地址_无地址_4线传输指令,无空周期,0个字节数据
	NORFLASH_QPI_MODE=0;//标记SPI模式
}

/* 读取W25QXX的状态寄存器 */
//W25QXX一共有3个状态寄存器
//状态寄存器1：
//BIT7  6   5   4   3   2   1   0
//SPR   RV  TB BP2 BP1 BP0 WEL BUSY
//SPR:默认0,状态寄存器保护位,配合WP使用
//TB,BP2,BP1,BP0:FLASH区域写保护设置
//WEL:写使能锁定
//BUSY:忙标记位(1,忙;0,空闲)
//默认:0x00
//状态寄存器2：
//BIT7  6   5   4   3   2   1   0
//SUS   CMP LB3 LB2 LB1 (R) QE  SRP1
//状态寄存器3：
//BIT7      6    5    4   3   2   1   0
//HOLD/RST  DRV1 DRV0 (R) (R) WPS ADP ADS
//regno:状态寄存器号，范:1~3
//返回值:状态寄存器值
u8 NORFLASH_ReadSR(u8 regno)   
{  
	u8 byte=0,command=0; 
    switch(regno)
    {
        case 1:
            command=W25X_ReadStatusReg1;    //读状态寄存器1指令
            break;
        case 2:
            command=W25X_ReadStatusReg2;    //读状态寄存器2指令
            break;
        case 3:
            command=W25X_ReadStatusReg3;    //读状态寄存器3指令
            break;
        default:
            command=W25X_ReadStatusReg1;    
            break;
    }   
	if(NORFLASH_QPI_MODE)
        QSPI_Send_CMD(command,0,(3<<6)|(0<<4)|(0<<2)|(3<<0),0);
    	//QSPI模式,写command指令,地址为0,4线传数据_8位地址_无地址_4线传输指令,无空周期,1个字节数据
	else
        QSPI_Send_CMD(command,0,(1<<6)|(0<<4)|(0<<2)|(1<<0),0);
    	//SPI模式,写command指令,地址为0,单线传数据_8位地址_无地址_单线传输指令,无空周期,1个字节数据
	QSPI_Receive(&byte,1);
    
	return byte;
}   

//写W25QXX状态寄存器
void NORFLASH_Write_SR(u8 regno,u8 sr)   
{   
    u8 command=0;
    switch(regno)
    {
        case 1:
            command=W25X_WriteStatusReg1;    //写状态寄存器1指令
            break;
        case 2:
            command=W25X_WriteStatusReg2;    //写状态寄存器2指令
            break;
        case 3:
            command=W25X_WriteStatusReg3;    //写状态寄存器3指令
            break;
        default:
            command=W25X_WriteStatusReg1;    
            break;
    }   
	if(NORFLASH_QPI_MODE)
        QSPI_Send_CMD(command,0,(3<<6)|(0<<4)|(0<<2)|(3<<0),0);
    	//QPI,写command指令,地址为0,4线传数据_8位地址_无地址_4线传输指令,无空周期,1个字节数据
	else
        QSPI_Send_CMD(command,0,(1<<6)|(0<<4)|(0<<2)|(1<<0),0);
        //SPI,写command指令,地址为0,单线传数据_8位地址_无地址_单线传输指令,无空周期,1个字节数据
	QSPI_Transmit(&sr,1);
}  

//W25QXX写使能
//将S1寄存器的WEL置位
void NORFLASH_Write_Enable(void)
{
	if(NORFLASH_QPI_MODE)
        QSPI_Send_CMD(W25X_WriteEnable,0,(0<<6)|(0<<4)|(0<<2)|(3<<0),0);
    	//QPI,写使能指令,地址为0,无数据_8位地址_无地址_4线传输指令,无空周期,0个字节数据
	else
        QSPI_Send_CMD(W25X_WriteEnable,0,(0<<6)|(0<<4)|(0<<2)|(1<<0),0);
    	//SPI,写使能指令,地址为0,无数据_8位地址_无地址_单线传输指令,无空周期,0个字节数据
} 

//W25QXX写禁止	
//将WEL清零  
void NORFLASH_Write_Disable(void)   
{  
	if(NORFLASH_QPI_MODE)
        QSPI_Send_CMD(W25X_WriteDisable,0,(0<<6)|(0<<4)|(0<<2)|(3<<0),0);
    	//QPI,写禁止指令,地址为0,无数据_8位地址_无地址_4线传输指令,无空周期,0个字节数据
	else
        QSPI_Send_CMD(W25X_WriteDisable,0,(0<<6)|(0<<4)|(0<<2)|(1<<0),0);
    	//SPI,写禁止指令,地址为0,无数据_8位地址_无地址_单线传输指令,无空周期,0个字节数据 
} 

//返回值如下:				   
//0XEF13,表示芯片型号为W25Q80  
//0XEF14,表示芯片型号为W25Q16    
//0XEF15,表示芯片型号为W25Q32  
//0XEF16,表示芯片型号为W25Q64 
//0XEF17,表示芯片型号为W25Q128 	  
//0XEF18,表示芯片型号为W25Q256
u16 NORFLASH_ReadID(void)
{
	u8 temp[2];
	u16 deviceid;
	if(NORFLASH_QPI_MODE)
        QSPI_Send_CMD(W25X_ManufactDeviceID,0,(3<<6)|(2<<4)|(3<<2)|(3<<0),0);
    	//QPI,读id,地址为0,4线传输数据_24位地址_4线传输地址_4线传输指令,无空周期,2个字节数据
	else
        QSPI_Send_CMD(W25X_ManufactDeviceID,0,(1<<6)|(2<<4)|(1<<2)|(1<<0),0);
    	//SPI,读id,地址为0,单线传输数据_24位地址_单线传输地址_单线传输指令,无空周期,2个字节数据
	QSPI_Receive(temp,2);
	deviceid=(temp[0]<<8)|temp[1];
    
	return deviceid;
}    

//读取SPI FLASH,仅支持QSPI模式
//在指定地址开始读取指定长度的数据
//pBuffer:数据存储区
//ReadAddr:开始读取的地址(最大32bit)
//NumByteToRead:要读取的字节数(最大65535)
void NORFLASH_Read(u8* pBuffer,u32 ReadAddr,u16 NumByteToRead)   
{ 
	QSPI_Send_CMD(W25X_FastReadData,ReadAddr,(3<<6)|(2<<4)|(3<<2)|(3<<0),8);
    //QPI,快速读数据,地址为ReadAddr,4线传输数据_24位地址_4线传输地址_4线传输指令,8空周期,NumByteToRead个数据
	QSPI_Receive(pBuffer,NumByteToRead); 
}

//SPI在一页(0~65535)内写入少于256个字节的数据
//在指定地址开始写入最大256字节的数据
//pBuffer:数据存储区
//WriteAddr:开始写入的地址(最大32bit)
//NumByteToWrite:要写入的字节数(最大256),该数不应该超过该页的剩余字节数!!!	 
void NORFLASH_Write_Page(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite)
{
	NORFLASH_Write_Enable();//写使能
	QSPI_Send_CMD(W25X_PageProgram,WriteAddr,(3<<6)|(2<<4)|(3<<2)|(3<<0),0);
    //QPI,页写指令,地址为WriteAddr,4线传输数据_24位地址_4线传输地址_4线传输指令,无空周期,NumByteToWrite个数据
	QSPI_Transmit(pBuffer,NumByteToWrite);
	NORFLASH_Wait_Busy();//等待写入结束
} 

//无检验写SPI FLASH
//必须确保所写的地址范围内的数据全部为0XFF,否则在非0XFF处写入的数据将失败!
//具有自动换页功能
//在指定地址开始写入指定长度的数据,但是要确保地址不越界!
//pBuffer:数据存储区
//WriteAddr:开始写入的地址(最大32bit)
//NumByteToWrite:要写入的字节数(最大65535)
//CHECK OK
void NORFLASH_Write_NoCheck(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite)   
{ 			 		 
	u16 pageremain;	   
	pageremain=256-WriteAddr%256;//单页剩余的字节数		 	    
	if(NumByteToWrite<=pageremain)pageremain=NumByteToWrite;//不大于256个字节
	while(1)
	{	   
		NORFLASH_Write_Page(pBuffer,WriteAddr,pageremain);
		if(NumByteToWrite==pageremain)
            break;//写入结束
	 	else//NumByteToWrite>pageremain
		{
			pBuffer+=pageremain;
			WriteAddr+=pageremain;	

			NumByteToWrite-=pageremain;//减去已经写入了的字节数
			if(NumByteToWrite>256)
                pageremain=256;//一次可以写入256个字节
			else
                pageremain=NumByteToWrite;//不够256个字节了
		}
	}   
} 

//写SPI FLASH
//在指定地址开始写入指定长度的数据
//该函数带擦除操作!
//pBuffer:数据存储区
//WriteAddr:开始写入的地址(最大32bit)
//NumByteToWrite:要写入的字节数(最大65535)
u8 NORFLASH_BUFFER[4096];

void NORFLASH_Write(u8* pBuffer,u32 WriteAddr,u16 NumByteToWrite)   
{ 
	u32 secpos;
	u16 secoff;
	u16 secremain;
 	u16 i;
	u8 * NORFLASH_BUF;

	NORFLASH_BUF=NORFLASH_BUFFER;
 	secpos=WriteAddr/4096;//扇区基地址
	secoff=WriteAddr%4096;//偏移地址
	secremain=4096-secoff;//扇区剩余空间大小
    
 	//printf("ad:%X,nb:%X\r\n",WriteAddr,NumByteToWrite);//测试用
 	if(NumByteToWrite<=secremain)
        secremain=NumByteToWrite;//如果待写入字节不大于4096个字节，将待写入大小限制为一个块大小
	while(1)
	{
		NORFLASH_Read(NORFLASH_BUF,secpos*4096,4096);//读出整个扇区的内容
		for(i=0;i<secremain;i++)//校验数据
		{
			if(NORFLASH_BUF[secoff+i]!=0XFF)//如果存在非空区域
                break;//需要擦除
		}
		if(i<secremain)//如果待写入字节小于剩余空间，需要擦除
		{
			NORFLASH_Erase_Sector(secpos);//擦除这个扇区
			for(i=0;i<secremain;i++)
			{
				NORFLASH_BUF[i+secoff]=pBuffer[i];//将写入内容复制到FLASH	  
			}
			NORFLASH_Write_NoCheck(NORFLASH_BUF,secpos*4096,4096);//写入整个扇区   
		}
        else//如果不需要擦除
            NORFLASH_Write_NoCheck(pBuffer,WriteAddr,secremain);//直接写入扇区剩余空区间
        
		if(NumByteToWrite==secremain)
            break;//写入结束
		else//写入未结束，接着写下一个扇区
		{
			secpos++;//扇区地址增1
			secoff=0;//偏移位置为0 	 

			pBuffer+=secremain;//指针偏移
			WriteAddr+=secremain;//写地址偏移
			NumByteToWrite-=secremain;//字节数递减
			if(NumByteToWrite>4096)
                secremain=4096;//下一个扇区还是写不完
			else
                secremain=NumByteToWrite;//下一个扇区可以写完了
		}
	}
}

//全片擦除
//等待时间会很长
void NORFLASH_Erase_Chip(void)
{
	NORFLASH_Write_Enable();//WEL置位
	NORFLASH_Wait_Busy();
	QSPI_Send_CMD(W25X_ChipErase,0,(0<<6)|(0<<4)|(0<<2)|(3<<0),0);
    //QPI,写全片擦除指令,地址为0,无数据_8位地址_无地址_4线传输指令,无空周期,0个字节数据
	NORFLASH_Wait_Busy();//等待芯片擦除结束
} 

//擦除一个扇区
//Dst_Addr:扇区地址 根据实际容量设置
//擦除一个扇区的最少时间:150ms
void NORFLASH_Erase_Sector(u32 Dst_Addr)   
{
	//printf("fe:%x\r\n",Dst_Addr);//监视falsh擦除情况,测试用  	  
	Dst_Addr*=4096;
	NORFLASH_Write_Enable();//WEL置位
	NORFLASH_Wait_Busy();
	QSPI_Send_CMD(W25X_SectorErase,Dst_Addr,(0<<6)|(2<<4)|(3<<2)|(3<<0),0);
    //QPI,写扇区擦除指令,地址为0,无数据_24位地址_4线传输地址_4线传输指令,无空周期,0个字节数据
	NORFLASH_Wait_Busy();//等待擦除完成
}

//等待空闲
void NORFLASH_Wait_Busy(void)   
{
	while((NORFLASH_ReadSR(1)&0x01)==0x01);	// 等待BUSY位清空
}
```

2. 配置QSPI

这里写的驱动代码是纯HAL库函数实现，外设IC是W25Q64 8MB大小

w25q64.h

```c
#ifndef w25q64_H
#define w25q64_H
#include "stm32h7xx_hal.h"
#include "main.h"

/*----------------------------------------------- 命名参数宏 -------------------------------------------*/

#define QSPI_W25Qxx_OK           		0			// W25Qxx通信正常
#define W25Qxx_ERROR_INIT         		-1			// 初始化错误
#define W25Qxx_ERROR_WriteEnable       -2			// 写使能错误
#define W25Qxx_ERROR_AUTOPOLLING       -3			// 轮询等待错误，无响应
#define W25Qxx_ERROR_Erase         		-4			// 擦除错误
#define W25Qxx_ERROR_TRANSMIT         	-5			// 传输错误
#define W25Qxx_ERROR_MemoryMapped		-6    		// 内存映射模式错误

#define W25Qxx_CMD_EnableReset  		0x66		// 使能复位
#define W25Qxx_CMD_ResetDevice   		0x99		// 复位器件
#define W25Qxx_CMD_JedecID 				0x9F		// JEDEC ID  
#define W25Qxx_CMD_WriteEnable			0X06		// 写使能

#define W25Qxx_CMD_SectorErase 			0x20		// 扇区擦除，4K字节， 参考擦除时间 45ms
#define W25Qxx_CMD_BlockErase_32K 		0x52		// 块擦除，  32K字节，参考擦除时间 120ms
#define W25Qxx_CMD_BlockErase_64K 		0xD8		// 块擦除，  64K字节，参考擦除时间 150ms
#define W25Qxx_CMD_ChipErase 			0xC7		// 整片擦除，参考擦除时间 20S

#define W25Qxx_CMD_QuadInputPageProgram  	0x32  	// 1-1-4模式下(1线指令1线地址4线数据)，页编程指令，参考写入时间 0.4ms 
#define W25Qxx_CMD_FastReadQuad_IO       	0xEB  	// 1-4-4模式下(1线指令4线地址4线数据)，快速读取指令

#define W25Qxx_CMD_ReadStatus_REG1			0X05	// 读状态寄存器1
#define W25Qxx_Status_REG1_BUSY  			0x01	// 读状态寄存器1的第0位（只读），Busy标志位，当正在擦除/写入数据/写命令时会被置1
#define W25Qxx_Status_REG1_WEL  			0x02	// 读状态寄存器1的第1位（只读），WEL写使能标志位，该标志位为1时，代表可以进行写操作

#define W25Qxx_PageSize       				256			// 页大小，256字节
#define W25Qxx_FlashSize       				0x800000	// W25Q64大小，8M字节
#define W25Qxx_FLASH_ID           			0Xef4017    // W25Q64 JEDEC ID
#define W25Qxx_ChipErase_TIMEOUT_MAX		100000U		// 超时等待时间，W25Q64整片擦除所需最大时间是100S
#define W25Qxx_Mem_Addr						0x90000000 	// 内存映射模式的地址

/*----------------------------------------------- 引脚配置宏 ------------------------------------------*/

#define QUADSPI_CLK_PIN				GPIO_PIN_2						// QUADSPI_CLK 引脚
#define	QUADSPI_CLK_PORT			GPIOB							// QUADSPI_CLK 引脚端口
#define	QUADSPI_CLK_AF				GPIO_AF9_QUADSPI				// QUADSPI_CLK IO口复用
#define GPIO_QUADSPI_CLK_ENABLE     __HAL_RCC_GPIOB_CLK_ENABLE()	// QUADSPI_CLK 引脚时钟使能

#define QUADSPI_BK1_NCS_PIN			GPIO_PIN_6						// QUADSPI_BK1_NCS 引脚
#define	QUADSPI_BK1_NCS_PORT		GPIOB							// QUADSPI_BK1_NCS 引脚端口
#define	QUADSPI_BK1_NCS_AF			GPIO_AF10_QUADSPI				// QUADSPI_BK1_NCS IO口复用
#define GPIO_QUADSPI_BK1_NCS_ENABLE __HAL_RCC_GPIOB_CLK_ENABLE()	// QUADSPI_BK1_NCS 引脚时钟使能

#define QUADSPI_BK1_IO0_PIN			GPIO_PIN_11						// QUADSPI_BK1_IO0 引脚
#define	QUADSPI_BK1_IO0_PORT		GPIOD							// QUADSPI_BK1_IO0 引脚端口
#define	QUADSPI_BK1_IO0_AF			GPIO_AF9_QUADSPI				// QUADSPI_BK1_IO0 IO口复用
#define GPIO_QUADSPI_BK1_IO0_ENABLE __HAL_RCC_GPIOD_CLK_ENABLE()	// QUADSPI_BK1_IO0 引脚时钟使能

#define QUADSPI_BK1_IO1_PIN			GPIO_PIN_2						// QUADSPI_BK1_IO1 引脚
#define	QUADSPI_BK1_IO1_PORT		GPIOE							// QUADSPI_BK1_IO1 引脚端口
#define	QUADSPI_BK1_IO1_AF			GPIO_AF9_QUADSPI				// QUADSPI_BK1_IO1 IO口复用
#define GPIO_QUADSPI_BK1_IO1_ENABLE __HAL_RCC_GPIOE_CLK_ENABLE()	// QUADSPI_BK1_IO1 引脚时钟使能

#define QUADSPI_BK1_IO2_PIN			GPIO_PIN_12						// QUADSPI_BK1_IO2 引脚
#define	QUADSPI_BK1_IO2_PORT		GPIOD							// QUADSPI_BK1_IO2 引脚端口
#define	QUADSPI_BK1_IO2_AF			GPIO_AF9_QUADSPI				// QUADSPI_BK1_IO2 IO口复用
#define GPIO_QUADSPI_BK1_IO2_ENABLE __HAL_RCC_GPIOD_CLK_ENABLE()	// QUADSPI_BK1_IO2 引脚时钟使能

#define QUADSPI_BK1_IO3_PIN			GPIO_PIN_13						// QUADSPI_BK1_IO3 引脚
#define	QUADSPI_BK1_IO3_PORT		GPIOD							// QUADSPI_BK1_IO3 引脚端口
#define	QUADSPI_BK1_IO3_AF			GPIO_AF9_QUADSPI				// QUADSPI_BK1_IO3 IO口复用
#define GPIO_QUADSPI_BK1_IO3_ENABLE __HAL_RCC_GPIOD_CLK_ENABLE()	// QUADSPI_BK1_IO3 引脚时钟使能

/*----------------------------------------------- 函数声明 --------------------------------------------*/

int8_t	QSPI_W25Qxx_Init(void);						// W25Qxx初始化
int8_t 	QSPI_W25Qxx_Reset(void);					// 复位器件
uint32_t QSPI_W25Qxx_ReadID(void);					// 读取器件ID
int8_t 	QSPI_W25Qxx_MemoryMappedMode(void);			// 进入内存映射模式
	
int8_t 	QSPI_W25Qxx_SectorErase(uint32_t SectorAddress);		// 扇区擦除，4K字节，参考擦除时间 45ms
int8_t 	QSPI_W25Qxx_BlockErase_32K (uint32_t SectorAddress);	// 块擦除，32K字节，参考擦除时间 120ms
int8_t 	QSPI_W25Qxx_BlockErase_64K (uint32_t SectorAddress);	// 块擦除，64K字节，参考擦除时间 150ms，实际使用建议使用64K擦除，擦除的时间最快
int8_t 	QSPI_W25Qxx_ChipErase (void);                         	// 整片擦除，参考擦除时间 20S

// 按页写入，最大256字节
int8_t	QSPI_W25Qxx_WritePage(uint8_t* pBuffer, uint32_t WriteAddr, uint16_t NumByteToWrite);
// 写入数据，最大不能超过flash芯片的大小
int8_t	QSPI_W25Qxx_WriteBuffer(uint8_t* pData, uint32_t WriteAddr, uint32_t Size);
// 读取数据，最大不能超过flash芯片的大小
int8_t 	QSPI_W25Qxx_ReadBuffer(uint8_t* pBuffer, uint32_t ReadAddr, uint32_t NumByteToRead);
#endif
```

w25q64.c

```c
#include "w25q64.h"
QSPI_HandleTypeDef hqspi;//定义QSPI句柄，这里保留使用cubeMX生成的变量命名，方便用户参考和移植

/* QSPI初始化 */
void HAL_QSPI_MspInit(QSPI_HandleTypeDef* hqspi)
{
	GPIO_InitTypeDef GPIO_InitStruct = {0};
	if(hqspi->Instance==QUADSPI)
	{
		__HAL_RCC_QSPI_CLK_ENABLE();	// 使能QSPI时钟

		GPIO_QUADSPI_CLK_ENABLE;		// 使能 QUADSPI_CLK IO口时钟
		GPIO_QUADSPI_BK1_NCS_ENABLE;	// 使能 QUADSPI_BK1_NCS IO口时钟
		GPIO_QUADSPI_BK1_IO0_ENABLE;	// 使能 QUADSPI_BK1_IO0 IO口时钟
		GPIO_QUADSPI_BK1_IO1_ENABLE;	// 使能 QUADSPI_BK1_IO1 IO口时钟
		GPIO_QUADSPI_BK1_IO2_ENABLE;	// 使能 QUADSPI_BK1_IO2 IO口时钟
		GPIO_QUADSPI_BK1_IO3_ENABLE;	// 使能 QUADSPI_BK1_IO3 IO口时钟
		
		/******************************************************  
		PB2     ------> QUADSPI_CLK	
		PB6     ------> QUADSPI_BK1_NCS 		
		PD11    ------> QUADSPI_BK1_IO0
		PD12    ------> QUADSPI_BK1_IO1		
		PE2     ------> QUADSPI_BK1_IO2	
		PD13    ------> QUADSPI_BK1_IO3
		*******************************************************/
		
		GPIO_InitStruct.Mode 		= GPIO_MODE_AF_PP;				// 复用推挽输出模式
		GPIO_InitStruct.Pull 		= GPIO_NOPULL;					// 无上下拉
		GPIO_InitStruct.Speed 		= GPIO_SPEED_FREQ_VERY_HIGH;	// 超高速IO口速度
		
		GPIO_InitStruct.Pin 			= QUADSPI_CLK_PIN;			// QUADSPI_CLK 引脚
		GPIO_InitStruct.Alternate 	= QUADSPI_CLK_AF;				// QUADSPI_CLK 复用
		HAL_GPIO_Init(QUADSPI_CLK_PORT, &GPIO_InitStruct);			// 初始化 QUADSPI_CLK 引脚

		GPIO_InitStruct.Pin 			= QUADSPI_BK1_NCS_PIN;		// QUADSPI_BK1_NCS 引脚
		GPIO_InitStruct.Alternate 	= QUADSPI_BK1_NCS_AF;			// QUADSPI_BK1_NCS 复用
		HAL_GPIO_Init(QUADSPI_BK1_NCS_PORT, &GPIO_InitStruct);   	// 初始化 QUADSPI_BK1_NCS 引脚
		
		GPIO_InitStruct.Pin 			= QUADSPI_BK1_IO0_PIN;		// QUADSPI_BK1_IO0 引脚
		GPIO_InitStruct.Alternate 	= QUADSPI_BK1_IO0_AF;			// QUADSPI_BK1_IO0 复用
		HAL_GPIO_Init(QUADSPI_BK1_IO0_PORT, &GPIO_InitStruct);		// 初始化 QUADSPI_BK1_IO0 引脚	
		
		GPIO_InitStruct.Pin 			= QUADSPI_BK1_IO1_PIN;		// QUADSPI_BK1_IO1 引脚
		GPIO_InitStruct.Alternate 	= QUADSPI_BK1_IO1_AF;			// QUADSPI_BK1_IO1 复用
		HAL_GPIO_Init(QUADSPI_BK1_IO1_PORT, &GPIO_InitStruct);   	// 初始化 QUADSPI_BK1_IO1 引脚
		
		GPIO_InitStruct.Pin 			= QUADSPI_BK1_IO2_PIN;		// QUADSPI_BK1_IO2 引脚
		GPIO_InitStruct.Alternate 	= QUADSPI_BK1_IO2_AF;			// QUADSPI_BK1_IO2 复用
		HAL_GPIO_Init(QUADSPI_BK1_IO2_PORT, &GPIO_InitStruct);		// 初始化 QUADSPI_BK1_IO2 引脚
		
		GPIO_InitStruct.Pin 			= QUADSPI_BK1_IO3_PIN;		// QUADSPI_BK1_IO3 引脚
		GPIO_InitStruct.Alternate 	= QUADSPI_BK1_IO3_AF;			// QUADSPI_BK1_IO3 复用
		HAL_GPIO_Init(QUADSPI_BK1_IO3_PORT, &GPIO_InitStruct);		// 初始化 QUADSPI_BK1_IO3 引脚
	}
}

void MX_QUADSPI_Init(void)
{
	hqspi.Instance 					= QUADSPI;									// QSPI外设
	
	/* QSPI的内核时钟设置为PLL2CLK，速度250M，经过2分频得到125M驱动时钟 */
	
    // 当使用内存映射模式时,这里的分频系数不能设置为0,否则会读取错误
	hqspi.Init.ClockPrescaler= 1;// 时钟分频值，将QSPI内核时钟进行 1+1 分频得到QSPI通信驱动时钟
	hqspi.Init.FifoThreshold= 32;// FIFO阈值
	hqspi.Init.SampleShifting= QSPI_SAMPLE_SHIFTING_HALFCYCLE;// 半个CLK周期之后进行采样
	hqspi.Init.FlashSize= 22;// flash大小，FLASH 中的字节数=2^[FSIZE+1]，对于8MB的W25Q64设置为22
	hqspi.Init.ChipSelectHighTime=QSPI_CS_HIGH_TIME_1_CYCLE;// 片选保持高电平的时间
	hqspi.Init.ClockMode=QSPI_CLOCK_MODE_3;// 模式3
	hqspi.Init.FlashID=QSPI_FLASH_ID_1;// 使用QSPI1
	hqspi.Init.DualFlash=QSPI_DUALFLASH_DISABLE;// 关闭双闪存模式
	// 应用配置
	HAL_QSPI_Init(&hqspi);
}

/* 检查W25Q64 */
int8_t QSPI_W25Qxx_Init(void)
{
	uint32_t Device_ID;
	
	MX_QUADSPI_Init();//初始化QSPI
	QSPI_W25Qxx_Reset();//复位
	Device_ID = QSPI_W25Qxx_ReadID();//读取ID
	
	if(Device_ID == W25Qxx_FLASH_ID )//检查外设器件
	{
		STM_printf ("W25Q64 OK,flash ID:%X\r\n",Device_ID);//初始化成功，打印debug信息
		return QSPI_W25Qxx_OK;//返回成功标志		
	}
	else
	{
		STM_printf ("W25Q64 ERROR!!!!!  ID:%X\r\n",Device_ID);//初始化失败	
		return W25Qxx_ERROR_INIT;//返回错误标志
	}	
}

//轮询确认FLASH是否空闲（用于等待通讯结束等）
int8_t QSPI_W25Qxx_AutoPollingMemReady(void)
{
	QSPI_CommandTypeDef     s_command;	   						// 	QSPI传输配置
	QSPI_AutoPollingTypeDef s_config;							// 	轮询比较相关配置参数

	s_command.InstructionMode   = QSPI_INSTRUCTION_1_LINE;		// 	1线指令模式
	s_command.AddressMode       = QSPI_ADDRESS_NONE;			// 	无地址模式
	s_command.AlternateByteMode = QSPI_ALTERNATE_BYTES_NONE;	//	无交替字节 
	s_command.DdrMode           = QSPI_DDR_MODE_DISABLE;	    // 	禁止DDR模式
	s_command.DdrHoldHalfCycle  = QSPI_DDR_HHC_ANALOG_DELAY;	// 	DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          = QSPI_SIOO_INST_EVERY_CMD;	   	//	每次传输数据都发送指令	
	s_command.DataMode          = QSPI_DATA_1_LINE;				// 	1线数据模式
	s_command.DummyCycles       = 0;							//	空周期个数
	s_command.Instruction       = W25Qxx_CMD_ReadStatus_REG1;	// 	读状态信息寄存器

// 不停查询 W25Qxx_CMD_ReadStatus_REG1 寄存器，将读取到的状态字节中的 W25Qxx_Status_REG1_BUSY 与0作比较
// 读状态寄存器1的第0位（只读），Busy标志位，当正在擦除/写入数据/写命令时会被置1，空闲或通信结束为0
    s_config.Match           = 0;   							//	匹配值
	s_config.MatchMode       = QSPI_MATCH_MODE_AND;	      		//	与运算
	s_config.Interval        = 0x10;	                     	//	轮询间隔
	s_config.AutomaticStop   = QSPI_AUTOMATIC_STOP_ENABLE;		// 自动停止模式
	s_config.StatusBytesSize = 1;	                        	//	状态字节数
	s_config.Mask=W25Qxx_Status_REG1_BUSY;//对在轮询模式下接收的状态字节进行屏蔽，只比较需要用到的位
		
	// 发送轮询等待命令
	if (HAL_QSPI_AutoPolling(&hqspi, &s_command, &s_config, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
		return W25Qxx_ERROR_AUTOPOLLING; // 轮询等待无响应
    
	return QSPI_W25Qxx_OK; // 通信正常结束
}

//FLASH软件复位
int8_t QSPI_W25Qxx_Reset(void)	
{
	QSPI_CommandTypeDef s_command;// QSPI传输配置

	s_command.InstructionMode   = QSPI_INSTRUCTION_1_LINE;   	// 1线指令模式
	s_command.AddressMode 		= QSPI_ADDRESS_NONE;   			// 无地址模式
	s_command.AlternateByteMode = QSPI_ALTERNATE_BYTES_NONE; 	// 无交替字节 
	s_command.DdrMode           = QSPI_DDR_MODE_DISABLE;     	// 禁止DDR模式
	s_command.DdrHoldHalfCycle  = QSPI_DDR_HHC_ANALOG_DELAY; 	// DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          = QSPI_SIOO_INST_EVERY_CMD;	 	// 每次传输数据都发送指令
	s_command.DataMode 			= QSPI_DATA_NONE;       		// 无数据模式	
	s_command.DummyCycles 		= 0;                     		// 空周期个数
	s_command.Instruction 		= W25Qxx_CMD_EnableReset;       // 执行复位使能命令

	// 发送复位使能命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) 
		return W25Qxx_ERROR_INIT;//如果发送失败，返回错误信息
	// 使用自动轮询标志位，等待通信结束
	if (QSPI_W25Qxx_AutoPollingMemReady() != QSPI_W25Qxx_OK)
		return W25Qxx_ERROR_AUTOPOLLING;// 轮询等待无响应

	s_command.Instruction  = W25Qxx_CMD_ResetDevice;//复位器件命令    

	//发送复位器件命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) 
		return W25Qxx_ERROR_INIT;// 如果发送失败，返回错误信息
    
	// 使用自动轮询标志位，等待通信结束
	if (QSPI_W25Qxx_AutoPollingMemReady() != QSPI_W25Qxx_OK)
		return W25Qxx_ERROR_AUTOPOLLING;// 轮询等待无响应
    
	return QSPI_W25Qxx_OK;// 复位成功
}

uint32_t QSPI_W25Qxx_ReadID(void)	
{
	QSPI_CommandTypeDef s_command;// QSPI传输配置
	uint8_t	QSPI_ReceiveBuff[3];// 存储QSPI读到的数据
	uint32_t W25Qxx_ID;// 器件的ID

	s_command.InstructionMode   = QSPI_INSTRUCTION_1_LINE;    	// 1线指令模式
	s_command.AddressSize       = QSPI_ADDRESS_24_BITS;     	// 24位地址
	s_command.AlternateByteMode = QSPI_ALTERNATE_BYTES_NONE;  	// 无交替字节 
	s_command.DdrMode           = QSPI_DDR_MODE_DISABLE;      	// 禁止DDR模式
	s_command.DdrHoldHalfCycle  = QSPI_DDR_HHC_ANALOG_DELAY;  	// DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          = QSPI_SIOO_INST_EVERY_CMD;	 	// 每次传输数据都发送指令
	s_command.AddressMode		= QSPI_ADDRESS_NONE;   			// 无地址模式
	s_command.DataMode			= QSPI_DATA_1_LINE;       	 	// 1线数据模式
	s_command.DummyCycles 		= 0;                   			// 空周期个数
	s_command.NbData 			= 3;                       		// 传输数据的长度
	s_command.Instruction 		= W25Qxx_CMD_JedecID;         	// 执行读器件ID命令

	// 发送指令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) 
		return W25Qxx_ERROR_INIT;// 如果发送失败，返回错误信息
	// 接收数据
	if (HAL_QSPI_Receive(&hqspi, QSPI_ReceiveBuff, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) 
		return W25Qxx_ERROR_TRANSMIT;// 如果接收失败，返回错误信息
    
	// 将得到的数据组合成ID
	W25Qxx_ID = (QSPI_ReceiveBuff[0] << 16) | (QSPI_ReceiveBuff[1] << 8 ) | QSPI_ReceiveBuff[2];
	return W25Qxx_ID;// 返回ID
}

//设置QSPI为内存映射模式
//此模式为只读状态，无法写入
int8_t QSPI_W25Qxx_MemoryMappedMode(void)
{
	QSPI_CommandTypeDef s_command;// QSPI传输配置
	QSPI_MemoryMappedTypeDef s_mem_mapped_cfg;// 内存映射访问参数

	s_command.InstructionMode   = QSPI_INSTRUCTION_1_LINE;    		// 1线指令模式
	s_command.AddressSize       = QSPI_ADDRESS_24_BITS;            	// 24位地址
	s_command.AlternateByteMode = QSPI_ALTERNATE_BYTES_NONE;  		// 无交替字节 
	s_command.DdrMode           = QSPI_DDR_MODE_DISABLE;     		// 禁止DDR模式
	s_command.DdrHoldHalfCycle  = QSPI_DDR_HHC_ANALOG_DELAY; 		// DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          = QSPI_SIOO_INST_EVERY_CMD;			// 每次传输数据都发送指令	
	s_command.AddressMode 		= QSPI_ADDRESS_4_LINES; 			// 4线地址模式
	s_command.DataMode    		= QSPI_DATA_4_LINES;    			// 4线数据模式
	s_command.DummyCycles 		= 6;                    			// 空周期个数
	s_command.Instruction 		= W25Qxx_CMD_FastReadQuad_IO; 		// 1-4-4模式下(1线指令4线地址4线数据)，快速读取指令
	
	s_mem_mapped_cfg.TimeOutActivation = QSPI_TIMEOUT_COUNTER_DISABLE; // 禁用超时计数器, nCS 保持激活状态
	s_mem_mapped_cfg.TimeOutPeriod     = 0;							   // 超时判断周期

	QSPI_W25Qxx_Reset();// 复位W25Qxx
	
	if (HAL_QSPI_MemoryMapped(&hqspi, &s_command, &s_mem_mapped_cfg) != HAL_OK)// 进行配置
		return W25Qxx_ERROR_MemoryMapped;// 设置内存映射模式错误

	return QSPI_W25Qxx_OK; // 配置成功
}

//写使能
int8_t QSPI_W25Qxx_WriteEnable(void)
{
	QSPI_CommandTypeDef     s_command;	   	// QSPI传输配置
	QSPI_AutoPollingTypeDef s_config;		// 轮询比较相关配置参数

	s_command.InstructionMode   	= QSPI_INSTRUCTION_1_LINE;    	// 1线指令模式
	s_command.AddressMode 			= QSPI_ADDRESS_NONE;   		    // 无地址模式
	s_command.AlternateByteMode 	= QSPI_ALTERNATE_BYTES_NONE;  	// 无交替字节 
	s_command.DdrMode           	= QSPI_DDR_MODE_DISABLE;      	// 禁止DDR模式
	s_command.DdrHoldHalfCycle  	= QSPI_DDR_HHC_ANALOG_DELAY;  	// DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          	= QSPI_SIOO_INST_EVERY_CMD;		// 每次传输数据都发送指令	
	s_command.DataMode 				= QSPI_DATA_NONE;       	    // 无数据模式
	s_command.DummyCycles 			= 0;                   	        // 空周期个数
	s_command.Instruction	 		= W25Qxx_CMD_WriteEnable;      	// 发送写使能命令

	// 发送写使能命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) 
		return W25Qxx_ERROR_WriteEnable;
// 不停的查询W25Qxx_CMD_ReadStatus_REG1寄存器，将读取到的状态字节中的W25Qxx_Status_REG1_WEL与0x02作比较
// 读状态寄存器1的第1位（只读），WEL写使能标志位，该标志位为1时，代表可以进行写操作
	
	s_config.Match           = 0x02;  								// 匹配值
	s_config.Mask			 = W25Qxx_Status_REG1_WEL;				// 读状态寄存器1的第1位（只读），WEL写使能标志位，该标志位为1时，代表可以进行写操作
	s_config.MatchMode       = QSPI_MATCH_MODE_AND;			 		// 与运算
	s_config.StatusBytesSize = 1;									// 状态字节数
	s_config.Interval        = 0x10;							 	// 轮询间隔
	s_config.AutomaticStop   = QSPI_AUTOMATIC_STOP_ENABLE;			// 自动停止模式

	s_command.Instruction    = W25Qxx_CMD_ReadStatus_REG1;			// 读状态信息寄存器
	s_command.DataMode       = QSPI_DATA_1_LINE;					// 1线数据模式
	s_command.NbData         = 1;									// 数据长度

	// 发送轮询等待命令	
	if (HAL_QSPI_AutoPolling(&hqspi, &s_command, &s_config, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
		return W25Qxx_ERROR_AUTOPOLLING;// 轮询等待无响应，返回错误
    
	return QSPI_W25Qxx_OK;// 通信正常结束
}

/* 擦除 */
//这里照搬原文档，指令都是重复的，不作注释
int8_t QSPI_W25Qxx_SectorErase(uint32_t SectorAddress)	
{
	QSPI_CommandTypeDef s_command;	// QSPI传输配置
	
	s_command.InstructionMode   	= QSPI_INSTRUCTION_1_LINE;    // 1线指令模式
	s_command.AddressSize       	= QSPI_ADDRESS_24_BITS;       // 24位地址模式
	s_command.AlternateByteMode 	= QSPI_ALTERNATE_BYTES_NONE;  //	无交替字节 
	s_command.DdrMode           	= QSPI_DDR_MODE_DISABLE;      // 禁止DDR模式
	s_command.DdrHoldHalfCycle  	= QSPI_DDR_HHC_ANALOG_DELAY;  // DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          	= QSPI_SIOO_INST_EVERY_CMD;	// 每次传输数据都发送指令
	s_command.AddressMode 			= QSPI_ADDRESS_1_LINE;        // 1线地址模式
	s_command.DataMode 				= QSPI_DATA_NONE;             // 无数据
	s_command.DummyCycles 			= 0;                          // 空周期个数
	s_command.Address           	= SectorAddress;              // 要擦除的地址
	s_command.Instruction	 		= W25Qxx_CMD_SectorErase;     // 扇区擦除命令

	// 发送写使能
	if (QSPI_W25Qxx_WriteEnable() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_WriteEnable;		// 写使能失败
	}
	// 发出擦除命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
	{
		return W25Qxx_ERROR_Erase;				// 擦除失败
	}
	// 使用自动轮询标志位，等待擦除的结束 
	if (QSPI_W25Qxx_AutoPollingMemReady() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_AUTOPOLLING;		// 轮询等待无响应
	}
	return QSPI_W25Qxx_OK; // 擦除成功
}

int8_t QSPI_W25Qxx_BlockErase_32K (uint32_t SectorAddress)	
{
	QSPI_CommandTypeDef s_command;	// QSPI传输配置
	
	s_command.InstructionMode   	= QSPI_INSTRUCTION_1_LINE;    // 1线指令模式
	s_command.AddressSize       	= QSPI_ADDRESS_24_BITS;       // 24位地址模式
	s_command.AlternateByteMode 	= QSPI_ALTERNATE_BYTES_NONE;  //	无交替字节 
	s_command.DdrMode           	= QSPI_DDR_MODE_DISABLE;      // 禁止DDR模式
	s_command.DdrHoldHalfCycle  	= QSPI_DDR_HHC_ANALOG_DELAY;  // DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          	= QSPI_SIOO_INST_EVERY_CMD;	// 每次传输数据都发送指令
	s_command.AddressMode 			= QSPI_ADDRESS_1_LINE;        // 1线地址模式
	s_command.DataMode 				= QSPI_DATA_NONE;             // 无数据
	s_command.DummyCycles 			= 0;                          // 空周期个数
	s_command.Address           	= SectorAddress;              // 要擦除的地址
	s_command.Instruction	 		= W25Qxx_CMD_BlockErase_32K;  // 块擦除命令，每次擦除32K字节

	// 发送写使能	
	if (QSPI_W25Qxx_WriteEnable() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_WriteEnable;		// 写使能失败
	}
	// 发出擦除命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
	{
		return W25Qxx_ERROR_Erase;				// 擦除失败
	}
	// 使用自动轮询标志位，等待擦除的结束 
	if (QSPI_W25Qxx_AutoPollingMemReady() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_AUTOPOLLING;		// 轮询等待无响应
	}
	return QSPI_W25Qxx_OK;	// 擦除成功
}

int8_t QSPI_W25Qxx_BlockErase_64K (uint32_t SectorAddress)	
{
	QSPI_CommandTypeDef s_command;	// QSPI传输配置
	
	s_command.InstructionMode   	= QSPI_INSTRUCTION_1_LINE;    // 1线指令模式
	s_command.AddressSize       	= QSPI_ADDRESS_24_BITS;       // 24位地址模式
	s_command.AlternateByteMode 	= QSPI_ALTERNATE_BYTES_NONE;  //	无交替字节 
	s_command.DdrMode           	= QSPI_DDR_MODE_DISABLE;      // 禁止DDR模式
	s_command.DdrHoldHalfCycle  	= QSPI_DDR_HHC_ANALOG_DELAY;  // DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          	= QSPI_SIOO_INST_EVERY_CMD;	// 每次传输数据都发送指令
	s_command.AddressMode 			= QSPI_ADDRESS_1_LINE;        // 1线地址模式
	s_command.DataMode 				= QSPI_DATA_NONE;             // 无数据
	s_command.DummyCycles 			= 0;                          // 空周期个数
	s_command.Address           	= SectorAddress;              // 要擦除的地址
	s_command.Instruction	 		= W25Qxx_CMD_BlockErase_64K;  // 块擦除命令，每次擦除64K字节	

	// 发送写使能
	if (QSPI_W25Qxx_WriteEnable() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_WriteEnable;	// 写使能失败
	}
	// 发出擦除命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
	{
		return W25Qxx_ERROR_Erase;			// 擦除失败
	}
	// 使用自动轮询标志位，等待擦除的结束 
	if (QSPI_W25Qxx_AutoPollingMemReady() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_AUTOPOLLING;	// 轮询等待无响应
	}
	return QSPI_W25Qxx_OK;		// 擦除成功
}

int8_t QSPI_W25Qxx_ChipErase (void)	
{
	QSPI_CommandTypeDef s_command;		// QSPI传输配置
	QSPI_AutoPollingTypeDef s_config;	// 轮询等待配置参数

	s_command.InstructionMode   	= QSPI_INSTRUCTION_1_LINE;    // 1线指令模式
	s_command.AddressSize       	= QSPI_ADDRESS_24_BITS;       // 24位地址模式
	s_command.AlternateByteMode 	= QSPI_ALTERNATE_BYTES_NONE;  //	无交替字节 
	s_command.DdrMode           	= QSPI_DDR_MODE_DISABLE;      // 禁止DDR模式
	s_command.DdrHoldHalfCycle  	= QSPI_DDR_HHC_ANALOG_DELAY;  // DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          	= QSPI_SIOO_INST_EVERY_CMD;	// 每次传输数据都发送指令
	s_command.AddressMode 			= QSPI_ADDRESS_NONE;       	// 无地址
	s_command.DataMode 				= QSPI_DATA_NONE;             // 无数据
	s_command.DummyCycles 			= 0;                          // 空周期个数
	s_command.Instruction	 		= W25Qxx_CMD_ChipErase;       // 擦除命令，进行整片擦除

	// 发送写使能	
	if (QSPI_W25Qxx_WriteEnable() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_WriteEnable;	// 写使能失败
	}
	// 发出擦除命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
	{
		return W25Qxx_ERROR_Erase;		 // 擦除失败
	}

// 不停的查询 W25Qxx_CMD_ReadStatus_REG1 寄存器，将读取到的状态字节中的 W25Qxx_Status_REG1_BUSY 不停的与0作比较
// 读状态寄存器1的第0位（只读），Busy标志位，当正在擦除/写入数据/写命令时会被置1，空闲或通信结束为0
	
	s_config.Match           = 0;   									//	匹配值
	s_config.MatchMode       = QSPI_MATCH_MODE_AND;	      	//	与运算
	s_config.Interval        = 0x10;	                     	//	轮询间隔
	s_config.AutomaticStop   = QSPI_AUTOMATIC_STOP_ENABLE;	// 自动停止模式
	s_config.StatusBytesSize = 1;	                        	//	状态字节数
	s_config.Mask            = W25Qxx_Status_REG1_BUSY;	   // 对在轮询模式下接收的状态字节进行屏蔽，只比较需要用到的位
	
	s_command.Instruction    = W25Qxx_CMD_ReadStatus_REG1;	// 读状态信息寄存器
	s_command.DataMode       = QSPI_DATA_1_LINE;					// 1线数据模式
	s_command.NbData         = 1;										// 数据长度

	// W25Q64整片擦除的典型参考时间为20s，最大时间为100s，这里的超时等待值 W25Qxx_ChipErase_TIMEOUT_MAX 为 100S
	if (HAL_QSPI_AutoPolling(&hqspi, &s_command, &s_config, W25Qxx_ChipErase_TIMEOUT_MAX) != HAL_OK)
	{
		return W25Qxx_ERROR_AUTOPOLLING;	 // 轮询等待无响应
	}
	return QSPI_W25Qxx_OK;
}

/* 写入 */
int8_t QSPI_W25Qxx_WritePage(uint8_t* pBuffer, uint32_t WriteAddr, uint16_t NumByteToWrite)
{
	QSPI_CommandTypeDef s_command;	// QSPI传输配置	
	
	s_command.InstructionMode   = QSPI_INSTRUCTION_1_LINE;    		// 1线指令模式
	s_command.AddressSize       = QSPI_ADDRESS_24_BITS;            // 24位地址
	s_command.AlternateByteMode = QSPI_ALTERNATE_BYTES_NONE;  		// 无交替字节 
	s_command.DdrMode           = QSPI_DDR_MODE_DISABLE;     		// 禁止DDR模式
	s_command.DdrHoldHalfCycle  = QSPI_DDR_HHC_ANALOG_DELAY; 		// DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          = QSPI_SIOO_INST_EVERY_CMD;			// 每次传输数据都发送指令	
	s_command.AddressMode 		 = QSPI_ADDRESS_1_LINE; 				// 1线地址模式
	s_command.DataMode    		 = QSPI_DATA_4_LINES;    				// 4线数据模式
	s_command.DummyCycles 		 = 0;                    				// 空周期个数
	s_command.NbData      		 = NumByteToWrite;      			   // 数据长度，最大只能256字节
	s_command.Address     		 = WriteAddr;         					// 要写入 W25Qxx 的地址
	s_command.Instruction 		 = W25Qxx_CMD_QuadInputPageProgram; // 1-1-4模式下(1线指令1线地址4线数据)，页编程指令
	
	// 写使能
	if (QSPI_W25Qxx_WriteEnable() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_WriteEnable;	// 写使能失败
	}
	// 写命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
	{
		return W25Qxx_ERROR_TRANSMIT;		// 传输数据错误
	}
	// 开始传输数据
	if (HAL_QSPI_Transmit(&hqspi, pBuffer, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
	{
		return W25Qxx_ERROR_TRANSMIT;		// 传输数据错误
	}
	// 使用自动轮询标志位，等待写入的结束 
	if (QSPI_W25Qxx_AutoPollingMemReady() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_AUTOPOLLING; // 轮询等待无响应
	}
	return QSPI_W25Qxx_OK;	// 写数据成功
}

int8_t QSPI_W25Qxx_WriteBuffer(uint8_t* pBuffer, uint32_t WriteAddr, uint32_t Size)
{	
	uint32_t end_addr, current_size, current_addr;
	uint8_t *write_data;  // 要写入的数据

	current_size = W25Qxx_PageSize - (WriteAddr % W25Qxx_PageSize); // 计算当前页还剩余的空间

	if (current_size > Size)	// 判断当前页剩余的空间是否足够写入所有数据
	{
		current_size = Size;		// 如果足够，则直接获取当前长度
	}

	current_addr = WriteAddr;		// 获取要写入的地址
	end_addr = WriteAddr + Size;	// 计算结束地址
	write_data = pBuffer;			// 获取要写入的数据

	do
	{
		// 发送写使能
		if (QSPI_W25Qxx_WriteEnable() != QSPI_W25Qxx_OK)
		{
			return W25Qxx_ERROR_WriteEnable;
		}

		// 按页写入数据
		else if(QSPI_W25Qxx_WritePage(write_data, current_addr, current_size) != QSPI_W25Qxx_OK)
		{
			return W25Qxx_ERROR_TRANSMIT;
		}

		// 使用自动轮询标志位，等待写入的结束 
		else 	if (QSPI_W25Qxx_AutoPollingMemReady() != QSPI_W25Qxx_OK)
		{
			return W25Qxx_ERROR_AUTOPOLLING;
		}

		else // 按页写入数据成功，进行下一次写数据的准备工作
		{
			current_addr += current_size;	// 计算下一次要写入的地址
			write_data += current_size;	// 获取下一次要写入的数据存储区地址
			// 计算下一次写数据的长度
			current_size = ((current_addr + W25Qxx_PageSize) > end_addr) ? (end_addr - current_addr) : W25Qxx_PageSize;
		}
	}
	while (current_addr < end_addr) ; // 判断数据是否全部写入完毕

	return QSPI_W25Qxx_OK;	// 写入数据成功
}

/* 读取 */
int8_t QSPI_W25Qxx_ReadBuffer(uint8_t* pBuffer, uint32_t ReadAddr, uint32_t NumByteToRead)
{
	QSPI_CommandTypeDef s_command;	// QSPI传输配置
	
	s_command.InstructionMode   = QSPI_INSTRUCTION_1_LINE;    		// 1线指令模式
	s_command.AddressSize       = QSPI_ADDRESS_24_BITS;            // 24位地址
	s_command.AlternateByteMode = QSPI_ALTERNATE_BYTES_NONE;  		// 无交替字节 
	s_command.DdrMode           = QSPI_DDR_MODE_DISABLE;     		// 禁止DDR模式
	s_command.DdrHoldHalfCycle  = QSPI_DDR_HHC_ANALOG_DELAY; 		// DDR模式中数据延迟，这里用不到
	s_command.SIOOMode          = QSPI_SIOO_INST_EVERY_CMD;			// 每次传输数据都发送指令	
	s_command.AddressMode 		 = QSPI_ADDRESS_4_LINES; 				// 4线地址模式
	s_command.DataMode    		 = QSPI_DATA_4_LINES;    				// 4线数据模式
	s_command.DummyCycles 		 = 6;                    				// 空周期个数
	s_command.NbData      		 = NumByteToRead;      			   	// 数据长度，最大不能超过flash芯片的大小
	s_command.Address     		 = ReadAddr;         					// 要读取 W25Qxx 的地址
	s_command.Instruction 		 = W25Qxx_CMD_FastReadQuad_IO; 		// 1-4-4模式下(1线指令4线地址4线数据)，快速读取指令
	
	// 发送读取命令
	if (HAL_QSPI_Command(&hqspi, &s_command, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
	{
		return W25Qxx_ERROR_TRANSMIT;		// 传输数据错误
	}

	//	接收数据
	
	if (HAL_QSPI_Receive(&hqspi, pBuffer, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)
	{
		return W25Qxx_ERROR_TRANSMIT;		// 传输数据错误
	}

	// 使用自动轮询标志位，等待接收的结束 
	if (QSPI_W25Qxx_AutoPollingMemReady() != QSPI_W25Qxx_OK)
	{
		return W25Qxx_ERROR_AUTOPOLLING; // 轮询等待无响应
	}
	return QSPI_W25Qxx_OK;	// 读取数据成功
}
```

可以看到，使用HAL库函数调用QSPI执行简单读写的基本方式是**==【QSPI传输配置】——【发送相关命令】——【读取回复】——【执行操作】——【等待接收完毕】==**

简单读写一般采用下面的方式：

```c
QSPI_Status=QSPI_W25Qxx_ReadBuffer(W25Qxx_ReadBuffer,W25Qxx_TestAddr,W25Qxx_NumByteToTest);//读取数据
QSPI_Status=QSPI_W25Qxx_BlockErase_32K(W25Qxx_TestAddr);//擦除32K字节,也可以调用上面.c文件里的其他擦除函数
QSPI_Status=QSPI_W25Qxx_WriteBuffer(W25Qxx_WriteBuffer,W25Qxx_TestAddr,W25Qxx_NumByteToTest);//写入数据
```

在软件中加入

```c
QSPI_Status = QSPI_W25Qxx_MemoryMappedMode();
```

即可在各模式之间切换，应当注意：**内存映射模式下，SPI FLASH只读**，使用以下指令进行读取

```c
memcpy(W25Qxx_ReadBuffer,(uint8_t *)W25Qxx_Mem_Addr+W25Qxx_TestAddr,W25Qxx_NumByteToTest);
//从 QSPI_Mem_Addr +W25Qxx_TestAddr 地址处复制数据到 W25Qxx_ReadBuffer
```

如果需要开启DMA，在.c文件中加入MDMA相关配置即可，如下所示

```c
MDMA_HandleTypeDef QSPI_MDMA_Handle;//定义MDMA句柄

void MX_MDMA_Init(void)
{
	__HAL_RCC_MDMA_CLK_ENABLE(); // 开启MDMA化时钟

	QSPI_MDMA_Handle.Instance = MDMA_Channel1; // 使用通道1
	QSPI_MDMA_Handle.Init.TransferTriggerMode = MDMA_BUFFER_TRANSFER; // 使用缓冲区传输	
	QSPI_MDMA_Handle.Init.BufferTransferLength 	= 128; // 缓冲区单次传输数据长度，最大128字节
	QSPI_MDMA_Handle.Init.Priority = MDMA_PRIORITY_VERY_HIGH; // 优先级最高
	QSPI_MDMA_Handle.Init.Request = MDMA_REQUEST_QUADSPI_FIFO_TH; // FIFO阈值触发中断请求
	QSPI_MDMA_Handle.Init.Endianness = MDMA_LITTLE_ENDIANNESS_PRESERVE; // 小端字节格式，不使用交换
	QSPI_MDMA_Handle.Init.DataAlignment = MDMA_DATAALIGN_PACKENABLE; // 所有字节右对齐，使用小端格式	
	QSPI_MDMA_Handle.Init.SourceInc = MDMA_SRC_INC_BYTE; // 源地址按照字节递增(8 bits)
	QSPI_MDMA_Handle.Init.SourceDataSize = MDMA_SRC_DATASIZE_BYTE; // 源地址数据宽度为1字节(8 bits)
	QSPI_MDMA_Handle.Init.SourceBurst = MDMA_SOURCE_BURST_SINGLE; // 源数据单次突发传输
	QSPI_MDMA_Handle.Init.DestinationInc = MDMA_DEST_INC_DISABLE; // 禁止目标地址自增 
	QSPI_MDMA_Handle.Init.DestDataSize = MDMA_DEST_DATASIZE_BYTE; // 目标地址数据宽度为1字节(8 bits)
	QSPI_MDMA_Handle.Init.DestBurst = MDMA_DEST_BURST_SINGLE; // 目标数据单次突发传输

	__HAL_LINKDMA(&hqspi, hmdma, QSPI_MDMA_Handle); // 关联MDMA句柄
	
    // 应用配置
	HAL_MDMA_Init(&QSPI_MDMA_Handle);

	HAL_NVIC_SetPriority(MDMA_IRQn, 0x0E, 0); // 设置MDMA中断优先级
	HAL_NVIC_EnableIRQ(MDMA_IRQn); // 使能MDMA中断
}

//在QSPI_W25Qxx_Init()中加入MDMA初始化
MX_MDMA_Init();// MDMA初始化

//加入MDMA中断回调函数用于标识QSPI接收结束
void HAL_QSPI_RxCpltCallback(QSPI_HandleTypeDef *hqspi)
{
	QSPI_RX_Status = 1;  // 当进入此中断函数时，说明QSPI接收完成，将标志变量置1
}

//将接收函数的if (HAL_QSPI_Receive(&hqspi, pBuffer, HAL_QPSI_TIMEOUT_DEFAULT_VALUE) != HAL_OK)都改成if (HAL_QSPI_Receive_DMA(&hqspi, pBuffer) != HAL_OK)或类似形式，相当于把基本读取方式改变为等待DMA中断，DMA一旦中断就表明数据收取完毕，CPU再接管数据
```

MDMA中断下，收发数据的应用层接口不变

```c
QSPI_Status=QSPI_W25Qxx_WriteBuffer(W25Qxx_WriteBuffer,W25Qxx_TestAddr,W25Qxx_NumByteToTest);//写入数据
QSPI_Status=QSPI_W25Qxx_BlockErase_32K(W25Qxx_TestAddr);//擦除32K字节
QSPI_Status=QSPI_W25Qxx_ReadBuffer(W25Qxx_ReadBuffer,W25Qxx_TestAddr,W25Qxx_NumByteToTest);//读取数据
```

## HAL库的QSPI使用总结

1. 间接模式下，使用QSPI**与使用其他外设一样**，通过寄存器配置，与SPI的使用方法大同小异
2. 自动轮询模式下，通过查询SPI FLASH的状态寄存器来使用，当读取/写入完成后轮询得到器件空闲，即可进行新一轮写入，可以配合MDMA使用，让其自动写入，CPU在中间还能做其他任务，轮询得到可以继续写入后再向buffer中填充写入数据或读取buffer中数据。可以使用**掩码**功能来**匹配状态位**
3. 内存映射模式下，将SPI FLASH视为STM32的片上FLASH，可以利用这个功能在片外SPI FLASH中存储程序。读取时使用指针即可，但SPI FLASH==**只读**==

# W25Qxx系列SPI FLASH特性

详见芯片手册

![W25Q64(3)](STM32H7外设配置速查_QSPI部分.assets/W25Q64(3).jpg)

![W25Q64(1)](STM32H7外设配置速查_QSPI部分.assets/W25Q64(1).jpg)

![W25Q64(2)](STM32H7外设配置速查_QSPI部分.assets/W25Q64(2).jpg)

* 支持标准摩托罗拉SPI协议
* 支持双线/四线SPI，通过写入IC内部的控制寄存器相关控制位，可将WP和Hold引脚作为IO2、IO3使用

相关指令如下

```c
//写保护
#define W25X_WriteEnable		0x06 
#define W25X_WriteDisable		0x04 
//读写W25Qxx状态寄存器
#define W25X_ReadStatusReg1		0x05 
#define W25X_ReadStatusReg2		0x35 
#define W25X_ReadStatusReg3		0x15 
#define W25X_WriteStatusReg1    0x01 
#define W25X_WriteStatusReg2    0x31 
#define W25X_WriteStatusReg3    0x11 
//读数据
#define W25X_ReadData			0x03 
#define W25X_FastReadData		0x0B 
#define W25X_FastReadDual		0x3B 
//按页写入
#define W25X_PageProgram		0x02 
//擦除
#define W25X_BlockErase			0xD8 
#define W25X_SectorErase		0x20 
#define W25X_ChipErase			0xC7 
//关闭/低功耗
#define W25X_PowerDown			0xB9 
#define W25X_ReleasePowerDown	0xAB 
//ID相关
#define W25X_DeviceID			0xAB 
#define W25X_ManufactDeviceID	0x90 
#define W25X_JedecDeviceID		0x9F 
//4字节地址模式
#define W25X_Enable4ByteAddr    0xB7
#define W25X_Exit4ByteAddr      0xE9
//设置读取参数
#define W25X_SetReadParam		0xC0 
//是否使用QSPI模式
#define W25X_EnterQPIMode       0x38
#define W25X_ExitQPIMode        0xFF
```

四字节地址模式：**使用该模式可以访问到W25Q256的所有空间**，对于容量小于等于16MB的SPI FLASH并不需要开启此模式（仅W25Q256可用此模式）

