# IAP(In Application Programming)应用内编程

## mcu编程方式

1. ICP（in circuit programming）

使用JTAG/SWD协议或bootloader下载用户应用程序到mcu

2. IAP（in application programming）

通过任意一种通信接口（IO口、USB、CAN、USART、I2C、SPI等）下载册灰姑娘徐或者应用数据到flash

stm32允许用户在应用程序中重新烧写flash中的内容

**局限性：IAP至少需要有一部分程序已经使用ICP方式烧录到闪存存储器中，即需要有bootloader**

**作用：在不需要操作硬件平台的情况下实现==远程升级==**

## stm32系统存储器

所有stm32都带有**系统存储器**区域，ST在mcu出厂前已经将bootloader固化在mcu内部的系统存储器区域

系统存储器可以使用串口1（USART1）接收应用程序

stm32f4xx中系统存储器大小为30k，位于主存储区和OTP区域之间

==将BOOT1=0，BOOT0=1==即可从系统存储器区域加载

### ICP/ISP下载流程

1. 通过串口1传输程序数据
2. 在ICP下，bootloader将其下载到0x8000000到0x0807FFFF之间的主存储器区域（在ISP下载中依靠JTAG/SWD协议直接写入）

### IAP下载流程

1. ICP方式烧录bootloader区域代码
2. 将应用程序转换为二进制编码
3. 通过各种通信接口发送二进制文件到bootloader
4. bootloader接收程序并将其烧录在IAP应用程序存储区（主存储器）
5. bootloader跳转到程序区进行执行

### 一般程序执行过程（从startup.s启动）

1. 从0x08000000执行程序，同时从栈顶开始读取地址执行程序
2. 开栈、开堆、设置内存（共用4字节）
3. 开辟复位中断向量（中断向量表起始地址）——对应Reset_Handler地址
4. 跳转到复位中断程序入口Reset_Handler(void)，执行相关程序
5. 相关程序包含systemInit和main函数入口SystemInit、__main，进入int main(void)
6. 执行主程序内容（主循环）
7. 当发生中断事件时，先进行现场保护，再到中断向量表中查找对应中断向量xxx_Handler——对应XXX_IRQHandler(void)函数地址
8. 执行中断服务函数内容
9. 执行完毕后，先恢复现场，再加载入主函数

### 加入IAP后程序执行过程

1-5同上

6. 到主函数后，进行IAP过程
7. IAP程序完毕后，跳回新的复位中断向量地址（0x08000004+n+m，n为相对IAP程序main函数入口偏移地址，m为相对bootloader复位中断向量偏移地址）
8. 在新程序中重复上述一般程序执行步骤
9. 中断执行时，跳转到原来的中断向量表，不依据新的中断向量表进行跳转
10. 执行完毕后，恢复现场并加载入新程序主函数

### IAP升级应用程序过程

1. 检查是否需要对实际应用程序代码进行更新
2. 如果不需要，则跳转到实际应用部分代码执行
3. 如果需要，则执行更新操作后再跳转到实际应用部分代码执行

**将第一部分的原始代码称为bootloader程序，第二部分代码称为APP，一般从最低地址存放bootloader，APP紧跟其后**

**stm32的APP不仅可以放到flash里执行，也可以放入SRAM里执行，两者原理一致**



startup.s

