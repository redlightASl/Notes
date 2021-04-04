# 电源管理

ESP-IDF中集成的电源管理算法可以根据应用程序组件的需求，调整外围总线 (APB) 频率、CPU 频率，并使芯片进入 Light-sleep 模式，尽可能减少运行应用程序的功耗

应用程序组件可以通过创建和获取电源管理锁来控制功耗

编译时可使用CONFIG_PM_ENABLE选项启用电源管理功能

## 电源管理配置

（摘自官网）启用电源管理功能将会增加中断延迟。额外延迟与多个因素有关，例如CPU频率、单/双核模式、是否需要进行频率切换等（CPU 频率为 240 MHz 且未启用频率调节时，最小额外延迟为 0.2 us；如果启用频率调节，且在中断入口将频率由 40 MHz 调节至 80 MHz，则最大额外延迟为 40 us）

应用程序可以通过调用esp_pm_configure()函数启用动态调频（DFS）功能和自动light-sleep模式。

通过esp_pm_config_esp32_t结构体来设置相关参数，如下所示

```c
struct esp_pm_config_esp32_t//pm代表power management
{
    int max_freq_mhz;//最大CPU频率，也就是获取ESP_PM_CPU_FREQ_MAX锁后使用的频率，单位MHz
    int min_freq_mhz;//最小CPU频率，也就是获取ESP_PM_APB_FREQ_MAX锁后使用的频率，单位MHz，可设置为晶振频率值或晶振频率除以一个整数，但是需要注意10MHz是生成1MHz的REF_TICK默认时钟所需的最小频率
    bool light_sleep_enable;//当未获得任何管理锁时，决定系统是否需要自动进入light-sleep状态
}
```

## 电源管理锁与管理算法

**应用程序可以通过获取或释放管理锁来控制电源管理算法**

ESP32 支持下表中所述的三种电源管理锁。

| 电源管理锁            | 描述                                                         |
| --------------------- | ------------------------------------------------------------ |
| ESP_PM_CPU_FREQ_MAX   | 请求使用esp_pm_configure将CPU频率设置为最大值。ESP32可以将该值设置为 80 MHz、160 MHz 或 240 MHz。 |
| ESP_PM_APB_FREQ_MAX   | 请求将APB频率设置为最大值，ESP32支持的最大频率为80MHz        |
| ESP_PM_NO_LIGHT_SLEEP | 禁止自动切换至Light-sleep模式                                |

如果没有获取任何管理锁，调用esp_pm_configure()将启动Light-sleep模式

Light-sleep模式持续时间由以下因素决定：1.处于阻塞状态的FreeRTOS任务书；2.高分辨率定时器API注册的计数器数量

## 动态调频和外设驱动

启用动态调频后，APB频率可在一个RTOS滴答周期内多次更改。有些外设不受APB频率变更的影响，但有些外设可能会出现问题

UART、LEDC、RMT不受APB频率变更的影响

SPI master、I2C、I2S、SDMMC可以感知动态调频并在调频期间使用ESP_PM_APB_FREQ_MAX锁

启用SPI slave、以太网、wifi、蓝牙、CAN时，将占用ESP_PM_APB_FREQ_MAX锁

MCPWM、PCNT、Sigma-delta、Timer Group无法感知动态调频，需要应用程序自行获取、释放管理锁

ESP32 在内置**Deep-sleep低功耗模式**、**RTC外设**和**ULP协处理器**的支持下，可以满足多种应用场景下的低功耗需求

（ULP协处理器见最后部分）

# 低功耗模式

ESP32可以进入light-sleep和deep-sleep模式，还能进入一个用于相对较低功耗运行的modem-sleep模式

注意：**进入低功耗模式前，应用程序必须关闭wifi和蓝牙设备**，如果需要维持wifi连接，应当使用modem-sleep模式，在这个模式下当需要wifi驱动执行时系统会自动唤醒来维持wifi连接

## light-sleep

==CPU暂停运行，wifi/蓝牙基带和射频关闭。RTC、ULP运行，任何唤醒事件都会唤醒芯片==

在light-sleep模式下，数字外设、大部分内存和CPU都会被停用（停用时钟），电源功耗也会降低，从light-sleep模式下唤醒后外设和CPU会接回时钟源并继续工作，他们的外部状态会被保存

**这个模式可以理解为电脑的挂起休眠**

## deep-sleep

==CPU、大部分外设掉电，wifi/蓝牙基带和射频关闭，进有RTC、ULP运行，wifi和蓝牙连接数据被转移到RTC内存中。仅有一部分中断源会唤醒芯片==

