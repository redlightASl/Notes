# 电容触摸开关

​	实现步骤：

1. Touch_PAD引脚设置为推挽输出，初始输出0，实现电容放电到0
2. 等待IO复位，Touch_PAD引脚设置为浮空输入，等待电容充电
3. 等待同时开启Touch_PAD引脚输入捕获
4. 等待充电完成（充电到底，Vx检测到上升沿）
5. 计算充电时间

开关触发条件：没有按下时，充电时间为T_default，Touch_PAD按下时电容变大，充电时间为T_touch，若(T_default-T_touch)<T_trigger，则可判断按键按下，开关触发

### u8 Touch_PAD_init(u8 psc)

初始化触摸按键并提供按键充电时间的参考参数

TPAD_ARR_MAX_VAL为初始设置的最大充电时间

```c
u8 Touch_PAD_init(u8 psc)
{
    u16 buf[10];
	u8 i,j;
	u16 average;

	TIM2_CH1_Capture_init(TPAD_ARR_MAX_VAL,psc-1);

	for(i=0;i<10;i++)//连续读取10次数据
	{
    	buf[i]=Touch_PAD_get_val();
    	delay_ms(10);
	}
    
	for(i=0;i<9;i++)//选择排序
	{	
    	for(j=i+1;j<10;j++)//升序排列
    	{
        	if(buf[i]>buf[j])//若buf[i]比buf[j]大，交换两者位置
        	{
            	buf[i]=buf[i]^buf[j];
            	buf[j]=buf[i]^buf[j];
            	buf[i]=buf[i]^buf[j];
        	}
    	}
	}
    
	for(i=2;i<8;i++)
    	average+=bug[i];//取10个数中间6个数进行平均
	Touch_PAD_default_val=average/6;
    
    if(Touch_PAD_default_val>TPAD_ARR_MAX_VAL)//若初始化时遇到超过TPAD_ARR_MAX_VAL的值
        return 1;//不正常
    else 
        return 0;//否则正常
    
}
```

### Touch_PAD_get_val()

获得当前触摸按键充电时间的值

```c
u16 Touch_PAD_get_val(void)
{
    Touch_PAD_reset();
    while(TIM_GetFlagStatus(TIM2,TIM_IT_OC1)==RESET)//等待捕获上升沿
    {
        if(TIM_GetCounter(TIM2)>TPAD_ARR_MAX_VAL-500)
            return TIM_GetCounter(TIM2);//如果超时则直接返回CNT的值
    }
       return TIM_GetCapture1(TIM2);//返回捕获到的充电时间
}
```

### Touch_PAD_reset

重置触摸按键为初始状态

```c
void Touch_PAD_reset(void)
{
    GPIO_InitTypeDef GPIO_InitStructure
        
    GPIO_InitStructure.GPIO_Pin=GPIO_Pin_5;//PA5
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_OUT;//普通输出
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//速度100MHz
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽输出
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_DOWN;//内部下拉
    //应用设置
	GPIO_Init(GPIOA,&GPIO_InitStructure);
    
    GPIO_ResetBits(GPIOA,GPIO_Pin_5);//PA5输出0，电容放电
    
    delay_ms(5);//等待电容放电
    
    TIM_ClearITPendingBit(TIM2,TIM_IT_OC1|TIM_IT_Update);//清除中断标志
	TIM_SetCounter(TIM2,0);//TIM2归零
    
    GPIO_InitStructure.GPIO_Pin=GPIO_Pin_5;//PA5
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AF;//复用功能
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//速度100MHz
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽复用输出
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_NOPULL;//引脚悬空
    //应用设置
	GPIO_Init(GPIOA,&GPIO_InitStructure);
}   
```

****

### Touch_PAD_scan

主循环运行中扫描按键状态