```assembly
Stack_Size      EQU     0x00000400
                AREA    STACK, NOINIT, READWRITE, ALIGN=3
Stack_Mem       SPACE   Stack_Size
__initial_sp
; <h> Heap Configuration
;   <o>  Heap Size (in Bytes) <0x0-0xFFFFFFFF:8>
; </h>
Heap_Size       EQU     0x00000200
                AREA    HEAP, NOINIT, READWRITE, ALIGN=3
__heap_base
Heap_Mem        SPACE   Heap_Size
__heap_limit
                PRESERVE8
                THUMB
;中断向量表
; Vector Table Mapped to Address 0 at Reset
                AREA    RESET, DATA, READONLY
                EXPORT  __Vectors
                EXPORT  __Vectors_End
                EXPORT  __Vectors_Size
__Vectors       DCD     __initial_sp               ; Top of Stack
                DCD     Reset_Handler              ; Reset Handler复位中断向量
                DCD     NMI_Handler                ; NMI Handler非可屏蔽中断向量
                DCD     HardFault_Handler          ; Hard Fault Handler
                DCD     MemManage_Handler          ; MPU Fault Handler
                DCD     BusFault_Handler           ; Bus Fault Handler
                DCD     UsageFault_Handler         ; Usage Fault Handler
                DCD     0                          ; Reserved
                DCD     0                          ; Reserved
                DCD     0                          ; Reserved
                DCD     0                          ; Reserved
                DCD     SVC_Handler                ; SVCall Handler
                DCD     DebugMon_Handler           ; Debug Monitor Handler
                DCD     0                          ; Reserved
                DCD     PendSV_Handler             ; PendSV Handler
                DCD     SysTick_Handler            ; SysTick Handler
                ; External Interrupts
                DCD     WWDG_IRQHandler                   ; Window WatchDog                       
                DCD     PVD_IRQHandler                    ; PVD through EXTI Line detection
                DCD     TAMP_STAMP_IRQHandler             ; Tamper and TimeStamps through the EXTI line
                DCD     RTC_WKUP_IRQHandler               ; RTC Wakeup through the EXTI line
                DCD     FLASH_IRQHandler                  ; FLASH
                DCD     RCC_IRQHandler                    ; RCC
                DCD     EXTI0_IRQHandler                  ; EXTI Line0
                DCD     EXTI1_IRQHandler                  ; EXTI Line1
                DCD     EXTI2_IRQHandler                  ; EXTI Line2
                DCD     EXTI3_IRQHandler                  ; EXTI Line3
                DCD     EXTI4_IRQHandler                  ; EXTI Line4
                DCD     DMA1_Stream0_IRQHandler           ; DMA1 Stream 0
                DCD     DMA1_Stream1_IRQHandler           ; DMA1 Stream 1
                DCD     DMA1_Stream2_IRQHandler           ; DMA1 Stream 2
                DCD     DMA1_Stream3_IRQHandler           ; DMA1 Stream 3
                DCD     DMA1_Stream4_IRQHandler           ; DMA1 Stream 4
                DCD     DMA1_Stream5_IRQHandler           ; DMA1 Stream 5
                DCD     DMA1_Stream6_IRQHandler           ; DMA1 Stream 6
                DCD     ADC_IRQHandler                    ; ADC1, ADC2 and ADC3s
                DCD     CAN1_TX_IRQHandler                ; CAN1 TX
                DCD     CAN1_RX0_IRQHandler               ; CAN1 RX0
                DCD     CAN1_RX1_IRQHandler               ; CAN1 RX1
                DCD     CAN1_SCE_IRQHandler               ; CAN1 SCE
                DCD     EXTI9_5_IRQHandler                ; External Line[9:5]s
                DCD     TIM1_BRK_TIM9_IRQHandler          ; TIM1 Break and TIM9                   
                DCD     TIM1_UP_TIM10_IRQHandler          ; TIM1 Update and TIM10                 
                DCD     TIM1_TRG_COM_TIM11_IRQHandler     ; TIM1 Trigger and Commutation and TIM11
                DCD     TIM1_CC_IRQHandler                ; TIM1 Capture Compare
                DCD     TIM2_IRQHandler                   ; TIM2
                DCD     TIM3_IRQHandler                   ; TIM3
                DCD     TIM4_IRQHandler                   ; TIM4
                DCD     I2C1_EV_IRQHandler                ; I2C1 Event
                DCD     I2C1_ER_IRQHandler                ; I2C1 Error
                DCD     I2C2_EV_IRQHandler                ; I2C2 Event
                DCD     I2C2_ER_IRQHandler                ; I2C2 Error
                DCD     SPI1_IRQHandler                   ; SPI1
                DCD     SPI2_IRQHandler                   ; SPI2
                DCD     USART1_IRQHandler                 ; USART1
                DCD     USART2_IRQHandler                 ; USART2
                DCD     USART3_IRQHandler                 ; USART3
                DCD     EXTI15_10_IRQHandler              ; External Line[15:10]s
                DCD     RTC_Alarm_IRQHandler              ; RTC Alarm (A and B) through EXTI Line
                DCD     OTG_FS_WKUP_IRQHandler            ; USB OTG FS Wakeup through EXTI line
                DCD     TIM8_BRK_TIM12_IRQHandler         ; TIM8 Break and TIM12                  
                DCD     TIM8_UP_TIM13_IRQHandler          ; TIM8 Update and TIM13                 
                DCD     TIM8_TRG_COM_TIM14_IRQHandler     ; TIM8 Trigger and Commutation and TIM14
                DCD     TIM8_CC_IRQHandler                ; TIM8 Capture Compare
                DCD     DMA1_Stream7_IRQHandler           ; DMA1 Stream7
                DCD     FSMC_IRQHandler                   ; FSMC
                DCD     SDIO_IRQHandler                   ; SDIO
                DCD     TIM5_IRQHandler                   ; TIM5
                DCD     SPI3_IRQHandler                   ; SPI3
                DCD     UART4_IRQHandler                  ; UART4
                DCD     UART5_IRQHandler                  ; UART5
                DCD     TIM6_DAC_IRQHandler               ; TIM6 and DAC1&2 underrun errors
                DCD     TIM7_IRQHandler                   ; TIM7                   
                DCD     DMA2_Stream0_IRQHandler           ; DMA2 Stream 0
                DCD     DMA2_Stream1_IRQHandler           ; DMA2 Stream 1
                DCD     DMA2_Stream2_IRQHandler           ; DMA2 Stream 2
                DCD     DMA2_Stream3_IRQHandler           ; DMA2 Stream 3
                DCD     DMA2_Stream4_IRQHandler           ; DMA2 Stream 4
                DCD     ETH_IRQHandler                    ; Ethernet
                DCD     ETH_WKUP_IRQHandler               ; Ethernet Wakeup through EXTI line
                DCD     CAN2_TX_IRQHandler                ; CAN2 TX
                DCD     CAN2_RX0_IRQHandler               ; CAN2 RX0
                DCD     CAN2_RX1_IRQHandler               ; CAN2 RX1
                DCD     CAN2_SCE_IRQHandler               ; CAN2 SCE
                DCD     OTG_FS_IRQHandler                 ; USB OTG FS
                DCD     DMA2_Stream5_IRQHandler           ; DMA2 Stream 5
                DCD     DMA2_Stream6_IRQHandler           ; DMA2 Stream 6
                DCD     DMA2_Stream7_IRQHandler           ; DMA2 Stream 7
                DCD     USART6_IRQHandler                 ; USART6
                DCD     I2C3_EV_IRQHandler                ; I2C3 event
                DCD     I2C3_ER_IRQHandler                ; I2C3 error
                DCD     OTG_HS_EP1_OUT_IRQHandler         ; USB OTG HS End Point 1 Out
                DCD     OTG_HS_EP1_IN_IRQHandler          ; USB OTG HS End Point 1 In
                DCD     OTG_HS_WKUP_IRQHandler            ; USB OTG HS Wakeup through EXTI
                DCD     OTG_HS_IRQHandler                 ; USB OTG HS
                DCD     DCMI_IRQHandler                   ; DCMI
                DCD     CRYP_IRQHandler                   ; CRYP crypto
                DCD     HASH_RNG_IRQHandler               ; Hash and Rng
                DCD     FPU_IRQHandler                    ; FPU
__Vectors_End

__Vectors_Size  EQU  __Vectors_End - __Vectors
                AREA    |.text|, CODE, READONLY
; Reset handler
Reset_Handler    PROC
                 EXPORT  Reset_Handler             [WEAK]
        IMPORT  SystemInit
        IMPORT  __main
                 LDR     R0, =SystemInit
                 BLX     R0
                 LDR     R0, =__main
                 BX      R0
                 ENDP
; Dummy Exception Handlers (infinite loops which can be modified)
NMI_Handler     PROC
                EXPORT  NMI_Handler                [WEAK]
                B       .
                ENDP
HardFault_Handler\
                PROC
                EXPORT  HardFault_Handler          [WEAK]
                B       .
                ENDP
MemManage_Handler\
                PROC
                EXPORT  MemManage_Handler          [WEAK]
                B       .
                ENDP
BusFault_Handler\
                PROC
                EXPORT  BusFault_Handler           [WEAK]
                B       .
                ENDP
UsageFault_Handler\
                PROC
                EXPORT  UsageFault_Handler         [WEAK]
                B       .
                ENDP
SVC_Handler     PROC
                EXPORT  SVC_Handler                [WEAK]
                B       .
                ENDP
DebugMon_Handler\
                PROC
                EXPORT  DebugMon_Handler           [WEAK]
                B       .
                ENDP
PendSV_Handler  PROC
                EXPORT  PendSV_Handler             [WEAK]
                B       .
                ENDP
SysTick_Handler PROC
                EXPORT  SysTick_Handler            [WEAK]
                B.
                ENDP

Default_Handler PROC
                EXPORT  WWDG_IRQHandler                   [WEAK]
;后面都是类似的 EXPORT xxx_IRQHandler [WEAK] 中断函数名声明
;此处省略中断向量名
                B.
                ENDP
                ALIGN
;*******************************************************************************
; User Stack and Heap initialization
;*******************************************************************************
                 IF      :DEF:__MICROLIB
                 EXPORT  __initial_sp
                 EXPORT  __heap_base
                 EXPORT  __heap_limit
                 ELSE
                 IMPORT  __use_two_region_memory
                 EXPORT  __user_initial_stackheap
__user_initial_stackheap
                 LDR     R0, =  Heap_Mem
                 LDR     R1, =(Stack_Mem + Stack_Size)
                 LDR     R2, = (Heap_Mem +  Heap_Size)
                 LDR     R3, = Stack_Mem
                 BX      LR
                 ALIGN
                 ENDIF
                 END
```

