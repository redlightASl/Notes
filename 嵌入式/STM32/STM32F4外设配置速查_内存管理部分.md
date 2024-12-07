# 内存管理

**内存管理：软件运行时对MCU内存资源的分配和使用的技术**

主要目的：高效、快速分配内存并在适当时刻释放和回收内存资源

实现方法：==实现或近似实现c语言定义的malloc()和free()函数==，malloc()用于内存申请，free()用于内存释放

## 分块式内存管理

由**内存池**和**内存管理表**组成

* 内存池

内存池被**等分为n块**，对应**大小为n**的内存管理表，内存管理表的每一个项对应内存池的一块内存

* 内存管理表

每一项代表一块对应的内存池，项为0时，代表对应的内存块未被占用；项非0时，代表对应的内存块已经被占用，数值代表被连续占用的内存块数

当内存管理刚初始化的时候，内存管理表全部清零，表示没有任何内存块被占用

* 内存分配方向

从顶到底的方向（出栈方向）：首先从内存池最末端找空内存

* 内存管理的实现

1. 通过malloc()申请内存
   1. 判断指针p要分配的内存块数
   2. 从第n项开始向下查找，直到找到m块连续的空内存块（即 对应内存管理表项为0）
   3. 将m个对应的内存管理表项的值都设置为m（即 标记被占用内存块）
   4. 将最后的空内存块地址返回指针p，完成分配
   5. 当查找到最后也没能找到连续的n块空闲内存时，返回NULL给p（即 内存不够时返回NULL）
2. 通过free()释放内存
   1. 查找指针p指向的内存地址对应的内存块
   2. 找到对应的内存管理表项
   3. 读取内存管理表项的值（即 获取p所占用的内存块数目）
   4. 将此后m个内存管理表项目的值都置0（即 标记释放）

## 硬件配置

一般对外部SRAM使用内存管理或在操作系统中内嵌

按照芯片手册配置硬件即可

## 软件配置

sram.h

```c
#ifndef __SRAM_H
	#define __SRAM_H															    
	#include "sys.h" 
											  
	void FSMC_SRAM_init(void);
	void FSMC_SRAM_write_buffer(u8* pBuffer,u32 WriteAddr,u32 NumHalfwordToWrite);
	void FSMC_SRAM_read_buffer(u8* pBuffer,u32 ReadAddr,u32 NumHalfwordToRead);

	void FSMC_SRAM_test_write(u32 addr,u8 data);
	u8 FSMC_SRAM_test_read(u32 addr);

#endif
```

sram.c

