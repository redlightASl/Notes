# ADC原理

ADC电源要求：**全速**运行时2.4-3.6V	**慢速**运行时1.8V	电压输入范围$$V_{REF-}\le V_{IN}\le V_{REF+}$$

规则通道转换期间可产生DMA请求

 stm32f40x系列大容量芯片带有3个ADC控制器（3路ADC），都是其中144脚IC因为带PF脚所以多8个通道，共24个外部通道，小于144脚的IC只有16个外部通道

所有ADC均为12位逐次逼近型模拟数字转换器

各通道可以单次（执行一次转换）、连续（ADC结束一个转换后立即启动一个新的转换，多同时DMA）、扫描（扫描所有规则通道和注入通道分别对应的寄存器，为组内每个通道都执行一次转换，转换结束后，会自动转换该组中的下一个通道；若使能了DMA控制寄存器，则会在每次规则通道转换之后均使用DMA控制器将转换自规则通道组的数据传输到SRAM）、中断、间断模式执行

stm32f4的ADC最大转换速率为2.4MHz，即转换时间为1μs（条件：ADCCLK=36MHz，采样周期为3），==ADC时钟应小于等于36MHz==，否则可能不准

### 规则通道

相当于正常运行的程序，最多16个

数据保存在规则通道寄存器

### 注入通道

相当于中断，最多4个

注入通道的转换可以打断规则通道的转换，在注入通道转换完成后，规则通道才能继续转换

数据保存在注入通道寄存器

# ADC配置

注意配置之前需要将**stm32f4xx_adc.c**添加到FWLIB中

adc.c

```c
#include "adc.h"
#include "delay.h"
#include "sys.h"

void ADC_init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	ADC_CommonInitTypeDef ADC_CommonInitStruct;
	ADC_InitTypeDef ADC_InitStruct;
	
	//1. 使能GPIO与ADC1时钟
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOE,ENABLE);
  	RCC_APB2PeriphClockCmd(RCC_APB2Periph_ADC1,ENABLE);
		
	//2. 复用PE0为ADC1
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_0;//PE0
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AN;//模拟输入模式
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_NOPULL;//引脚悬空
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//速度100MHz
	//应用设置
	GPIO_Init(GPIOE,&GPIO_InitStructure);
	
	//3. 复位ADC
	//这里包括了RCC_APB2PeriphResetCmd(RCC_APB2Periph_ADC1,ENABLE)和RCC_APB2PeriphResetCmd(RCC_APB2Periph_ADC1,ENABLE)两个函数
	ADC_DeInit();
	
		
	//4. ADC时钟分频与通用设置
	ADC_CommonInitStruct.ADC_DMAAccessMode=ADC_DMAAccessMode_Disabled;//不使用DMA
	ADC_CommonInitStruct.ADC_Mode=ADC_Mode_Independent;//独立模式
	ADC_CommonInitStruct.ADC_Prescaler=ADC_Prescaler_Div4;//ADC时钟最好小于32MHz，这里采用84/4=21MHz
	ADC_CommonInitStruct.ADC_TwoSamplingDelay=ADC_TwoSamplingDelay_5Cycles;//两个采样阶段之间延迟5个时钟
	//应用设置
	ADC_CommonInit(&ADC_CommonInitStruct);
	
	//5. 设置ADC1
	ADC_InitStruct.ADC_Resolution=ADC_Resolution_12b;//12位模式
	ADC_InitStruct.ADC_DataAlign=ADC_DataAlign_Right;//右对齐
	ADC_InitStruct.ADC_NbrOfConversion=1;//1个转换在规则序列中<=>只转换规则序列1
	ADC_InitStruct.ADC_ExternalTrigConvEdge=ADC_ExternalTrigConvEdge_None;//不使用触发检测，使用软件触发
	ADC_InitStruct.ADC_ScanConvMode=DISABLE;//非扫描（扫描转换）模式
	ADC_InitStruct.ADC_ContinuousConvMode=DISABLE;//关闭连续转换
	//应用设置
	ADC_Init(ADC1,&ADC_InitStruct);
	
	//开启ADC
	ADC_Cmd(ADC1,ENABLE);
}

//获取单次ADC值
//ch表示通道值0~16	即	@ref ADC_channels 
//返回单次转换结果
u16 ADC_get_value(u8 ch)
{
	//6. 设置ADC规则通道：(ADC通道,通道值,转换序列,采样时间)
	ADC_RegularChannelConfig(ADC1,ch,1,ADC_SampleTime_480Cycles);
	
	//7. 启用ADC1的软件转换
	ADC_SoftwareStartConv(ADC1);
	
	//8. 等待转换结束后返回结果
	while(!ADC_GetFlagStatus(ADC1,ADC_FLAG_EOC));
	return ADC_GetConversionValue(ADC1);//返回最近一次ADC1规则组的转换结果
}


//获取平均ADC值
//ch表示通道值0~16	即	@ref ADC_channels 
//ADC_times表示采样次数
//返回多次转换平均结果
u16 ADC_get_average(u8 ch,u8 ADC_times)
{
	u32 ADC_temp_value=0;
	u8 ADC_t;
	
    //9. 多次平均后取其结果
	for(ADC_t=0;ADC_t<ADC_times;ADC_t++)
	{
		ADC_temp_value+=ADC_get_value(ch);
		delay_ms(2);
	}
	return ADC_temp_value/ADC_times;
}
```