## IAP的实现

IAP程序的要求：1.APP必须在bootloader之后某个偏移量为x的地址开始；2.必须将新程序的中断向量表相应移动，移动的偏移量为x

### APP程序的生成步骤

1. 设置APP的起始地址和储存空间大小
2. 设置中断向量表偏移量（通过SCB->VTOR寄存器进行设置）

在APP的main()函数内写入

```c
SCB->VTOR=FLASH_BASE|0x10000;
```

来设置偏移地址

3. 设置MDK编译后运行fromelf.exe，生成对应二进制文件（通过设置MDK User选项卡为“编译后调用fromelf.exe，根据axf文件生成bin文件，用于IAP更新”）

设置以下指令

```c
${workspace}/bin/fromelf.exe --bin -o ../OBJ/${APP}.bin ../OBJ/${APP}.axf
```

到User选项卡中"After Build/Rebuild"一项

编译后显示"After Build -User command xxxxxx"且无报错可判断为生成成功bin文件

4. 下载并写入APP程序

### IAP-Bootloader的具体代码实现

1. 选择通信接口
2. 选择写入地址
3. 设置跳转

注意**编写代码前引入stm32f4xx_flash.c源文件、stmflash.c文件和对应头文件**

usart.c

```c
//仅列出改动内容
#define USART_REC_LEN 120*1024 //120k缓存

//注意这里设置为全局变量
u8 USART_RX_BUF[USART_REC_LEN] __attribute__ (at(0x20001000));//将数据存放在SRAM起始地址为0x20001000的位置

void USART1_IRQHandler(void)
{
    u8 res;
    
    if(USART_GetITStatus(USART1,USART_IT_RXNE)!=RESET)//接收中断
    {
    	res=USART_ReceiveData(USART1);//读取接收到的数据    
        if(USART_RX_CNT<USART_REC_LEN)//若收取到数据大小小于缓存区大小
        {
            USART_RX_BUF[USART_RX_CNT]=res;//将数据保存在缓存
            USART_RX_CNT++;
        }
    }
}
```

