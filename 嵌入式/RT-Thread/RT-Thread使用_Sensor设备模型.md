# RT-Thread中的传感器设备

Rt-Thread的新版本中更新了传感器设备，这使得各种传感器外设可以使用统一的代码接入RT-Thread。这使得通过移植RT-Thread可以使用一套统一的驱动代码控制底层设备

> Sensor 设备的作用是：为上层提供统一的操作接口，提高上层代码的可重用性——官方文档

传感器设备*继承自标准的RTT设备接口*（RTT-Device），基本的open、close、read和各种控制函数都可以直接对传感器设备使用。除此之外，它还支持轮询、中断、FIFO三种工作模式，可以通过扩展编辑底层代码支持掉电、普通、低功耗、高功耗四种功耗模式。目前**RTT官方只提供了一部分温湿度、气压、加速度、陀螺仪、光照传感器的Sensor设备接口**，但是**开源社区中已经有dalao开发出来dhtxx、mpu60xx等市面上相对流行的RTT Sensor设备接口**，只要在软件包中添加即可

==**使用RTT device相关函数即可访问传感器设备**==

下表摘录自官网

| **函数**                    | **描述**                                   |
| --------------------------- | ------------------------------------------ |
| rt_device_find()            | 根据传感器设备设备名称查找设备获取设备句柄 |
| rt_device_open()            | 打开传感器设备                             |
| rt_device_read()            | 读取数据                                   |
| rt_device_control()         | 控制传感器设备                             |
| rt_device_set_rx_indicate() | 设置接收回调函数                           |
| rt_device_close()           | 关闭传感器设备                             |

不多作介绍，如果有疑惑可以参考RT-Thread的统一设备驱动模型

需要特别注意：`rt_device_open`可以采用三种方式：`RT_DEVICE_FLAG_RDONLY`（只读）、`RT_DEVICE_FLAG_INT_RX`（中断接收）、`RT_DEVICE_FLAG_FIFO_RX`（FIFO接收），其中只读方式等效于轮询读取传感器数据，这个方式是函数参数没有指定时会默认使用的；FIFO则需要传感器硬件支持才能使用，数据会被存储在硬件FIFO中，一次读出多位数据，节省了CPU资源，可配合DMA针对低功耗模式进行优化或者用于高实时性场合

## 控制传感器

使用以下函数配合传感器命令参数来对传感器进行控制：

```c
rt_err_t rt_device_control(rt_device_t dev, rt_uint8_t cmd, void* arg);
```

其中dev是设备句柄，通过`rt_device_find`获取；cmd就是控制命令，arg是命令的参数

目前cmd支持以下几种：

* RT_SENSOR_CTRL_GET_ID **读取设备ID**

  ```c
  rt_uint8_t reg = 0xFF; //这里是设备ID地址，读出的设备ID会被保存在这里
  rt_device_control(dev, RT_SENSOR_CTRL_GET_ID, &reg);
  
  //使用Debug指令可以直接输出reg的内容
  ```

* RT_SENSOR_CTRL_SELF_TEST **设备自检**

  ```c
  int test_res;
  //会返回设备自检结果，RT_EOK表示成功，其他为自检失败
  rt_device_control(dev, RT_SENSOR_CTRL_SELF_TEST, &test_res);
  ```

* RT_SENSOR_CTRL_GET_INFO **获取设备信息**

  ```c
  struct rt_sensor_info info; //设备信息被封装在传感器设备结构体里
  rt_device_control(dev, RT_SENSOR_CTRL_GET_INFO, &info); //需要传入传感器设备结构体指针
  ```

* RT_SENSOR_CTRL_SET_RANGE **设置传感器测量范围**

  在arg部分需要填入合适的单位

* RT_SENSOR_CTRL_SET_ODR **设置传感器输出速率**，单位为Hz

  ```c
  rt_device_control(dev, RT_SENSOR_CTRL_SET_ODR, (void *)100); //官网示例，一看就懂
  ```

* RT_SENSOR_CTRL_SET_POWER **设置设备电源模式**

  ```c
  /* 设置电源模式为掉电模式 */
  rt_device_control(dev, RT_SENSOR_CTRL_SET_POWER, (void *)RT_SEN_POWER_DOWN);
  /* 设置电源模式为普通模式 */
  rt_device_control(dev, RT_SENSOR_CTRL_SET_POWER, (void *)RT_SEN_POWER_NORMAL);
  /* 设置电源模式为低功耗模式 */
  rt_device_control(dev, RT_SENSOR_CTRL_SET_POWER, (void *)RT_SEN_POWER_LOW);
  /* 设置电源模式为高性能模式 */
  rt_device_control(dev, RT_SENSOR_CTRL_SET_POWER, (void *)RT_SEN_POWER_HIGH);
  ```

## 使用传感器设备模型

一般来说引入了RTOS的设备不应该多使用中断，所以一般的传感器直接使用轮询模式读取即可，下面配合mpu6050软件包演示了如何使用传感器设备模型读取mpu6050传感器数据

### 前期配置







### 根据PCBA/开发板引脚分配要使用的外设







### 创建任务









### 创建消息队列