```c
#include "sram.h"

//使用NOR/SRAM的 Bank1.sector3,地址位HADDR[27,26]=10 
//对IS61LV25616/IS62WV25616,地址线范围为A0~A17 
//对IS61LV51216/IS62WV51216,地址线范围为A0~A18
#define Bank1_SRAM3_ADDR    ((u32)(0x68000000))	

//初始化外部SRAM
void FSMC_SRAM_init(void)
{	
	GPIO_InitTypeDef  GPIO_InitStructure;
	FSMC_NORSRAMInitTypeDef  FSMC_NORSRAMInitStructure;
    FSMC_NORSRAMTimingInitTypeDef  readWriteTiming; 
	
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB|\
                           RCC_AHB1Periph_GPIOD|\
                           RCC_AHB1Periph_GPIOE|\
                           RCC_AHB1Periph_GPIOF|\
                           RCC_AHB1Periph_GPIOG, ENABLE);//使能PD,PE,PF,PG时钟  
  	RCC_AHB3PeriphClockCmd(RCC_AHB3Periph_FSMC,ENABLE);//使能FSMC时钟  
   
	
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_15;//PB15 推挽输出,控制背光
  	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_OUT;//普通输出模式
  	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出
  	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;//100MHz
  	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//上拉
  	GPIO_Init(GPIOB, &GPIO_InitStructure);//初始化 //PB15 推挽输出,控制背光

	GPIO_InitStructure.GPIO_Pin = (3<<0)|(3<<4)|(0XFF<<8);//PD0,1,4,5,8~15 AF OUT
  	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;//复用输出
  	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出
  	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//100MHz
  	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//上拉
  	GPIO_Init(GPIOD, &GPIO_InitStructure);//初始化  
	
  	GPIO_InitStructure.GPIO_Pin = (3<<0)|(0X1FF<<7);//PE0,1,7~15,AF OUT
  	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;//复用输出
  	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出
  	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//100MHz
  	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//上拉
  	GPIO_Init(GPIOE, &GPIO_InitStructure);//初始化  
	
 	GPIO_InitStructure.GPIO_Pin = (0X3F<<0)|(0XF<<12); 	//PF0~5,12~15
 	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;//复用输出
  	GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出
  	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//100MHz
  	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//上拉
  	GPIO_Init(GPIOF, &GPIO_InitStructure);//初始化  

	GPIO_InitStructure.GPIO_Pin =(0X3F<<0)| GPIO_Pin_10;//PG0~5,10
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;//复用输出
    GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;//100MHz
	GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_UP;//上拉
    GPIO_Init(GPIOG, &GPIO_InitStructure);//初始化 
 
 
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource0,GPIO_AF_FSMC);//PD0,AF12
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource1,GPIO_AF_FSMC);//PD1,AF12
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource4,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource5,GPIO_AF_FSMC); 
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource8,GPIO_AF_FSMC); 
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource9,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource10,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource11,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource12,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource13,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource14,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOD,GPIO_PinSource15,GPIO_AF_FSMC);//PD15,AF12

    GPIO_PinAFConfig(GPIOE,GPIO_PinSource0,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource1,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource7,GPIO_AF_FSMC);//PE7,AF12
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource8,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource9,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource10,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource11,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource12,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource13,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource14,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOE,GPIO_PinSource15,GPIO_AF_FSMC);//PE15,AF12
 
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource0,GPIO_AF_FSMC);//PF0,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource1,GPIO_AF_FSMC);//PF1,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource2,GPIO_AF_FSMC);//PF2,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource3,GPIO_AF_FSMC);//PF3,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource4,GPIO_AF_FSMC);//PF4,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource5,GPIO_AF_FSMC);//PF5,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource12,GPIO_AF_FSMC);//PF12,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource13,GPIO_AF_FSMC);//PF13,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource14,GPIO_AF_FSMC);//PF14,AF12
    GPIO_PinAFConfig(GPIOF,GPIO_PinSource15,GPIO_AF_FSMC);//PF15,AF12

    GPIO_PinAFConfig(GPIOG,GPIO_PinSource0,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOG,GPIO_PinSource1,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOG,GPIO_PinSource2,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOG,GPIO_PinSource3,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOG,GPIO_PinSource4,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOG,GPIO_PinSource5,GPIO_AF_FSMC);
    GPIO_PinAFConfig(GPIOG,GPIO_PinSource10,GPIO_AF_FSMC);

 	readWriteTiming.FSMC_AddressSetupTime = 0x00;//地址建立时间（ADDSET）为1个HCLK 1/36M=27ns
  	readWriteTiming.FSMC_AddressHoldTime = 0x00;//地址保持时间（ADDHLD）模式A未用到	
  	readWriteTiming.FSMC_DataSetupTime = 0x08;//数据保持时间（DATAST）为9个HCLK 6*9=54ns	 	 
  	readWriteTiming.FSMC_BusTurnAroundDuration = 0x00;
  	readWriteTiming.FSMC_CLKDivision = 0x00;
  	readWriteTiming.FSMC_DataLatency = 0x00;
    readWriteTiming.FSMC_AccessMode = FSMC_AccessMode_A;//模式A 

    FSMC_NORSRAMInitStructure.FSMC_Bank = FSMC_Bank1_NORSRAM3;//NE3对应BTCR[4],[5]。
  	FSMC_NORSRAMInitStructure.FSMC_DataAddressMux = FSMC_DataAddressMux_Disable; 
  	FSMC_NORSRAMInitStructure.FSMC_MemoryType =FSMC_MemoryType_SRAM;//外部SRAM 
  	FSMC_NORSRAMInitStructure.FSMC_MemoryDataWidth = FSMC_MemoryDataWidth_16b;//存储器数据宽度为16位 
  	FSMC_NORSRAMInitStructure.FSMC_BurstAccessMode =FSMC_BurstAccessMode_Disable;//关闭突发访问模式
  	FSMC_NORSRAMInitStructure.FSMC_WaitSignalPolarity = FSMC_WaitSignalPolarity_Low;
	FSMC_NORSRAMInitStructure.FSMC_AsynchronousWait=FSMC_AsynchronousWait_Disable;
  	FSMC_NORSRAMInitStructure.FSMC_WrapMode = FSMC_WrapMode_Disable;   
  	FSMC_NORSRAMInitStructure.FSMC_WaitSignalActive = FSMC_WaitSignalActive_BeforeWaitState;  
  	FSMC_NORSRAMInitStructure.FSMC_WriteOperation = FSMC_WriteOperation_Enable;//存储器写使能 
  	FSMC_NORSRAMInitStructure.FSMC_WaitSignal = FSMC_WaitSignal_Disable;  
  	FSMC_NORSRAMInitStructure.FSMC_ExtendedMode = FSMC_ExtendedMode_Disable;//读写使用相同的时序
  	FSMC_NORSRAMInitStructure.FSMC_WriteBurst = FSMC_WriteBurst_Disable;  
  	FSMC_NORSRAMInitStructure.FSMC_ReadWriteTimingStruct = &readWriteTiming;
  	FSMC_NORSRAMInitStructure.FSMC_WriteTimingStruct = &readWriteTiming;//读写同样时序

  	FSMC_NORSRAMInit(&FSMC_NORSRAMInitStructure);//初始化FSMC配置

 	FSMC_NORSRAMCmd(FSMC_Bank1_NORSRAM3, ENABLE);//使能BANK3
}
	  														  
//在指定地址(WriteAddr+Bank1_SRAM3_ADDR)开始,连续写入n个字节.
//pBuffer:字节指针
//WriteAddr:要写入的地址
//n:要写入的字节数
void FSMC_SRAM_write_buffer(u8* pBuffer,u32 WriteAddr,u32 n)
{
	for(;n!=0;n--)  
	{										    
		*(vu8*)(Bank1_SRAM3_ADDR+WriteAddr)=*pBuffer;
		WriteAddr++;
		pBuffer++;
	}   
}																			    
//在指定地址((WriteAddr+Bank1_SRAM3_ADDR))开始,连续读出n个字节.
//pBuffer:字节指针
//ReadAddr:要读出的起始地址
//n:要读出的字节数
void FSMC_SRAM_read_buffer(u8* pBuffer,u32 ReadAddr,u32 n)
{
	for(;n!=0;n--)
	{
		*pBuffer++=*(vu8*)(Bank1_SRAM3_ADDR+ReadAddr);
		ReadAddr++;
	}
} 

//测试函数
//在指定地址写入1个字节
//addr:地址
//data:要写入的数据
void FSMC_SRAM_test_write(u32 addr,u8 data)
{			   
	FSMC_SRAM_WriteBuffer(&data,addr,1);//写入1个字节
}
//读取1个字节
//addr:要读取的地址
//返回值:读取到的数据
u8 FSMC_SRAM_test_read(u32 addr)
{
	u8 data;
	FSMC_SRAM_ReadBuffer(&data,addr,1);
	return data;
}
```