加入IAP文件夹与iap.c、iap.h文件

iap.h

```c
#ifndef __IAP_H
	#define __IAP_H
	#include "sys.h"
	typedef void (*iapfun)(void);//定义一个函数类型的参数
		
	#define FLASH_APP1_ADDR 0x0801000 //第一个应用程序起始地址（存放在FLASH）
	//保留0x08000000-0x0800FFFF的64k空间给bootloader
	
	void IAP_load_app(u32 appxaddr);//跳转到APP执行
	void IAP_write_appbin(u32 appxaddr,u8* appbuf,u32 applen);//在指定地址开始处写入APP二进制文件	
#endif
```

iap.c

```c
#include "iap.h"
#include "stmflash.h"

IAPfun jmp2app;
u32 IAPbuf[512];//2k字节缓存

//写入APP到FLASH
//appxaddr APP起始地址
//appbuf APP代码缓存
//applen APP大小
void IAP_write_appbin(u32 appxaddr,u8* appbuf,u32 applen)
{
	u32 t;
	u32 temp;
	u32 fwaddr=appxaddr;
	u16 i=0;
	u8* dfu=appbuf;

	for(t=0;t<applen;t+=4)
	{
		temp=(u32)dfu[3]<<24;
		temp|=(u32)dfu[2]<<16;
		temp|=(u32)dfu[1]<<8;
		temp|=(u32)dfu[0];//每8个字节封装成32位(8个字节)
		
		dfu+=4;//偏移4个字节
		IAPbuf[i++]=temp;//将封装后的数据传给写入缓存
		
		if(i==512)//每满足512个字节写入一次
		{
			i=0;
			STMFLASH_write(fwaddr,IAPbuf,512);
			fwaddr+=2048;//fwaddr偏移512*4=2048位数据，进行下一轮操作直到将接收数据全部写入
		}
	}
	if(i)//如果最后有剩余
		STMFLASH_write(fwaddr,IAPbuf,i);//将剩余的内容字节写入FLASH
}

//跳转到APP段
//appxaddr APP代码起始地址
void IAP_load_app(u32 appxaddr)
{
	if(((*(vu32*)appxaddr)&0x2FFE0000)==0x20000000)//检查栈顶地址是否合法
	{
		jmp2app=(IAPfun)*(vu32*)(appxaddr+4);//用户代码区第二个字为程序开始地址(复位地址)
		
		/*这里使用了汇编程序MSR_MSP设置堆栈*/
		MSR_MSP(*(vu32*)appxaddr);//初始化APP堆栈指针
		jmp2app();//跳转到APP段
	}
}
```

### 使用方法

1. 烧录bootloader至stm32
2. 打开串口
3. 使用串口助手将文件发送王mcu
4. 等待固件更新
5. 开始程序