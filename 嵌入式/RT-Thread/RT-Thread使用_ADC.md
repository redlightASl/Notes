# RT-Thread的ADC与DAC驱动

## ADC简介

ADC即模数转换器，是指将连续变化的模拟信号转换为离散的数字信号的器件。与之相对应的DAC是ADC的逆向过程。ADC 最早用于对无线信号向数字信号转换，如电视信号，长短播电台发接收等，现在已经用于生活中的方方面面，在仪表中尤为常见。

如下所示模数转换一般要经过**采样**、**保持**和**量化**、**编码**这几个步骤。在实际电路中，采样和保持，量化和编码在转换过程中是同时实现的。

* **采样**：将时间上连续变化的模拟信号转换为时间上离散的模拟信号
* **保持**：将采样取得的模拟信号保持一段时间，提供给后续的量化编码一个稳定值
* **量化**：将数值连续的模拟量转换为数字量的过程，任何数字量只能是某个最小数量单位的整数倍
* **编码**：将量化后的数字值格式化成ADC输出的数字量

## ADC的性能参数

### 分辨率

分辨率以**二进制**（或十进制）**数的位数**来表示，一般有8位、10位、12位、16位等，它说明模数转换器对输入信号的分辨能力，位数越多，表示**分辨率越高，恢复模拟信号时会更精确**

### 精度

精度表示ADC器件在所有的数值点上对应的模拟值和真实值之间的最大误差值，也就是**输出数值偏离线性最大的距离**

### 转换速率

转换速率是指ADC完成一次从模拟到数字的AD转换所需时间的倒数

转换速率就是实际意义上的ADC速度

## RTT的ADC驱动API

ADC设备被RTT视为一般的设备进行管理，可以像PIN、SPI、IIC一样使用ADC设备，但是存在以下几个特殊API

* 使能ADC通道

  在读取 ADC 设备数据前需要先使能设备

  ```c
  rt_err_t rt_adc_enable(rt_adc_device_t dev, rt_uint32_t channel);
  ```

* 读取ADC通道采样值

  ```c
  rt_uint32_t rt_adc_read(rt_adc_device_t dev, rt_uint32_t channel);
  ```

  使用这一函数来读取ADC通道采样值，并保存到一个变量

* 关闭ADC通道

  ```c
  rt_err_t rt_adc_disable(rt_adc_device_t dev, rt_uint32_t channel);
  ```

  使用以上函数关闭ADC通道，相当于不再使用ADC设备

## DAC简介

DAC指数模转换器，即把二进制数字量形式的离散数字信号转换为连续变化的模拟信号的器件，它是 DAC数模转换的逆向过程

DAC主要由**数字寄存器**、**模拟电子开关**、**位权网络**、**求和运算放大器**和**基准电压源**（或**恒流源**）组成。用存于数字寄存器的数字量的各位数码分别控制对应位的模拟电子开关，使数码为1的位在位权网络上产生与其位权成正比的电流值，再由运算放大器对各电流值求和，并转换成电压值。这一过程一般用*低通滤波*即可以实现。数字信号先进行解码，把数字码转换成与之对应的电平，形成阶梯状信号，然后进行低通滤波。

## DAC的性能参数

### 分辨率

分辨率是指DAC能够转换的二进制位数，位数越多分辨率越高

### 转换时间（建立时间）

建立时间是将一个数字量转换为稳定模拟信号所需的时间，也可以认为是转换时间

DAC中用建立时间来描述其速度，而不是ADC中常用的转换速率。一般地，电流输出型DAC建立时间较短，电压输出型DAC则较长

### 转换精度

精度是指输入端加有最大数值量时，DAC的实际输出值和理论计算值之差,它主要包括非线性误差、比例系统误差、失调误差。

### 线性度

理想的DAC是线性的，但实际DAC存在误差。线性度就是指数字量化时，DAC输出的模拟量按比例关系变化程度，线性度越高，DAC性能越理想，输出结果越精确

## RTT的DAC设备驱动

DAC的RTT驱动和ADC很相似，如下所示：

```c
rt_err_t rt_dac_enable(rt_dac_device_t dev, rt_uint32_t channel);/* 使能DAC设备通道 */
rt_uint32_t rt_dac_write(rt_dac_device_t dev, rt_uint32_t channel, rt_uint32_t value);/* 设置DAC通道输出值 */
rt_err_t rt_dac_disable(rt_dac_device_t dev, rt_uint32_t channel);/* 关闭DAC设备通道 */
```