```c
#define TPAD_GATE_VAL 100 
//设置触摸的门限值，即必须大于Touch_PAD_default_val+TPAD_GATE_VAL才被认定为一次有效触摸

u8 Touch_PAD_scan(u8 mode)//支持单次/连续触发
{
    static u8 keyen=0;//为0，可以开始检测，大于0则不能开始检测
    u8 res=0;
    u8 sample=3;//默认采样3次
    u16 rval;
    
    if(mode)
    {
        sample=6;//支持连按时采样6次
        keyen=0;//支持连按
    }
    
    rval=Touch_PAD_get_MAXVAL(sample);
    
    if((rval>Touch_PAD_default+TPAD_GATE_VAL)&&(rval<10*Touch_PAD_default_val))
    {
        if((keyen==0)&&(rval>Touch_PAD_default_val+TPAD_GATE_VAL)
        {
            res=0;
        }
        keyen=3;
    }
    if(keyen)
    	keyen--;
	return res;
}
```

### Touch_PAD_get_MAXVAL

读取n次，取其中最大值

```c
u16 Touch_PAD_get_MAXVAL(u8 n)//采样n次
{
    u16 temp=0;
	u16 res=0;    
    while(n--)
    {
        temp=Touch_PAD_get_val();//读取n次值
        if(temp>res)//取其中最大的
            res=temp;
    }
    return res;//返回最大值
}
```

****

### TIM2_CH1_Capture_init(u32 arr,u16 psc)

TIM2 IC1初始化

```c
void TIM2_CH1_Capture_init(u32 arr,u16 psc)
{
    GPIO_InitTypeDef GPIO_InitStructure;
	TIM_TimeBaseInitTypeDef TIM_TimeBaseStructure;
    TIM_ICInitTypeDef TIM2_ICInitStructure;
    
    RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM2,ENABLE);//使能TIM2时钟    
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA, ENABLE);//使能PA时钟	

    GPIO_InitStructure.GPIO_Pin=GPIO_Pin_5;//PA5
	GPIO_InitStructure.GPIO_Mode=GPIO_Mode_AF;//复用功能
	GPIO_InitStructure.GPIO_Speed=GPIO_Speed_100MHz;//速度100MHz
	GPIO_InitStructure.GPIO_OType=GPIO_OType_PP;//推挽复用输出
	GPIO_InitStructure.GPIO_PuPd=GPIO_PuPd_NOPULL;//引脚悬空
    //应用设置
	GPIO_Init(GPIOA,&GPIO_InitStructure);
    
    GPIO_PinAFConfig(GPIOA,GPIO_PinSource5,GPIO_AF_TIM2);//GPIOA5复用为定时器2
    
    TIM_TimeBaseStructure.TIM_Prescaler=psc;//定时器分频
	TIM_TimeBaseStructure.TIM_CounterMode=TIM_CounterMode_Up;//向上计数模式
	TIM_TimeBaseStructure.TIM_Period=arr;//自动重装载值
	TIM_TimeBaseStructure.TIM_ClockDivision=TIM_CKD_DIV1;//设置时钟分割：TDTS=Tck_tim 
	//应用设置
	TIM_TimeBaseInit(TIM5,&TIM_TimeBaseStructure);

	TIM2_ICInitStructure.TIM_Channel=TIM_Channel_1; //CC1S=01 选择输入端 IC1映射到TIM2上
  	TIM2_ICInitStructure.TIM_ICPolarity=TIM_ICPolarity_Rising;//上升沿捕获
  	TIM2_ICInitStructure.TIM_ICSelection=TIM_ICSelection_DirectTI;
  	TIM2_ICInitStructure.TIM_ICPrescaler=TIM_ICPSC_DIV1;	 //配置输入分频,不分频 
  	TIM2_ICInitStructure.TIM_ICFilter=0x00;//IC2F=0000 配置输入滤波器 不滤波
    //应用TIM2-IC1设置
  	TIM_ICInit(TIM2,&TIM2_ICInitStructure);
	
    //不设置中断，在Touch_PAD_get_val中判断上升沿捕获标志位
    //如果捕获到上升沿，则直接置标志位为1
    
	TIM_Cmd(TIM2,ENABLE);
}
```













