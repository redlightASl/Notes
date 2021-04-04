# 前置知识：STM32编程方式

* 在线编程（**ICP**）

通过==JTAG/SWD协议或Bootloader下载==用户程序到mcu

* 在程序中编程（**IAP**）

通过任意通信接口（IO、USB、CAN、USART、I2C、SPI等）下载程序或应用数据到存储器中

==STM32允许用户在应用程序中烧录FLASH中的内容==

局限性：使用前==需要有bootloader==被以ICP方式烧录进FLASH中

# 前置知识：FLASH结构

| 块                                                      | 名称                                                         | 块基地址                | 大小  |
| ------------------------------------------------------- | ------------------------------------------------------------ | ----------------------- | ----- |
| ==主存储器==                                            | 扇区0                                                        | 0x0800 0000-0x0800 3FFF | 16KB  |
| 共12扇区                                                | 扇区1                                                        | 0x0800 4000-0x0800 7FFF | 16KB  |
|                                                         | 扇区2                                                        | 0x0800 8000-0x0800 BFFF | 16KB  |
| 起始地址:0x0800 0000                                    | 扇区3                                                        | 0x0800 C000-0x0800 FFFF | 16KB  |
|                                                         | 扇区4                                                        | 0x0801 0000-0x0801 FFFF | 64KB  |
| （**存放数据常数 和 代码**）                            | 扇区5                                                        | 0x0802 0000-0x0803 FFFF | 128KB |
|                                                         | 扇区6                                                        | 0x0804 0000-0x080% FFFF | 128KB |
| B0、B1接GND时从此开始运行代码                           | ...                                                          | ...                     | ...   |
|                                                         | 扇区11                                                       | 0x080E 0000-0x080F FFFF | 128KB |
| ==系统存储器== （**存放bootloader**）                   | B0接3.3V，B1接GND时从此开始运行，进入串口下载模式            | 0x1FFF 0000-0x1FFF 77FF | 30KB  |
| ==OTP区域==（**一次性可编程区域**）                     | OTP区域用完一次永远不能擦除。前512B存储用户数据；后16B用于锁定对应块 | 0x1FFF 7800-0x1FFF 7A0F | 528B  |
| ==选项字节==                                            | 用于配置读保护、BOR级别、软件/硬件看门狗、器件复位           | 0x1FFF C000-0x1FFF C00F | 16B   |
|                                                         |                                                              |                         |       |
| stm32f407zgt6                                           | FLASH=1024KB=1MB                                             |                         |       |
| 在进行FLASH写或擦除操作时，不能进行代码或数据的读取操作 |                                                              |                         |       |
| 此表针对                                                | stm32f40x和stm32f41x                                         | 具体情况参考芯片手册    |       |

# 前置知识：FLASH相关寄存器

#### FLASH访问控制寄存器 FLASH_ACR

主要用于设置latency、功能配置

#### FLASH密钥寄存器 FLASH_KEYR

主要用于解锁FLASH擦写

#### FLASH控制寄存器 FLASH_CR

主要用于擦除/写入FLASH的模式控制等

#### FLASH状态寄存器 FLASH_SR

主要用于获取FLASH运行状态和对FLASH读取进行操作

# 嵌入式FLASH编程

1. FLASH读取

   * 从addr读取一个字（字节8位、半字16位、字32位）

     data=\*(vu32\*)addr

     将addr强制转换为vu32指针，取其指向地址的值（addr地址的值）

   * vu32对应字，vu16对应半字，vu8对应字节

   * 必须根据cpu时钟**HCLK**和**器件电源电压**在FLASH存取控制寄存器**FLASH_ACR**中正确设置等待周期数**LATENCY**

     ==当电源电压低于2.1V时，必须关闭预取缓冲器==

     对应关系可参考芯片手册“FLASH等待周期与CPU时钟频率之间的对应关系”表

     当供电电压3.3V，HCLK=168MHz时，LATENCY=5，否则FLASH读写可能出错导致死机

