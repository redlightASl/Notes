# 硬件随机数发生器（RNG）

stm32f4片上自带RNG，以连续模拟噪声为基数，在**主机读数时**提供一个**32位**随机数

两个连续的随机数间隔**40个PLL48CLK时钟**

可以通过监控RNG熵来标识异常行为或禁止来降低功耗



原理：由数个环形振荡器组成，振荡器输出进行异或来产生种子，输入馈入线性反馈移位寄存器（RNG_LFSR），然后寄存器会把结果转移到读取此寄存器即可获得32位随机数

rng.c

```c
#include "rng.h"
#include "delay.h"

//RNG初始化
u8 RNG_inti(void)
{
	u16 RNG_retry=0;
	
	//1. 使能来自PLL48CLK的RNG时钟
	RCC_AHB2PeriphClockCmd(RCC_AHB2Periph_RNG,ENABLE);
	
	//2. 使能ENG时钟
	RNG_Cmd(ENABLE);
	
	//3. 等待随机数就绪
	while(RNG_GetFlagStatus(RNG_FLAG_DRDY)==RESET && RNG_retry<10000)
	{
		RNG_retry++;
		delay_us(100);
	}
	if(RNG_retry>=10000)
		return 1;//随机数初始化异常
	return 0;//随机数正常初始化
}


//获取随机数
//返回得到的32位随机数
u32 RNG_get_randnum(void)
{
	while(RNG_GetFlagStatus(RNG_FLAG_DRDY)==RESET);
		
	return RNG_GetRandomNumber();
}


//获取[min,max]范围的随机数
//返回整型随机数
int RNG_get_randrange(int min,int max)
{
	return RNG_get_randnum()%(max-min+1)+min;
}
```

rng.h

```c
#ifndef __RNG_H
	#define __RNG_H
	#include "sys.h"

	u8 RNG_inti(void);//RNG初始化
	u32 RNG_get_randnum(void);//获取随机数
	int RNG_get_randrange(int min,int max);//获取[min,max]范围的随机数
	
#endif
```

main.c

```c
#include "sys.h"
#include "delay.h"
#include "oled.h"
#include "rng.h"

int main(void)
{
    u32 show_randnum=0;
    int show_t=0;
    
    delay_init(168);
    OLED_init();
    RNG_init();
    
    while(1)
    {
        if(show_t%100==0)
        {
            show_randnum=RNG_get_randnum();
        	OLED_ShowNum(0,2,show_randnum,1,16);
        	delay_ms(1);
            
        	show_randnum=RNG_get_randrange(1,6);
            OLED_ShowNum(0,2,show_randnum,1,16);
            delay_ms(1);
        }
        t++;
        delay_ms(10);
    }
}
```