adc.h

```c
#ifndef __ADC_H
	#define __ADC_H
	#include "sys.h"

	void ADC_init(void);//ADC通道初始化
	u16 ADC_get_value(u8 ch);//获得某个通道值
	u16 ADC_get_average(u8 ch,u8 times);//获取某通道给定次数采样的平均值
	
#endif
```

main.c

```c
#include "delay.h"
#include "adc.h"
#include "lcd.h"
#include "led.h"

int main(void)
{
    u16 ADC_val_x;//读取ADC值
    float temp;//暂存相关值
    
    delay_init(168);
    LED_init();
    ADC_init();
    LCD_init();
    
    while(1)
    {
        //10. 将平均结果保存
        ADC_val_x=ADC_get_average(ADC_Channel_5,20);//获取PE0读取到的ADC平均值，取20次平均
        LCD_ShowxNum(134,130,ADC_val_x,4,16,0);//显示原始值
        
        //11. 获取计算后带小数的实际值
        temp=(float)ADC_val_x*(3.3/4096);
        ADC_val_x=temp;//将temp的整数部分赋给ADC_val_x
        LCD_ShowxNum(134,150,ADC_val_x,1,16,0);//显示整数部分
        
        temp-=ADC_val_x;//获取小数部分
        temp*=1000;//保留三位小数
        LCD_ShowxNum(150,150,temp,3,16,0x80);//显示小数部分
        
        LED0!=LED0;
        delay_ms(200);
    }
}
```

# DAC原理

stm32f4配备了独立2通道8位/12位可选数字输入，电压输出型DAC，可通过引脚引入参考电压$V_{ref}$获得更精确的转换结果

* 支持DMA

* 支持同步更新

* 集成2个输出缓冲器，可用来降低阻抗并在不增加外部运放的情况下直接驱动外部负载。通过DAC_CR寄存器中的相应BOFFx位可使能或禁止各DAC通道输出缓冲器；但使能输出缓冲器后输出无法到0

12位模式下，数据可选左对齐（数据写入DAC_DHR12Rx[15:4]位，存入DHRx[11:0]位）、右对齐（数据写入DAC_DHR12Rx[11:0]位，存入DHRx[11:0]位）

8位模式下，数据只有右对齐（数据写入DAC_DHR8Rx[7:0]位，存入DHRx[11:4]位）

| 名称       | 信号类型           | 作用                                               |
| ---------- | ------------------ | -------------------------------------------------- |
| $V_{ref+}$ | 正模拟参考电压输入 | DAC 高/正参考电压，$1.8V \le V_{ref+} \le V_{DDA}$ |
| $V_{DDA}$  | 模拟电源输入       | 模拟电源                                           |
| $V_{SSA}$  | 模拟电源接地输入   | 模拟电源接地                                       |
| DAC_OUTx​   | 模拟输出信号       | DACx模拟输出                                       |

注意：使能DAC通道x后，相应GPIO引脚（PA4或PA5）将自动连接到DAC_OUTx，为避免寄生电流消耗，应首先讲PA4或PA5配置为模拟输入模式（GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AN）

#### 存在输出延迟