malloc.h

```c
#ifndef __MALLOC_H
	#define __MALLOC_H
	#include "stm32f4xx.h"
 
	#ifndef NULL
		#define NULL 0
	#endif

	//定义三个内存池
	#define SRAM_IN 0 //内部内存池
	#define SRAM_EX 1 //外部内存池
	#define SRAM_CCM 2 //CCM内存池	此部分SRAM仅CPU可以访问
	//定义支持的SRAM块数
	#define SRAM_BANK 3

	//mem1内存参数设定	mem1处于内部SRAM
	#define MEM1_BLOCK_SIZE			32  	  						//内存块大小为32字节
	#define MEM1_MAX_SIZE			100*1024  						//最大管理内存100K
	#define MEM1_ALLOC_TABLE_SIZE	MEM1_MAX_SIZE/MEM1_BLOCK_SIZE 	//内存表大小

	//mem2内存参数设定	mem2处于外部SRAM
	#define MEM2_BLOCK_SIZE			32  	  						//内存块大小为32字节
	#define MEM2_MAX_SIZE			960*1024  						//最大管理内存960K
	#define MEM2_ALLOC_TABLE_SIZE	MEM2_MAX_SIZE/MEM2_BLOCK_SIZE 	//内存表大小

	//mem3内存参数设定	mem3处于CCM(这部分SRAM仅CPU可以访问)
	#define MEM3_BLOCK_SIZE			32  	  						//内存块大小为32字节
	#define MEM3_MAX_SIZE			60*1024  						//最大管理内存60K
	#define MEM3_ALLOC_TABLE_SIZE	MEM3_MAX_SIZE/MEM3_BLOCK_SIZE 	//内存表大小

	//内存管理控制器结构体，用c面向对象的方式构建
	typedef struct
	{
		u8* membase[SRAM_BANK];//内存池	管理SRAMBANK个区域的内存
		u16* memmap[SRAM_BANK];//内存管理状态表，最大可分配 65535*内存块 的内存区域，在这里一次性最大可申请2MB
		u8  memrdy[SRAM_BANK];//内存管理是否就绪，1表示就绪；0表示未就绪
        
        void (*init)(u8);//初始化方法，指向内存初始化函数，用于初始化函数管理
		u8 (*perused)(u8);//内存使用率方法，指向内存使用率函数，用于初始化函数管理
	}_m_Malloc_Dev;
	extern _m_Malloc_Dev malloc_dev;	 //在mallco.c里初始化

	void my_mem_set(void *s,u8 c,u32 count);//设置内存
	void my_mem_cpy(void *des,void *src,u32 n);//复制内存
	u32 my_mem_malloc(u8 memx,u32 size);//内存分配(内部调用)
	u8 my_mem_free(u8 memx,u32 offset);//内存释放(内部调用)
	void public_mem_init(u8 memx);//内存管理初始化函数(外/内部调用)
	u8 public_mem_perused(u8 memx);//获得内存使用率(外/内部调用)
	
	/*************用户调用函数************/
	void public_free(u8 memx,void *ptr);//内存释放(外部调用)
	void* public_malloc(u8 memx,u32 size);//内存分配(外部调用)
	void* public_realloc(u8 memx,void *ptr,u32 size);//重新分配内存(外部调用)
	/*************用户调用函数************/
#endif
```