2. FLASH编程与擦除操作

   * 对stm32f4的FLASH进行写入或擦除操作器件，任何读取尝试都会导致总线堵塞，只有完成编程操作后才能正确进行读操作，每次读取前都需要判断FLASH是否busy

   * stm32f4复位后，FLASH编程是被保护的，只有写入特定的序列到FLASH_KEYR寄存器才能解除保护，解除保护后才能操作相关寄存器

     1. 写**0x45670123**  (KEY1)
     2. 写**0xCDEF89AB**  (KEY2)

     ==如果写入错误，FLASH_CR将被锁定，直到下次复位后才能再次解锁==

   * 可以通过FLASH_CR的PSIZE字段设置FLASH编程位数，**PSIZE设置必须与电源电压匹配**，**3.3V供电下，PSIZE必须设置为10，即32位并行位数**，擦除、编程都必须以32位为基础进行
   * FLASH编程时，要求写入地址的FLASH是被擦除的（其值必须为0xFFFFFFFF），否则无法写入；擦除是以sector为单位的，一次擦除必须将某个sector中的内容全部擦除

3. FLASH标准编程步骤

   1. 检查FLASH_SR中的BSY位，确保当前未执行任何FLASH操作
   2. 将FLASH_CR寄存器中的PG位置1，激活（解锁）FLASH编程
   3. 针对所需存储器地址（主存储器或OTP区域）执行数据写入操作
      * 并行位数为x8时按字节写入（PSIZE=00）
      * 并行位数为x16时按半字写入（PSIZE=01）
      * 并行位数为x32时按字写入（PSIZE=02）
      * 并行位数为x64时按双字写入（PSIZE=03）

   4. 等待BSY清零，完成一次编程

### FLASH擦除

* 扇区擦除

  1. 检查FLASH_CR是否解锁，如果没有则解锁
  2. 检查BSY位，确保当前未执行任何FLASH操作
  3. 将FLASH_CR寄存器的SER位置1，并选择要擦除的扇区（12块里选1块）
  4. 将FLASH_CR中的STRT位置1，触发擦除操作
  5. 等待BSY位清零

* 整片（批量）擦除

  1. 检查BSY位，确保当前未执行任何FLASH操作
  2. 在FLASH_CR寄存器中将MER位置1（**stm32f407xx专用**）
  3. 在FLASH_CR中的STRT位置1，触发擦除操作
  4. 等待BSY位清零

# 程序实现

正点原子采用例程：FLASH模拟EEPROM

flash.c