DAC转换时，**未选择硬件触发**，则**经过1个APB时钟周期后**DAC_DORx值加载到DAC_DHRx，**选择硬件触发且触发条件到来**，则将在**3个时钟周期后**进行转移。且DAC_DORx值加载到DAC_DHRx后模拟输出电压将在一段时间$t_{SETTING}$后可用，具体时间取决于电源电压和模拟输出负载

$t_{SETTING}$典型值是3μs，最大值是6μs，导致了DAC存在最大转换速度约为333kHz

#### DAC输出电压计算公式 $$DAC_{output}=V_{ref} * \frac{DAC_{DOR}}{4095}$$

4095=2^12^-1 	(12位寄存器最大数值111111111111~B~==4095~D~)

# DAC配置

注意：使用前要将stm32f4xx_dac.c加入FWLIB

dac.c

```c
#include "dac.h"

void DAC_1_init(void)
{
	GPIO_InitTypeDef GPIO_InitStructure;
	DAC_InitTypeDef DAC_InitStruct;
	
	//1. 开启GPIO和DAC时钟
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA,ENABLE);
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_DAC,ENABLE);

	//2. 设置DAC对应GPIO
	GPIO_InitStructure.GPIO_Pin=GPIO_Pin_4;//PA4
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AN;//模拟输入，在连接到DAC时同时表示模拟输出
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_DOWN;//内部下拉
	//没有GPIO输出，不设置GPIO_OType
	//直连DAC输出，不设置速度
	//应用设置
	GPIO_Init(GPIOA,&GPIO_InitStructure);

	//3. 设置DAC
	DAC_InitStruct.DAC_LFSRUnmask_TriangleAmplitude=DAC_LFSRUnmask_Bit0;//屏蔽、幅值设置
	DAC_InitStruct.DAC_OutputBuffer=DAC_OutputBuffer_Disable;//关闭输出缓存
	DAC_InitStruct.DAC_Trigger=DAC_Trigger_None;//不使用硬件触发
	DAC_InitStruct.DAC_WaveGeneration=DAC_WaveGeneration_None;//不使用波形发生
	//应用设置
	DAC_Init(DAC_Channel_1,&DAC_InitStruct);
	
	//4. 使能DAC通道1
	DAC_Cmd(DAC_Channel_1,ENABLE);
	
	//5. 以12位右对齐数据格式设置DAC值
	DAC_SetChannel1Data(DAC_Align_12b_R,0);//初始输出电压为0
}


//设置DAC1输出电压值
//使用整型较为方便，这里u16 voltage=0~3300，代表0-3.3V
void DAC_1_set_voltage(u16 voltage,float ref)
{
	float V_temp=voltage;//将整型转换为浮点型进行计算
	V_temp/=1000;//获得要输出的正确电压
	V_temp=4096*V_temp/ref;//输出电压占4096的V_temp/ref份
	
	//6. 设置输出电压值
	DAC_SetChannel1Data(DAC_Align_12b_R,V_temp);//以12位右对齐数据格式设置
}
```

dac.h

```c
#ifndef __DAC_H
	#define __DAC_H
	#include "sys.h"
	
	void DAC_1_init(void);//初始化DAC1
	void DAC_1_set_voltage(u16 voltage);//设置输出电压值
	
#endif
```

main.c

```c
#include "sys.h"
#include "delay.h"
#include "led.h"
#include "key.h"
#include "adc.h"
#include "dac.h"

int main(void)
{
    u16 adcx;
	u16 DAC_val=0;
	u8 t=0
	u8 key;
	
	float temp;
	
  	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);//中断优先级分组2
	delay_init(168);
	LED_init();
	LCD_init();
	KEY_init();
	ADC_init();
	DAC_1_init();//DAC初始化
	
	DAC_1_set_voltage(DAC_Align_12b_R,DAC_val);//设置初始值
    
    while(1)
    {
    	t++;
		
		key=KEY_scan(0);
    	if(key==KEY0_PRES)//KEY0按下
		{
			if(DAC_val<4000)
				DAC_val+=200;//每按一次+0.2V
			DAC_1_set_voltage(DAC_Align_12b_R,DAC_val);
		}
		else if(key==2)
		{
			if(DAC_val>200)
				DAC_val-=200;//每按一次-0.2V
			else
				DAC_val=0;
			DAC_1_set_voltage(DAC_Align_12b_R,DAC_val);
		}
        
        //将 ADC读取到的DAC输出电压V_实 与 用公式计算得到的V_计 比较 即可验证DAC功能，代码略
    }
}
```