malloc.c

```c
#include "malloc.h"	   

//内存池(32字节对齐)
__align(32) u8 mem1base[MEM1_MAX_SIZE];												//内部SRAM内存池
__align(32) u8 mem2base[MEM2_MAX_SIZE] __attribute__((at(0X68000000)));				//外部SRAM内存池
__align(32) u8 mem3base[MEM3_MAX_SIZE] __attribute__((at(0X10000000)));				//内部CCM内存池
//内存管理表
u16 mem1mapbase[MEM1_ALLOC_TABLE_SIZE];//内部SRAM内存池MAP
u16 mem2mapbase[MEM2_ALLOC_TABLE_SIZE] __attribute__((at(0X68000000+MEM2_MAX_SIZE)));//外部SRAM内存池MAP
u16 mem3mapbase[MEM3_ALLOC_TABLE_SIZE] __attribute__((at(0X10000000+MEM3_MAX_SIZE)));//内部CCM内存池MAP

//内存表大小
const u32 memtblsize[SRAM_BANK]={MEM1_ALLOC_TABLE_SIZE,MEM2_ALLOC_TABLE_SIZE,MEM3_ALLOC_TABLE_SIZE};
//内存分块大小
const u32 memblksize[SRAM_BANK]={MEM1_BLOCK_SIZE,MEM2_BLOCK_SIZE,MEM3_BLOCK_SIZE};
//内存总大小
const u32 memsize[SRAM_BANK]={MEM1_MAX_SIZE,MEM2_MAX_SIZE,MEM3_MAX_SIZE};

/****************内存管理控制器结构体初始化****************/
_m_Malloc_Dev malloc_dev=
{
	public_mem_init,//内存初始化
	public_mem_perused,//内存使用率
	mem1base,mem2base,mem3base,//内存池
	mem1mapbase,mem2mapbase,mem3mapbase,//内存管理状态表
	0,0,0,//内存管理未就绪
};
/****************内存管理控制器结构体初始化****************/

//复制内存
//des:目的地址
//src:源地址
//n:需要复制的内存长度(单位为字节)
void my_mem_cpy(void* des,void* src,u32 n)  
{  
    u8* xdes=des;
	u8* xsrc=src;
    while(n--)//逐项复制
        *xdes ++ = *xsrc ++;  
}
//设置内存
//s:内存首地址
//c:要设置的值
//count:需要设置的内存长度(单位为字节)
void my_mem_set(void* s,u8 c,u32 n)  
{  
    u8* xs = s;  
    while(n--)
        *xs ++ = c;  
}

//内存管理初始化
//memx:所属内存块
void public_mem_init(u8 memx)  
{  
    my_mem_set(malloc_dev.memmap[memx],0,memtblsize[memx]*2);//内存状态表数据清零
	my_mem_set(malloc_dev.membase[memx],0,memsize[memx]);//内存池所有数据清零
	malloc_dev.memrdy[memx]=1;//内存管理完成初始化
}

//获取内存使用率
//memx:所属内存块
//返回值:使用率(0~100)
u8 public_mem_perused(u8 memx)  
{
    u32 used=0;
    u32 i;
    for(i=0;i<memtblsize[memx];i++)  
    {
        if(malloc_dev.memmap[memx][i])
            used++;
    }
    
    return (used*100)/(memtblsize[memx]);  
}  
//内存分配(内部调用)
//memx:所属内存块
//size:要分配的内存大小(字节)
//返回值:0XFFFFFFFF,代表错误;其他,内存偏移地址 
u32 my_mem_malloc(u8 memx,u32 size)  
{  
    signed long offset=0;//偏移量
    u32 nmemb;//需要的内存块数  
	u32 cmemb=0;//连续空内存块数计数器
    u32 i;
    
    if(!malloc_dev.memrdy[memx])//未初始化,先执行初始化 
        malloc_dev.init(memx);
    
    if(size==0)
        return 0XFFFFFFFF;//不需要分配
    
    nmemb=size/memblksize[memx];//获取需要分配的连续内存块数
    if(size%memblksize[memx])
        nmemb++;
    
    for(offset=memtblsize[memx]-1;offset>=0;offset--)//搜索整个内存控制区  
    {
		if(!malloc_dev.memmap[memx][offset])//如果当前内存块为空
            cmemb++;//连续空内存块数增加
		else
            cmemb=0;//只要碰到连续内存块就让计数器清零
        
		if(cmemb==nmemb)//如果找到了连续nmemb个空内存块
		{
            for(i=0;i<nmemb;i++)//之前找到的内存块标注非空 
            {
                malloc_dev.memmap[memx][offset+i]=nmemb;
            }  
            return (offset*memblksize[memx]);//返回偏移地址
		}
    }
    
    return 0XFFFFFFFF;//未找到符合分配条件的内存块  
}
//释放内存(内部调用) 
//memx:所属内存块
//offset:内存地址偏移
//返回值:0,释放成功;1,释放失败
u8 my_mem_free(u8 memx,u32 offset)
{
    int i;
    
    if(!malloc_dev.memrdy[memx])//未初始化则先执行初始化
	{
		malloc_dev.init(memx);
        return 1;//未初始化
    }
    
    if(offset<memsize[memx])//如果偏移在内存池内
    {
        int index=offset/memblksize[memx];//计算偏移所在内存块号码
        int nmemb=malloc_dev.memmap[memx][index];//计算内存块数量
        
        for(i=0;i<nmemb;i++)//将待释放内存块清零
        {
            malloc_dev.memmap[memx][index+i]=0;
        }
        
        return 0;
    }
    else
        return 2;//偏移超区报错
}

/********************用户函数********************/
//释放内存(外部调用)
//memx:所属内存块
//ptr:内存首地址
void public_free(u8 memx,void* ptr)
{
	u32 offset;
    
	if(ptr==NULL)//地址为0
        return;
 	offset=(u32)ptr-(u32)malloc_dev.membase[memx];
    my_mem_free(memx,offset);//释放内存
}
//分配内存(外部调用)
//memx:所属内存块
//size:内存大小(字节)
//返回值:分配到的内存首地址
void* public_malloc(u8 memx,u32 size)  
{
    u32 offset;
    
	offset=my_mem_malloc(memx,size);
    
    if(offset==0XFFFFFFFF)//如果内存已满
        return NULL;//返回空指针
    else
        return (void*)((u32)malloc_dev.membase[memx]+offset);//返回分配的到的地址
}
//重新分配内存(外部调用)
//memx:所属内存块
//ptr:旧内存首地址
//size:要分配的内存大小(字节)
//返回值:新分配到的内存首地址.
void* public_realloc(u8 memx,void* ptr,u32 size)  
{  
    u32 offset;
    offset=my_mem_malloc(memx,size);
    
    if(offset==0XFFFFFFFF)//如果内存已满
        return NULL;//返回空指针
    else
    {
	    my_mem_cpy((void*)((u32)malloc_dev.membase[memx]+offset),ptr,size);//拷贝旧内存内容到新内存   
        public_free(memx,ptr);//释放旧内存
        return (void*)((u32)malloc_dev.membase[memx]+offset);//返回新内存首地址
    }
}
/********************用户函数********************/
```