```c
#include <assert.h>
#include "stmflash.h"
#include "delay.h"

//返回从地址faddr读取的一个字
u32 STMFLASH_read_word(u32 faddr)
{
	return *(vu32*)faddr;
}

//从指定位置开始连续读取length个字的数据
//read_addr_begin：起始位置
//p_buffer：数据指针
//length：读数长度
void STMFLASH_read(u32 read_addr_begin,u32* p_buffer,u32 length)
{
	u32 i;
	if(read_addr_begin%4)
		return;//read_addr_begin只能是4的倍数
	
	for(i=0;i<length;i++)
	{
		p_buffer[i]=STMFLASH_read_word(read_addr_begin);//读取4字节
		read_addr_begin+=4;//偏移4字节
	}
}


//从指定位置开始连续写入length个字的数据
//局限性:因为STM32F4的扇区实在太大,没办法本地保存扇区数据,所以本函数
//         写地址如果非0XFF,那么会先擦除整个扇区且不保存扇区数据.所以
//         写非0XFF的地址,将导致整个扇区数据丢失.建议写之前确保扇区里
//         没有重要数据,最好是整个扇区先擦除了,然后慢慢往后写
//该函数对OTP区域也有效
//OTP区域地址范围:0X1FFF7800~0X1FFF7A0F
//write_addr_begin：起始位置
//p_buffer：数据指针
//length：读数长度 
void STMFLASH_write(u32 write_addr_begin,u32* p_buffer,u32 length)
{
	u32 addrx=0;//设置可疑擦除地址，这里是为了不影响后面的写数据使用write_addr_begin才开begin_addr
	u32 end_addr=0;//设置写入结束地址
	
	//1. 设置写入程序执行时的FLASH状态
	FLASH_Status status=FLASH_COMPLETE;
	
	//2. 保证输入安全性并解锁写入
	if(write_addr_begin<STM32_FLASH_BASE||write_addr_begin%4)//若写入地址小于主存储器基地址或不是4的整数倍
		return;//非法地址，退出
	FLASH_Unlock();//否则为合法地址，解锁FLASH写入	
	FLASH_DataCacheCmd(DISABLE);//FLASH擦除期间,必须禁止数据缓存
	
	//3. 对非FFFFFFFF的地方执行按扇区擦除
	addrx=write_addr_begin;
	end_addr=write_addr_begin+length*4;
  if(addrx<0X1FFF0000)//只有主存储区才需要执行擦除操作
	{
		while(addrx<end_addr)
		{
			if(STMFLASH_read_word(addrx)!=0XFFFFFFFF)
			{   
				status=FLASH_EraseSector(STMFLASH_get_flash_sector(addrx),VoltageRange_3);
                //VCC=2.7~3.6V之间使用VoltageRange_3参数
				if(status!=FLASH_COMPLETE)
					break;//发生错误
			}
			else
				addrx+=4;//按字移动进行判断并擦除
		} 
	}
 		
	//4. 写数据
	if(status==FLASH_COMPLETE)
	{
		for(;write_addr_begin<end_addr;write_addr_begin+=4)//按字节写入
		{
			if(FLASH_ProgramWord(write_addr_begin,*p_buffer)!=FLASH_COMPLETE)
			{ 
				break;//如果写入时FLASH状态不为COMPLETE则发生写入异常
			}
			p_buffer++;
		} 
	}
	
	//5. 结束写入
  FLASH_DataCacheCmd(ENABLE);//FLASH擦除结束,可以开启数据缓存
	FLASH_Lock();//锁定FLASH
}


//输入地址addr，返回此地址所在的扇区
//返回扇区数0-11
uint16_t STMFLASH_get_flash_sector(u32 addr)
{
	if(addr<ADDR_FLASH_SECTOR_1)
		return 0;
	else if(addr<ADDR_FLASH_SECTOR_2)
		return 1;
	else if(addr<ADDR_FLASH_SECTOR_3)
		return 2;
	else if(addr<ADDR_FLASH_SECTOR_4)
		return 3;
	else if(addr<ADDR_FLASH_SECTOR_5)
		return 4;
	else if(addr<ADDR_FLASH_SECTOR_6)
		return 5;
	else if(addr<ADDR_FLASH_SECTOR_7)
		return 6;
	else if(addr<ADDR_FLASH_SECTOR_8)
		return 7;
	else if(addr<ADDR_FLASH_SECTOR_9)
		return 8;
	else if(addr<ADDR_FLASH_SECTOR_10)
		return 9;
	else if(addr<ADDR_FLASH_SECTOR_11)
		return 10;
	return 11;
}
```

flash.h