## 示例程序

1. ADC

   ```c
   #include <rtthread.h>
   #include <rtdevice.h>
   
   #define ADC_DEV_NAME        "adc1"      /* ADC 设备名称 */
   #define ADC_DEV_CHANNEL     5           /* ADC 通道 */
   #define REFER_VOLTAGE       330         /* 参考电压 3.3V,数据精度乘以100保留2位小数*/
   #define CONVERT_BITS        (1 << 12)   /* 转换位数为12位 */
   
   static int adc_vol_sample(int argc, char *argv[])
   {
       rt_adc_device_t adc_dev;
       rt_uint32_t value, vol;
       rt_err_t ret = RT_EOK;
   
       /* 查找设备 */
       adc_dev = (rt_adc_device_t)rt_device_find(ADC_DEV_NAME);
       if (adc_dev == RT_NULL)
       {
           rt_kprintf("adc sample run failed! can't find %s device!\n", ADC_DEV_NAME);
           return RT_ERROR;
       }
   
       /* 使能设备 */
       ret = rt_adc_enable(adc_dev, ADC_DEV_CHANNEL);
   
       /* 读取采样值 */
       value = rt_adc_read(adc_dev, ADC_DEV_CHANNEL);
       rt_kprintf("the value is :%d \n", value);
   
       /* 转换为对应电压值 */
       vol = value * REFER_VOLTAGE / CONVERT_BITS;
       rt_kprintf("the voltage is :%d.%02d \n", vol / 100, vol % 100);
   
       /* 关闭通道 */
       ret = rt_adc_disable(adc_dev, ADC_DEV_CHANNEL);
   
       return ret;
   }
   ```
   
2. DAC

   ```c
   /*
    * 程序清单： DAC 设备使用例程
    * 例程导出了 dac_sample 命令到控制终端
    * 命令调用格式：dac_sample
    * 程序功能：通过 DAC 设备将数字值转换为模拟量，并输出电压值。
    * 示例代码参考电压为3.3V,转换位数为12位。
    */
   #include <rtthread.h>
   #include <rtdevice.h>
   
   #define DAC_DEV_NAME        "dac1"  /* DAC 设备名称 */
   #define DAC_DEV_CHANNEL     1       /* DAC 通道 */
   #define REFER_VOLTAGE       330         /* 参考电压 3.3V,数据精度乘以100保留2位小数*/
   #define CONVERT_BITS        (1 << 12)   /* 转换位数为12位 */
       
   static int dac_vol_sample(int argc, char *argv[])
   {
   	rt_dac_device_t dac_dev;
   	rt_uint32_t value, vol;
   	rt_err_t ret = RT_EOK;
   	/* 查找设备 */
   	dac_dev = (rt_dac_device_t)rt_device_find(DAC_DEV_NAME);
       if (dac_dev == RT_NULL)
       {
       	rt_kprintf("dac sample run failed! can't find %s device!\n", DAC_DEV_NAME);
   		return RT_ERROR;
   	}
   	ret = rt_dac_enable(dac_dev, DAC_DEV_NAME); /* 使能设备 */
          
       /* 设置输出值 */
       value = atoi(argv[1]);
       rt_dac_write(dac_dev, DAC_DEV_NAME, DAC_DEV_CHANNEL, &value);
       rt_kprintf("the value is :%d \n", value);
   	/* 转换为对应电压值 */
       vol = value * REFER_VOLTAGE / CONVERT_BITS;
       rt_kprintf("the voltage is :%d.%02d \n", vol / 100, vol % 100);
   	/* 关闭通道 */
   	ret = rt_dac_disable(dac_dev, DAC_DEV_CHANNEL);
   	return ret;
   }
   ```


### ADC与DAC设备使用注意事项

1. ADC和DAC通常都需要一定的转换时间，如果是实时性很高的设备，这些时间往往难以让人接受，所以应该赋予使用ADC的任务较低的优先级，不过实时性需求次要的设备很适合使用RTT的ADC/DAC驱动，RTT内部使用较完善的任务处理体系足以平衡一定的DAC转换时间损耗
2. 使用相关驱动函数时应当调用<rtdevice.h>

