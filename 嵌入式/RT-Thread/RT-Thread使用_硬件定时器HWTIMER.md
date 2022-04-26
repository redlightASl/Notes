# 硬件定时器HWTIMER

在RTT中可以使用软件定时器和硬件定时器

其中

硬件定时器被封装为两个工作模式：定时器模式和计数器模式

1. 定时器模式：对内部脉冲信号计数

   定时器常用作**定时时钟**，用于实现定时检测、定时响应、定时控制等功能

   由于系统时钟频率恒定，所以可以根据定时器的计数值计算出定时时间，公式如下

   $$定时时间=\frac{计数值}{计数频率}$$

   16位计数器最大计数值为65535，32位计数最大值为4294967295，计数频率即硬件定时器时钟频率（单位MHz）

   定时时间单位微秒（us）

2. 计数器模式：对外部输入引脚的外部脉冲信号计数

   计数器可以**递增**或**递减**计数，16位计数器最大计数值为65535，32位计数最大值为4294967295

## 访问定时器设备的方法

### 查找定时器设备

```c
rt_device_t rt_device_find(const char* name);
```

根据输入的硬件定时器设备名称获取设备句柄

### 打开/关闭硬件定时器

```c
rt_err_t rt_device_open(rt_device_t dev, rt_uint16_t oflags);//打开
rt_err_t rt_device_close(rt_device_t dev);//关闭
```

打开、关闭定时器一定要**配对使用**

oflags为打开方式，一般采用读写方式`RT_DEVICE_OFLAG_RDWR`打开，打开设备时会自动检测设备是否初始化，如果没有初始化则会当场进行初始化

### 设置定时器超时值

```c
rt_size_t rt_device_write(rt_device_t dev,//设备句柄
                          rt_off_t pos,//写入数据偏移量，如果不使用可以设置为0
                          const void* buffer,//指向定时器超时时间结构体的指针，用作输入
                          rt_size_t size);//超时时间结构体大小
```

超时时间结构体原型如下所示：

```c
typedef struct rt_hwtimerval
{
    rt_int32_t sec;//秒 s
    rt_int32_t usec;//微秒 us
} rt_hwtimerval_t;
```

超时时间最小能设定为us级别

### 设置超时回调函数

```c
rt_err_t rt_device_set_rx_indicate(rt_device_t dev,//设备句柄
                                   rt_err_t (*rx_ind)(rt_device_t dev,rt_size_t size))//超时函数
```

超时函数必须按照以上形式进行定义，即

```c
rt_err_t timeout_func(rt_device_t dev,rt_size_t size)
```

### 获取当前值

```c
rt_size_t rt_device_read(rt_device_t dev,//设备句柄
                         rt_off_t pos,//写入数据偏移量，如果不使用可以设置为0
                         void* buffer,//指向定时器超时时间结构体的指针，用作输出
                         rt_size_t size);//超时时间结构体大小
```

使用例

```c
rt_hwtimerval_t timeout_s; /* 用于保存定时器经过时间 */
rt_device_read(hw_dev,
               0,
               &timeout_s,//读出数据在此保存
               sizeof(timeout_s));/* 读取定时器经过时间 */
```

### 控制定时器设备

```c
rt_err_t rt_device_control(rt_device_t dev,//设备句柄
                           rt_uint8_t cmd,//控制命令
                           void* arg);//定时器特征信息参数
```

可用的控制命令cmd如下所示

```c
HWTIMER_CTRL_FREQ_SET //设置计数频率
HWTIMER_CTRL_STOP //停止定时器
HWTIMER_CTRL_INFO_GET //获取定时器特征信息
HWTIMER_CTRL_MODE_SET //设置定时器模式
```

获取定时器特征信息参数arg为指向结构体struct rt_hwtimer_info的指针，作为一个输出参数保存获取的信息

可用取值如下

```c
HWTIMER_MODE_ONESHOT //单次定时
HWTIMER_MODE_PERIOD //周期性定时
```

注意：==定时器硬件及驱动支持设置计数频率的情况下设置频率才有效，一般使用驱动设置的默认频率即可==

## 特别注意（摘自官方文档）

**可能出现定时误差**

假设计数器最大值 0xFFFF，计数频率 1Mhz，定时时间 1 秒又 1 微秒。由于定时器一次最多只能计时到 65535us，对于 1000001us 的定时要求。可以 50000us 定时 20 次完成，此时将会出现计算误差 1us

（所以不要对RTOS的定时精度有太高要求，差不多得了）

# 使用示例

```c
#include <rtthread.h>
#include <rtdevice.h>

#define HWTIMER_DEV_NAME   "timer0" /* 定时器名称 */

static rt_err_t timeout_cb(rt_device_t dev, rt_size_t size)/* 定时器超时回调函数 */
{
    rt_kprintf("this is hwtimer timeout callback fucntion!\n");
    rt_kprintf("tick is :%d !\n", rt_tick_get());//获取当前系统时钟

    return 0;
}

static int hwtimer_sample(int argc, char *argv[])
{
    rt_err_t ret = RT_EOK;
    rt_hwtimerval_t timeout_s;      /* 定时器超时时间结构体 */
    rt_device_t hw_dev = RT_NULL;   /* 定时器设备句柄 */
    rt_hwtimer_mode_t mode;         /* 定时器模式 */

    /* 查找定时器设备 */
    hw_dev = rt_device_find(HWTIMER_DEV_NAME);
    if (hw_dev == RT_NULL)
    {
        rt_kprintf("hwtimer sample run failed! can't find %s device!\n", HWTIMER_DEV_NAME);
        return RT_ERROR;
    }

    /* 以读写方式打开设备 */
    ret = rt_device_open(hw_dev, RT_DEVICE_OFLAG_RDWR);
    if (ret != RT_EOK)
    {
        rt_kprintf("open %s device failed!\n", HWTIMER_DEV_NAME);
        return ret;
    }

    /* 设置超时回调函数 */
    rt_device_set_rx_indicate(hw_dev, timeout_cb);

    /* 设置模式为周期性定时器 */
    mode = HWTIMER_MODE_PERIOD;
    ret = rt_device_control(hw_dev, HWTIMER_CTRL_MODE_SET, &mode);
    if (ret != RT_EOK)
    {
        rt_kprintf("set mode failed! ret is :%d\n", ret);
        return ret;
    }

    /* 设置定时器超时值为5s并启动定时器 */
    timeout_s.sec = 5; /* 秒 */
    timeout_s.usec = 0; /* 微秒 */

    if (rt_device_write(hw_dev, 0, &timeout_s, sizeof(timeout_s)) != sizeof(timeout_s))
    {
        rt_kprintf("set timeout value failed\n");
        return RT_ERROR;
    }

    /* 延时3500ms */
    rt_thread_mdelay(3500);

    /* 读取定时器当前值 */
    rt_device_read(hw_dev, 0, &timeout_s, sizeof(timeout_s));
    rt_kprintf("Read: Sec = %d, Usec = %d\n", timeout_s.sec, timeout_s.usec);

    return ret;
}
```