```c
#ifndef __STMFLASH_H
	#define __STMFLASH_H
	#include "sys.h"
	
	//FLASH起始地址
	#define STM32_FLASH_BASE 0x08000000 	//STM32 FLASH的起始地址

	//FLASH 扇区的起始地址
	#define ADDR_FLASH_SECTOR_0     ((u32)0x08000000) 	//扇区0起始地址, 16 Kbytes  
	#define ADDR_FLASH_SECTOR_1     ((u32)0x08004000) 	//扇区1起始地址, 16 Kbytes  
	#define ADDR_FLASH_SECTOR_2     ((u32)0x08008000) 	//扇区2起始地址, 16 Kbytes  
	#define ADDR_FLASH_SECTOR_3     ((u32)0x0800C000) 	//扇区3起始地址, 16 Kbytes  
	#define ADDR_FLASH_SECTOR_4     ((u32)0x08010000) 	//扇区4起始地址, 64 Kbytes  
	#define ADDR_FLASH_SECTOR_5     ((u32)0x08020000) 	//扇区5起始地址, 128 Kbytes  
	#define ADDR_FLASH_SECTOR_6     ((u32)0x08040000) 	//扇区6起始地址, 128 Kbytes  
	#define ADDR_FLASH_SECTOR_7     ((u32)0x08060000) 	//扇区7起始地址, 128 Kbytes  
	#define ADDR_FLASH_SECTOR_8     ((u32)0x08080000) 	//扇区8起始地址, 128 Kbytes  
	#define ADDR_FLASH_SECTOR_9     ((u32)0x080A0000) 	//扇区9起始地址, 128 Kbytes  
	#define ADDR_FLASH_SECTOR_10    ((u32)0x080C0000) 	//扇区10起始地址,128 Kbytes  
	#define ADDR_FLASH_SECTOR_11    ((u32)0x080E0000) 	//扇区11起始地址,128 Kbytes  

	u32 STMFLASH_read_word(u32 faddr);//从faddr读取一个字
	void STMFLASH_read(u32 read_addr_begin,u32* p_buffer,u32 length);//从指定地址开始读取指定长度的数据
	void STMFLASH_write(u32 write_addr_begin,u32* p_buffer,u32 length);//从指定地址开始写入指定长度的数据
	
	uint16_t STMFLASH_get_flash_sector(u32 addr);//获取某个值所在的FLASH扇区
	
#endif
```

main.c

```c
#include "sys.h"
#include "delay.h"
#include "stmflash.h"

const u8 TEXT_Buffer[]={"STM32 FLASH TEST"};//要写入到STM32 FLASH的字符串数组
#define TEXT_LENTH sizeof(TEXT_Buffer) //数组长度	
#define SIZE TEXT_LENTH/4+((TEXT_LENTH%4)?1:0) //

#define FLASH_SAVE_ADDR 0X0800C004 
//设置FLASH 保存地址(必须为偶数，且所在扇区要大于本代码所占用到的扇区)
//否则写操作的时候可能会导致擦除整个扇区,从而引起部分程序丢失引起死机


int main(void)
{ 
	u8 key=0;
	u16 i=0;
	u8 datatemp[SIZE];
	
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//设置系统中断优先级分组2
	delay_init(168);//初始化延时函数
	LED_Init();//初始化LED 
 	LCD_Init();//初始化LCD  
 	KEY_Init();//初始化按键
    
 	POINT_COLOR=RED;//设置字体为红色
	LCD_ShowString(30,50,200,16,16,"WOW");	
	LCD_ShowString(30,70,200,16,16,"FLASH EEPROM TEST");	
	LCD_ShowString(30,90,200,16,16,"Template Codes From ATOM@ALIENTEK");
	LCD_ShowString(30,110,200,16,16,"2020.12.8"); 
	LCD_ShowString(30,130,200,16,16,"KEY1:Write  KEY0:Read");
    
	while(1)
	{
		key=KEY_Scan(0);
        
		if(key==KEY1_PRES)//KEY1按下,写入STM32 FLASH
		{
			LCD_Fill(0,170,239,319,WHITE);//清除半屏
 			LCD_ShowString(30,170,200,16,16,"Start Write FLASH...");
			STMFLASH_Write(FLASH_SAVE_ADDR,(u32*)TEXT_Buffer,SIZE);
			LCD_ShowString(30,170,200,16,16,"FLASH Write Finished");//提示传送完成
		}
		else if(key==KEY0_PRES)//KEY0按下,读取字符串并显示
		{
 			LCD_ShowString(30,170,200,16,16,"Start Read FLASH....");
			STMFLASH_Read(FLASH_SAVE_ADDR,(u32*)datatemp,SIZE);
			LCD_ShowString(30,170,200,16,16,"The Data Readed Is:  ");//提示传送完成
			LCD_ShowString(30,190,200,16,16,datatemp);//显示读到的字符串
		}
        
		i++;
		delay_ms(10);
        
		if(i==20)
		{
			LED0=!LED0;//提示系统正在运行	
			i=0;
		}
	}    
}
```