deep-sleep模式下，由APB_CLK时钟提供是时钟源的CPU、大部分内存和所有数字外设都会掉电；只有片上RTC控制器、RTC外设、ULP和RTC内存会被保留电源

**这个模式可以理解为电脑的断电休眠**

Deep-sleep模式下支持从以下唤醒源触发的设备唤醒

* 定时器
* touchpad
* Ext(0)：RTC IO中某个指定GPIO满足指定电平即唤醒
* Ext(1)：RTC IO中某些指定GPIO同时满足指定电平才能唤醒
* ULP协处理器

睡眠唤醒源可以在进入light-sleep或deep-sleep之前的任何时间设置

特别地，应用程序可以调用esp_sleep_pd_config()函数来让RTC外设和RTC内存掉电

设置好中断源后可以使用esp_light_sleep_start()和esp_deep_sleep_start()来进入睡眠模式

### 中断源

使用esp_sleep_disable_wakeup_source()来停用某个已经设置的中断源

设置中断源的方法如下

#### 定时器

RTC控制器自带一个能够在预定义时间后进行唤醒的定时器

这个换新模式不需要在睡眠期间为RTC外设或RTC内存上电

使用esp_sleep_enable_timer_wakeup()使能这个功能

#### 触摸检测

RTC IO模块包括了一套触摸传感器中断触发唤醒的逻辑，需要在MCU进入睡眠之前配置好触摸中断唤醒

只有在RTC外设没有被强行上电的时候才能使用这个唤醒模式

使用esp_sleep_enable_touchpad_wakeup()函数来使能这个中断源

#### 特定外部引脚

RTC IO模块包括了一套GPIO触发唤醒的逻辑。如果这个中断源被使能，RTC外设需要保持上电状态。因为RTC IO模组在这个模式中被使能，中断上拉或下拉电阻也会被使用到，它们需要通过rtc_gpio_pullup_en()和rtc_gpio_pulldown_en()函数设置

调用esp_sleep_enable_ext0_wakeup()函数来使能这个中断源

此外，也可以使用多个GPIO同时触发唤醒

配置API如下

```c
esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_PERIPH, ESP_PD_OPTION_ON);//开启特定GPIO唤醒
gpio_pullup_dis(gpio_num);//配置gpio_num为上拉
gpio_pulldown_en(gpio_num);//配置gpio_num为下拉
rtc_gpio_isolate(gpio_num);//配置gpio_num为高阻态

rtc_gpio_deinit(gpio_num);//使用这个函数来取消配置引脚
```

rtc_gpio_isolate()可以用于防止进入休眠后由GPIO产生的额外功耗

#### ULP协处理器

可以使用esp_sleep_enable_ulp_wakeup()来启用ULP协处理器指令唤醒

#### GPIO

除了特定的外部引脚触发唤醒，还可以**在light-sleep下**使用gpio_wakeup_enable()来设定任意GPIO的高/低电平触发唤醒

在进入睡眠模式之前使用esp_sleep_enable_gio_wakeup()来使能该唤醒源

#### UART

**在light-sleep下**可以使用esp_sleep_enable_uart_wakeup()来启用UART触发唤醒

若开启该触发源，当睡眠状态的ESP32收到来自外部设备的UART输入的数个上升沿时，会自动唤醒，该上升沿数目可以用uart_set_wakeup_threshold()函数配置；在这个触发信号被接收之前，所有信息不会被接收——这就意味着外部设备需要发送额外的字符给ESP32来让它唤醒

## modem-sleep

==CPU运行、可配置时钟，wifi/蓝牙基带和射频关闭，但会维持wifi连接==

# RTC外设

RTC外设不仅包括RTC，还包括了片上温度传感器、ADC、RTC-GPIO和touchpad外设

# ULP协处理器

ULP（Ultra Low Power超低功耗）协处理器是一种简单的**有限状态机**（FSM）。在主处理器处于Deep-sleep深度睡眠模式时，它可以使用ADC、温度传感器和外部IIC传感器执行测量操作。ULP协处理器可以访问RTC慢速内存区域（RTC_SLOW_MEM）及RTC_CNTL、RTC_IO、SARADC等外设寄存器。ULP协处理器使用**32位固定宽度的指令**、**32位内存寻址**，配备**4个16位通用寄存器**

## ULP协处理器编程

ULP协处理器代码是用**汇编**语言编写的，并使用**binutils-esp32ulp工具链**进行编译

开发环境被集成到ESP-IDF中

编译方法如下：

