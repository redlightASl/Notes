# 通过ESP32的SPI与STM32进行双机通讯

由于手头一个项目需要使用ESP32作为主设备控制一个负责跑运算程序的STM32，我又被迫用上了ESP-IDF的SPI库

但乐鑫提供的示例代码和官方文档里面的SPI用法只有

* SPI FLASH
* ESP32作为从机接收主机发来的SPI数据
* ESP32使用SPI控制LCD显示屏
* 两个ESP32之间使用SPI协议通讯

不能说没有我需要的程序逻辑，只能说没什么卵用

没办法偷懒就只能硬上了！

在此记录自己的实践过程

## 配置ESP32

目前很多人都把ESP32当成一个附带MCU的WIFI模块（虽然乐鑫在某种程度上也赞同），但是ESP32的性能是很强大的，内核跑到最高频率240MHz时甚至能把stm32f407吊起来打，日常使用的100MHz频率也足以打爆f103的狗头。所以在这个项目中我将ESP32作为系统的核心。

工作时，ESP32会向作为协处理器的STM32发送指令控制它的开启、关闭、紧急停止等。同时ESP32会接收到协处理器发来的数据，并通过WiFi上传到云端，这里建立了三个线程用于处理不同任务：

* SPI线程

  与stm32传输SPI数据，将收取到的人脸识别码转发给处理线程，并将网络线程传来的指令发送给stm32

* 网络线程

  连接wifi、与服务器建立http连接，发出GET、POST请求，等待处理线程传来数据

* 处理线程

  对SPI线程转发来的数据进行解析，转发给网络线程

来自官方示例的程序

```c

```

### 要进行的修改





### 修改后的代码





## ESP-IoT-Solution

这是l乐鑫提供的一套针对ESP32系列SoC的外设驱动和代码框架，作为ESP-IDF的补充组件使用，内置了

* I2C、SPI的总线驱动抽象
* I2S LCD外设驱动抽象
* 数码管控制芯片驱动抽象
* 官方开发板的BSP（板级支持包）及一套通用BSP开发框架
* 常用显示屏外设抽象
* 多种LED闪烁灯效
* PWM音频与DAC音频外设抽象
* LVGL图形库
* 按键与触摸屏外设抽象
* 常用的温湿度、环境光等传感器外设抽象
* 舵机控制器抽象
* SPI Flash、SD卡、eMMC、EEPROM等存储设备的外设驱动抽象和虚拟文件系统
* 一套针对ESP32系列SoC的加密和安全启动方案

更多信息可以参考[官方文档](https://docs.espressif.com/projects/espressif-esp-iot-solution/zh_CN/latest/index.html)

使用ESP-IoT-Solution的SPI驱动库可以非常快速地实现SPI功能，并且速度损失较小，如果有快速部署需求的话完全可以依托这个组件进行物联网开发

这个库里面的所有项目都是基于C面向对象的，所以按照同一套配置流程就能完成对大部分需求的开发；但是需要注意：**这个组件只能适用于ESP-IDF v4.0及以上版本**且**只有ESP32和ESP32-S2进行了适配**

使用SPI驱动的示例如下：

```c
spi_bus_handle_t bus_handle = NULL;
spi_bus_device_handle_t device_handle = NULL;

uint8_t data8_in = 0;
uint8_t data8_out = 0xff;
uint16_t data16_in = 0;
uint32_t data32_in = 0;

spi_config_t bus_conf = {
    .miso_io_num = 19,
    .mosi_io_num = 23,
    .sclk_io_num = 18,
}; // spi总线配置

spi_device_config_t device_conf = {
    .cs_io_num = 19,
    .mode = 0,
    .clock_speed_hz = 20 * 1000 * 1000,
}; // spi设备配置

bus_handle = spi_bus_create(SPI2_HOST, &bus_conf); //分别创建spi总线和挂载在这个总线上的spi设备
device_handle = spi_bus_device_create(bus_handle, &device_conf);

spi_bus_transfer_bytes(device_handle, &data8_out, &data8_in, 1); //传输1字节数据
spi_bus_transfer_bytes(device_handle, NULL, &data8_in, 1); //读取1字节数据
spi_bus_transfer_bytes(device_handle, &data8_out, NULL, 1); //写入1字节数据
spi_bus_transfer_reg16(device_handle, 0x1020, &data16_in); //传输16位数据
spi_bus_transfer_reg32(device_handle, 0x10203040, &data32_in); //传输32位数据

spi_bus_device_delete(&device_handle); //删除spi设备
spi_bus_delete(&bus_handle); //删除spi总线
```

使用`spi_bus_create()`创建一个总线实例，创建时需要指定SPI端口号（可选`SPI2_HOST`、`SPI3_HOST`）及总线配置项`spi_config_t`。总线配置项包括`MOSI`、`MISO`、`SCLK`引脚号，这些引脚在系统设计时已经确定，一般不在运行时切换。总线配置项还可以包括`max_transfer_sz`，即一次传输时的最大数据量，设置为0将使用默认值4096

使用`spi_bus_device_create()`在已创建的总线实例之上创建总线设备，创建时需要指定总线句柄、设备的`CS`引脚号、设备运行模式、设备运行的时钟频率，SPI传输**允许**根据设备的配置项**动态切换模式和频率**

## 配置STM32

这里使用的是STM32H750，通过HAL库操作SPI收发数据，STM32作为从机工作。

实际上STM32的主要任务是跑一个人脸识别算法，所以为了防止STM32在跑算法的时候被打断，就只能给它用上DMA，收到的东西全存进FIFO，用一个DMA中断提示设备收到信息，但是如果当前在跑算法，就先不理会DMA FIFO里的东西