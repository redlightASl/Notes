# FPU与DSP

详细内容参考Cortex-M4内核编程手册

## FPU调用

stm32f4xx及更高配置stm32单片机才有fpu支持

stm32f4带有32位单精度硬件FPU，支持浮点指令集，整个FPU单元能被使能和关闭

使用协处理器控制寄存器（SCB->CPACR）中的CP11和CP10启用/关闭FPU

芯片复位后，CP10、CP11四个位默认为0，FPU关闭

==将CP10、CP11同时置位即可开启FPU==

### FPU使用

system_stm32f4xx.c截取

```c
void SystemInit(void)
{
  /* FPU settings ------------------------------------------------------------*///这里是FPU设置
  #if (__FPU_PRESENT == 1) && (__FPU_USED == 1)
    SCB->CPACR |= ((3UL << 10*2)|(3UL << 11*2));  /* set CP10 and CP11 Full Access */
  #endif
  /* Reset the RCC clock configuration to the default reset state ------------*/
  /* Set HSION bit */
  RCC->CR |= (uint32_t)0x00000001;

  /* Reset CFGR register */
  RCC->CFGR = 0x00000000;

  /* Reset HSEON, CSSON and PLLON bits */
  RCC->CR &= (uint32_t)0xFEF6FFFF;

  /* Reset PLLCFGR register */
  RCC->PLLCFGR = 0x24003010;

  /* Reset HSEBYP bit */
  RCC->CR &= (uint32_t)0xFFFBFFFF;

  /* Disable all interrupts */
  RCC->CIR = 0x00000000;

#if defined (DATA_IN_ExtSRAM) || defined (DATA_IN_ExtSDRAM)
  SystemInit_ExtMemCtl(); 
#endif /* DATA_IN_ExtSRAM || DATA_IN_ExtSDRAM */
         
  /* Configure the System clock source, PLL Multiplier and Divider factors, 
     AHB/APBx prescalers and Flash settings ----------------------------------*/
  SetSysClock();

  /* Configure the Vector Table location add offset address ------------------*/
#ifdef VECT_TAB_SRAM
  SCB->VTOR = SRAM_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal SRAM */
#else
  SCB->VTOR = FLASH_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal FLASH */
#endif
}
```

本质方法：设置CPACR寄存器

### 通用开启方法

将**__FPU_PRESENT** 和 **__FPU_USED** **置1**即可开启FPU

1. 直接设置SCB->CPACR寄存器的CP10和CP11为1
2. 在代码中配置：

```c
#define __FPU_USED 1
```

3. 在MDK，Target选项卡中，将Float Point Hardware选项设置为Use Single Precision

## DSP调用

stm32f4xx及更高配置stm32单片机才有DSP支持

stm32f4带有32位单精度硬件DSP，支持DSP指令集，支持单周期乘加指令（MAC）、优化的单指令多数据指令（SIMD）、饱和算数等数字信号处理指令集。M4执行所有DSP指令集都能在单周期完成

整个DSP单元能被使能和关闭

### DSP指令集简述

#### 单周期乘加指令MAC

支持有符号/无符号乘法、有符号/无符号乘加、有符号/无符号长数据（64位）乘加

#### 单周期SIMD指令

可同时有多个数据参与运算

### DSP源码库

存放在STM32F4xx_DSP_StdPeriph_Lib/Libraries/CMSIS/DSP_Lib/Source下

#### BasicMathFunctions

基本数学函数，提供浮点数各种基本运算，包括向量运算

#### CommonTables

提供位反转或相关参数表

#### ComplexMathFunctions

复杂数学功能，包括向量处理、求模运算等

#### ControllerFunctions

控制功能函数，包括正余弦、PID电机控制、矢量Clarke变换、矢量Clarke逆变换等

#### FastMathFunctions 

快速数学功能函数，提供快速近似正余弦、平方根等算法

#### FilteringFunctions

滤波函数功能，主要为FIR、LMS（最小均方根）等滤波函数

#### MatrixFunctions

矩阵处理函数，包括、矩阵初始化、矩阵转置、矩阵反、矩阵加法、矩阵乘法、矩阵规模、矩阵减法等函数

#### StatisticsFunctions

统计功能函数，包括求平均值、最值、计算均方根RMS、计算方差/标准差等

#### SupportFunctions

支持功能函数，如数据拷贝、Q格式和浮点格式转换、Q任意格式相互转换

#### TransformFunctions

变换功能，包括复数FFT（CFFT）/复数FFT逆运算（CIFFT）、实数FFT（RFFT）/实数FFT逆运算（RIFFT）、DCT（离散余弦变换）和配套初始化函数

DSP源码库较大，ST提供了.lib格式的文件，**在代码中引入lib文件即可**

### DSP环境搭建

1. 添加文件

拷贝STM32F4xx_DSP_StdPeriph_Lib_V1.4.0/Libraries/CMSIS/Include到DSP_LIB

2. 包含DSP_LIB文件与路径
3. 添加全局宏定义

```c
#define __FPU_USED 1 //在MDK中开启即可不填
#define __FPU_PRESENT 1 //在stm32f4xx.h中默认开启，可不填
//将下面四个部分用逗号隔开添加到MDK的define选项中
ARM_MATH_CM4 
__CC_ARM
ARM_MATH_MATRIX_CHECK
ARM_MATH_ROUNDING
```

4. 需要哪些函数就将对应lib和配置添加到MDK