1. ULP代码必须导入到一个或多个.S扩展文件中，源文件必须放在组件目录中一个独立的目录（如ulp/）

2. 注册后从组件CMakeLists.txt中调用ulp_embed_binary，示例如下

   ```cmake
   ...
   idf_component_register()
   
   set(ulp_app_name ulp_${COMPONENT_NAME})
   set(ulp_s_sources ulp/ulp_assembly_source_file.S)
   set(ulp_exp_dep_srcs "ulp_c_source_file.c") #二进制文件命名
   
   ulp_embed_binary(${ulp_app_name} "${ulp_s_sources}" "${ulp_exp_dep_srcs}") # 导入二进制文件
   ```

3. 使用常规方法编译应用程序，ULP程序会被自动生成

   构建系统的内部编译步骤如下：

   1. 通过C预处理器运行每个.S文件，生成依赖文件和经过预处理的程序集文件
   2. 运行汇编器进行编译
   3. 通过C预处理器运行链接器脚本模板（位于components/ulp/ld目录）
   4. 将目标文件链接到.elf输出文件
   5. 将elf中的内容转储为.bin二进制文件
   6. 使用esp32ulp-elf-nm工具在elf文件中生成全局符号列表
   7. 创建LD导出脚本和头文件
   8. 将生成的二进制文件添加到要嵌入应用程序的二进制文件列表中

   总体过程和在mcu中嵌入二进制格式的其他文件类似，只是多出了编译的几步

## 使用ULP程序

**在ULP程序中定义的全局符号也可以在主程序中使用**

如果要从主程序访问ULP程序变量，应先**使用include语句包含生成的头文件**，这样就可以像访问常规变量一样访问ulp程序变量

注意：**ULP程序在RTC内存中只能使用32位字的低16位，因为寄存器是16位的并且不具备从字的高位加载的指令**

主应用程序需要**调用ulp_load_binary函数**将ULP程序加载到RTC内存中，然后**调用ulp_run函数**启动ULP程序。ULP协处理器由定时器启动，而调用ulp_run则可启动此定时器，定时器为RTC_SLOW_CLK的Tick事件计数（默认情况下，Tick由内部150 KHz晶振器生成）。一旦定时器为所选的SENS_ULP_CP_SLEEP_CYCx_REG寄存器的Tick事件计数，ULP协处理器就会启动，并调用ulp_run的入口点开始运行程序。程序保持运行，直到遇到halt指令或非法指令。一旦程序停止，ULP协处理器电源关闭，定时器再次启动。

使用 `SENS_ULP_CP_SLEEP_CYCx_REG` 寄存器 (x = 0..4) 设置 Tick 数值。第一次启动 ULP 时，使用 `SENS_ULP_CP_SLEEP_CYC0_REG` 设置定时器 Tick 数值，之后，ULP 程序可以使用 `sleep` 指令来另外选择 `SENS_ULP_CP_SLEEP_CYCx_REG` 寄存器

## 汇编指令集参考

ESP32与ESP32S2的汇编指令集并不相同，详情参考官网即可

[ESP32指令集参考](https://docs.espressif.com/projects/esp-idf/zh_CN/release-v4.1/api-guides/ulp_instruction_set.html)

[ESP32S2指令集参考](https://docs.espressif.com/projects/esp-idf/zh_CN/release-v4.1/api-guides/ulps2_instruction_set.html)

汇编大同小异，下面给出几个常见的指令

| 指令                      | 说明                                            |
| ------------------------- | ----------------------------------------------- |
| NOP                       | 空指令                                          |
| SUB R1,R2,R3              | R1=R2-R3                                        |
| AND R1,R2,R3              | R1=R2&R3                                        |
| OR R1,R2,R3               | R1=R2\|R3                                       |
| LSH R1,R2,R3              | R1=R2<<R3                                       |
| RSH R1,R2,R3              | R1=R2>>R3                                       |
| MOVE R1,R2                | R1=R2                                           |
| ST R1,R2,k                | MEM[R2+k]=R1                                    |
| LD R1,R2,k                | R1=MEM[R2+k]                                    |
| JUMP R1                   | 跳转到R1所在地址                                |
| HALT                      | 协处理器停机                                    |
| WAKE                      | 协处理器唤醒                                    |
| SLEEP k                   | 协处理器睡眠k个时间单位                         |
| REG_RD Addr,HIGH,LOW      | 读外设寄存器地址为Addr从LOW到HIGH的内容         |
| REG_WR Addr,HIGH,LOW,Data | 将Data写入外设寄存器地址为Addr从LOW到HIGH的内容 |
