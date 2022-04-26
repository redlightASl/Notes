# PIN设备

MCU/SoC上的引脚可以分为四类：电源（PWR、VCC、VDD、VSS、GND等）、时钟（CCLK、CLK、SLK等）、控制（EN、NSS、PRI等）、IO（GPIOx、I/Ox、Px、URx、UTx、SPIx、IICx等）

不同于一般MCU裸机编程中的GPIO复用（AF）设置，RTT将MCU的GPIO抽象为通用引脚PIN设备

在RTT系统中可以编程以下设置

* 可编程中断

共5种类型

| 上升沿触发 | 检测无抖动的上升沿 |
| ---------- | ------------------ |
| 下降沿触发 | 检测无抖动的下降沿 |
| 高电平触发 | 检测高电平状态     |
| 低电平触发 | 检测低电平状态     |
| 双边沿触发 | 检测无抖动的双边沿 |

* 可编程输入输出

* 可编程具体使用模式

输出模式对应：**推挽、开漏、内部上拉、内部下拉**

输入模式对应：**浮空、内部上拉、内部下拉、模拟**

# PIN设备的使用

RTT内置了一些PIN设备API供用户使用

## 获取引脚编号

**RTT提供的引脚编号和芯片的引脚编号不是同一个概念**

RTT的引脚编号由设备驱动程序定义

使用宏函数GET_PIN或查阅PIN驱动文件可以获取到引脚编号

1. GET_PIN()函数

通常在rt-thread/bsp/board目录中保存，需要相关的板级支持包（BSP）才能使用

部分BSP没有移植此函数

2. 查看驱动文件

所有BSP都会移植相关PIN驱动代码，可以查看drv_gpio.c文件确认引脚编号

**通常引脚编号保存在一个固定数组中**，如下所示

```c
static const struct pin_index pins[] =
{
#if (STM32F10X_PIN_NUMBERS == 36)
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(7, A, 0),
    __STM32_PIN(8, A, 1),
    __STM32_PIN(9, A, 2),
    __STM32_PIN(10, A, 3),
    __STM32_PIN(11, A, 4),
    __STM32_PIN(12, A, 5),
    __STM32_PIN(13, A, 6),
    __STM32_PIN(14, A, 7),
    __STM32_PIN(15, B, 0),
    __STM32_PIN(16, B, 1),
    __STM32_PIN(17, B, 2),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(20, A, 8),
    __STM32_PIN(21, A, 9),
    __STM32_PIN(22, A, 10),
    __STM32_PIN(23, A, 11),
    __STM32_PIN(24, A, 12),
    __STM32_PIN(25, A, 13),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(28, A, 14),
    __STM32_PIN(29, A, 15),
    __STM32_PIN(30, B, 3),
    __STM32_PIN(31, B, 4),
    __STM32_PIN(32, B, 5),
    __STM32_PIN(33, B, 6),
    __STM32_PIN(34, B, 7),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
#endif
#if (STM32F10X_PIN_NUMBERS == 48)
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(2, C, 13),
    __STM32_PIN(3, C, 14),
    __STM32_PIN(4, C, 15),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(10, A, 0),
    __STM32_PIN(11, A, 1),
    __STM32_PIN(12, A, 2),
    __STM32_PIN(13, A, 3),
    __STM32_PIN(14, A, 4),
    __STM32_PIN(15, A, 5),
    __STM32_PIN(16, A, 6),
    __STM32_PIN(17, A, 7),
    __STM32_PIN(18, B, 0),
    __STM32_PIN(19, B, 1),
    __STM32_PIN(20, B, 2),
    __STM32_PIN(21, B, 10),
    __STM32_PIN(22, B, 11),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(25, B, 12),
    __STM32_PIN(26, B, 13),
    __STM32_PIN(27, B, 14),
    __STM32_PIN(28, B, 15),
    __STM32_PIN(29, A, 8),
    __STM32_PIN(30, A, 9),
    __STM32_PIN(31, A, 10),
    __STM32_PIN(32, A, 11),
    __STM32_PIN(33, A, 12),
    __STM32_PIN(34, A, 13),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(37, A, 14),
    __STM32_PIN(38, A, 15),
    __STM32_PIN(39, B, 3),
    __STM32_PIN(40, B, 4),
    __STM32_PIN(41, B, 5),
    __STM32_PIN(42, B, 6),
    __STM32_PIN(43, B, 7),
    __STM32_PIN_DEFAULT,
    __STM32_PIN(45, B, 8),
    __STM32_PIN(46, B, 9),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,

#endif
#if (STM32F10X_PIN_NUMBERS == 64)
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(2, C, 13),
    __STM32_PIN(3, C, 14),
    __STM32_PIN(4, C, 15),
    __STM32_PIN(5, D, 0),
    __STM32_PIN(6, D, 1),
    __STM32_PIN_DEFAULT,
    __STM32_PIN(8, C, 0),
    __STM32_PIN(9, C, 1),
    __STM32_PIN(10, C, 2),
    __STM32_PIN(11, C, 3),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(14, A, 0),
    __STM32_PIN(15, A, 1),
    __STM32_PIN(16, A, 2),
    __STM32_PIN(17, A, 3),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(20, A, 4),
    __STM32_PIN(21, A, 5),
    __STM32_PIN(22, A, 6),
    __STM32_PIN(23, A, 7),
    __STM32_PIN(24, C, 4),
    __STM32_PIN(25, C, 5),
    __STM32_PIN(26, B, 0),
    __STM32_PIN(27, B, 1),
    __STM32_PIN(28, B, 2),
    __STM32_PIN(29, B, 10),
    __STM32_PIN(30, B, 11),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(33, B, 12),
    __STM32_PIN(34, B, 13),
    __STM32_PIN(35, B, 14),
    __STM32_PIN(36, B, 15),
    __STM32_PIN(37, C, 6),
    __STM32_PIN(38, C, 7),
    __STM32_PIN(39, C, 8),
    __STM32_PIN(40, C, 9),
    __STM32_PIN(41, A, 8),
    __STM32_PIN(42, A, 9),
    __STM32_PIN(43, A, 10),
    __STM32_PIN(44, A, 11),
    __STM32_PIN(45, A, 12),
    __STM32_PIN(46, A, 13),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(49, A, 14),
    __STM32_PIN(50, A, 15),
    __STM32_PIN(51, C, 10),
    __STM32_PIN(52, C, 11),
    __STM32_PIN(53, C, 12),
    __STM32_PIN(54, D, 2),
    __STM32_PIN(55, B, 3),
    __STM32_PIN(56, B, 4),
    __STM32_PIN(57, B, 5),
    __STM32_PIN(58, B, 6),
    __STM32_PIN(59, B, 7),
    __STM32_PIN_DEFAULT,
    __STM32_PIN(61, B, 8),
    __STM32_PIN(62, B, 9),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
#endif
#if (STM32F10X_PIN_NUMBERS == 100)
    __STM32_PIN_DEFAULT,
    __STM32_PIN(1, E, 2),
    __STM32_PIN(2, E, 3),
    __STM32_PIN(3, E, 4),
    __STM32_PIN(4, E, 5),
    __STM32_PIN(5, E, 6),
    __STM32_PIN_DEFAULT,
    __STM32_PIN(7, C, 13),
    __STM32_PIN(8, C, 14),
    __STM32_PIN(9, C, 15),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(15, C, 0),
    __STM32_PIN(16, C, 1),
    __STM32_PIN(17, C, 2),
    __STM32_PIN(18, C, 3),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(23, A, 0),
    __STM32_PIN(24, A, 1),
    __STM32_PIN(25, A, 2),
    __STM32_PIN(26, A, 3),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(29, A, 4),
    __STM32_PIN(30, A, 5),
    __STM32_PIN(31, A, 6),
    __STM32_PIN(32, A, 7),
    __STM32_PIN(33, C, 4),
    __STM32_PIN(34, C, 5),
    __STM32_PIN(35, B, 0),
    __STM32_PIN(36, B, 1),
    __STM32_PIN(37, B, 2),
    __STM32_PIN(38, E, 7),
    __STM32_PIN(39, E, 8),
    __STM32_PIN(40, E, 9),
    __STM32_PIN(41, E, 10),
    __STM32_PIN(42, E, 11),
    __STM32_PIN(43, E, 12),
    __STM32_PIN(44, E, 13),
    __STM32_PIN(45, E, 14),
    __STM32_PIN(46, E, 15),
    __STM32_PIN(47, B, 10),
    __STM32_PIN(48, B, 11),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(51, B, 12),
    __STM32_PIN(52, B, 13),
    __STM32_PIN(53, B, 14),
    __STM32_PIN(54, B, 15),
    __STM32_PIN(55, D, 8),
    __STM32_PIN(56, D, 9),
    __STM32_PIN(57, D, 10),
    __STM32_PIN(58, D, 11),
    __STM32_PIN(59, D, 12),
    __STM32_PIN(60, D, 13),
    __STM32_PIN(61, D, 14),
    __STM32_PIN(62, D, 15),
    __STM32_PIN(63, C, 6),
    __STM32_PIN(64, C, 7),
    __STM32_PIN(65, C, 8),
    __STM32_PIN(66, C, 9),
    __STM32_PIN(67, A, 8),
    __STM32_PIN(68, A, 9),
    __STM32_PIN(69, A, 10),
    __STM32_PIN(70, A, 11),
    __STM32_PIN(71, A, 12),
    __STM32_PIN(72, A, 13),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(76, A, 14),
    __STM32_PIN(77, A, 15),
    __STM32_PIN(78, C, 10),
    __STM32_PIN(79, C, 11),
    __STM32_PIN(80, C, 12),
    __STM32_PIN(81, D, 0),
    __STM32_PIN(82, D, 1),
    __STM32_PIN(83, D, 2),
    __STM32_PIN(84, D, 3),
    __STM32_PIN(85, D, 4),
    __STM32_PIN(86, D, 5),
    __STM32_PIN(87, D, 6),
    __STM32_PIN(88, D, 7),
    __STM32_PIN(89, B, 3),
    __STM32_PIN(90, B, 4),
    __STM32_PIN(91, B, 5),
    __STM32_PIN(92, B, 6),
    __STM32_PIN(93, B, 7),
    __STM32_PIN_DEFAULT,
    __STM32_PIN(95, B, 8),
    __STM32_PIN(96, B, 9),
    __STM32_PIN(97, E, 0),
    __STM32_PIN(98, E, 1),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
#endif
#if (STM32F10X_PIN_NUMBERS == 144)
    __STM32_PIN_DEFAULT,
    __STM32_PIN(1, E, 2),
    __STM32_PIN(2, E, 3),
    __STM32_PIN(3, E, 4),
    __STM32_PIN(4, E, 5),
    __STM32_PIN(5, E, 6),
    __STM32_PIN_DEFAULT,
    __STM32_PIN(7, C, 13),
    __STM32_PIN(8, C, 14),
    __STM32_PIN(9, C, 15),

    __STM32_PIN(10, F, 0),
    __STM32_PIN(11, F, 1),
    __STM32_PIN(12, F, 2),
    __STM32_PIN(13, F, 3),
    __STM32_PIN(14, F, 4),
    __STM32_PIN(15, F, 5),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(18, F, 6),
    __STM32_PIN(19, F, 7),
    __STM32_PIN(20, F, 8),
    __STM32_PIN(21, F, 9),
    __STM32_PIN(22, F, 10),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(26, C, 0),
    __STM32_PIN(27, C, 1),
    __STM32_PIN(28, C, 2),
    __STM32_PIN(29, C, 3),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(34, A, 0),
    __STM32_PIN(35, A, 1),
    __STM32_PIN(36, A, 2),
    __STM32_PIN(37, A, 3),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(40, A, 4),
    __STM32_PIN(41, A, 5),
    __STM32_PIN(42, A, 6),
    __STM32_PIN(43, A, 7),
    __STM32_PIN(44, C, 4),
    __STM32_PIN(45, C, 5),
    __STM32_PIN(46, B, 0),
    __STM32_PIN(47, B, 1),
    __STM32_PIN(48, B, 2),
    __STM32_PIN(49, F, 11),
    __STM32_PIN(50, F, 12),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(53, F, 13),
    __STM32_PIN(54, F, 14),
    __STM32_PIN(55, F, 15),
    __STM32_PIN(56, G, 0),
    __STM32_PIN(57, G, 1),
    __STM32_PIN(58, E, 7),
    __STM32_PIN(59, E, 8),
    __STM32_PIN(60, E, 9),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(63, E, 10),
    __STM32_PIN(64, E, 11),
    __STM32_PIN(65, E, 12),
    __STM32_PIN(66, E, 13),
    __STM32_PIN(67, E, 14),
    __STM32_PIN(68, E, 15),
    __STM32_PIN(69, B, 10),
    __STM32_PIN(70, B, 11),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(73, B, 12),
    __STM32_PIN(74, B, 13),
    __STM32_PIN(75, B, 14),
    __STM32_PIN(76, B, 15),
    __STM32_PIN(77, D, 8),
    __STM32_PIN(78, D, 9),
    __STM32_PIN(79, D, 10),
    __STM32_PIN(80, D, 11),
    __STM32_PIN(81, D, 12),
    __STM32_PIN(82, D, 13),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(85, D, 14),
    __STM32_PIN(86, D, 15),
    __STM32_PIN(87, G, 2),
    __STM32_PIN(88, G, 3),
    __STM32_PIN(89, G, 4),
    __STM32_PIN(90, G, 5),
    __STM32_PIN(91, G, 6),
    __STM32_PIN(92, G, 7),
    __STM32_PIN(93, G, 8),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(96, C, 6),
    __STM32_PIN(97, C, 7),
    __STM32_PIN(98, C, 8),
    __STM32_PIN(99, C, 9),
    __STM32_PIN(100, A, 8),
    __STM32_PIN(101, A, 9),
    __STM32_PIN(102, A, 10),
    __STM32_PIN(103, A, 11),
    __STM32_PIN(104, A, 12),
    __STM32_PIN(105, A, 13),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(109, A, 14),
    __STM32_PIN(110, A, 15),
    __STM32_PIN(111, C, 10),
    __STM32_PIN(112, C, 11),
    __STM32_PIN(113, C, 12),
    __STM32_PIN(114, D, 0),
    __STM32_PIN(115, D, 1),
    __STM32_PIN(116, D, 2),
    __STM32_PIN(117, D, 3),
    __STM32_PIN(118, D, 4),
    __STM32_PIN(119, D, 5),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(122, D, 6),
    __STM32_PIN(123, D, 7),
    __STM32_PIN(124, G, 9),
    __STM32_PIN(125, G, 10),
    __STM32_PIN(126, G, 11),
    __STM32_PIN(127, G, 12),
    __STM32_PIN(128, G, 13),
    __STM32_PIN(129, G, 14),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
    __STM32_PIN(132, G, 15),
    __STM32_PIN(133, B, 3),
    __STM32_PIN(134, B, 4),
    __STM32_PIN(135, B, 5),
    __STM32_PIN(136, B, 6),
    __STM32_PIN(137, B, 7),
    __STM32_PIN_DEFAULT,
    __STM32_PIN(139, B, 8),
    __STM32_PIN(140, B, 9),
    __STM32_PIN(141, E, 0),
    __STM32_PIN(142, E, 1),
    __STM32_PIN_DEFAULT,
    __STM32_PIN_DEFAULT,
#endif
};
```

以STM32为例，`__STM32_PIN(142, E, 1)`表示142为RTT引脚编号，E为端口号（GPIOE），1代表物理引脚号

也就是说GPIOE1对应的RTT引脚编号为142

实际使用中，如果在RTT Studio或ENV工具中设置好了对应的芯片型号，RTT会自动根据GPIO生成`GET_PIN()`，只要调用这个宏就可以直接得到引脚了

## 引脚设置

1. 引脚模式设置

使用rt_pin_mode()来设置引脚输入/输出模式

```c
void rt_pin_mode(rt_base_t pin, rt_base_t mode)
{
    RT_ASSERT(_hw_pin.ops != RT_NULL);
    _hw_pin.ops->pin_mode(&_hw_pin.parent, pin, mode);
}

static struct rt_device_pin _hw_pin;//PIN设备对象
struct rt_device_pin
{
    struct rt_device parent;//继承自设备对象
    const struct rt_pin_ops *ops;
};
struct rt_pin_ops//相关属性
{
    void (*pin_mode)(struct rt_device *device, rt_base_t pin, rt_base_t mode);
    void (*pin_write)(struct rt_device *device, rt_base_t pin, rt_base_t value);
    int (*pin_read)(struct rt_device *device, rt_base_t pin);

    /* TODO: add GPIO interrupt */
    rt_err_t (*pin_attach_irq)(struct rt_device *device, rt_int32_t pin,
                      rt_uint32_t mode, void (*hdr)(void *args), void *args);
    rt_err_t (*pin_dettach_irq)(struct rt_device *device, rt_int32_t pin);
    rt_err_t (*pin_irq_enable)(struct rt_device *device, rt_base_t pin, rt_uint32_t enabled);
};
```

stm32f103默认可以设置的工作模式如下，其他MCU/SoC的实际支持模式需参考相关驱动程序的实现

```c
#define PIN_MODE_OUTPUT         0x00//普通输出
#define PIN_MODE_INPUT          0x01//普通输入
#define PIN_MODE_INPUT_PULLUP   0x02//内部上拉输入
#define PIN_MODE_INPUT_PULLDOWN 0x03//内部下拉输入
#define PIN_MODE_OUTPUT_OD      0x04//开漏输出
```

2. 设置引脚中断模式与绑定/脱离引脚回调函数

使用rt_pin_attach_irq()将目标引脚配置为某种中断触发模式并绑定一个中断回调函数到对应引脚，当中断发生时会执行回调函数

```c
rt_err_t rt_pin_attach_irq(rt_int32_t pin,//引脚编号
                           rt_uint32_t mode,//中断触发模式
                           void (*hdr)(void *args),//中断回调函数，用户需自行定义
                           void  *args)//中断回调函数的参数，不需要时应设置为RT_NULL
{
    RT_ASSERT(_hw_pin.ops != RT_NULL);
    if(_hw_pin.ops->pin_attach_irq)
    {
        return _hw_pin.ops->pin_attach_irq(&_hw_pin.parent, pin, mode, hdr, args);
    }
    return RT_ENOSYS;
}
```

可设置的中断触发模式如下

```c
#define PIN_IRQ_MODE_RISING             0x00//上升沿触发
#define PIN_IRQ_MODE_FALLING            0x01//下降沿触发
#define PIN_IRQ_MODE_RISING_FALLING     0x02//边沿触发
#define PIN_IRQ_MODE_HIGH_LEVEL         0x03//高电平触发
#define PIN_IRQ_MODE_LOW_LEVEL          0x04//低电平触发
```

3. 脱离引脚中断回调函数

使用rt_pin_dettach_irq()脱离某个引脚的中断回调函数

```c
rt_err_t rt_pin_dettach_irq(rt_int32_t pin)
{
    RT_ASSERT(_hw_pin.ops != RT_NULL);
    if(_hw_pin.ops->pin_dettach_irq)
    {
        return _hw_pin.ops->pin_dettach_irq(&_hw_pin.parent, pin);
    }
    return RT_ENOSYS;
}
```

注意：**引脚脱离中断回调函数后，中断并未关闭，还可以绑定中断回调函数或绑定其他回调函数**

## 引脚使用

1. 引脚电平输出设置

使用rt_pin_write()设置当前引脚输出的电平

```c
void rt_pin_write(rt_base_t pin, rt_base_t value)
{
    RT_ASSERT(_hw_pin.ops != RT_NULL);
    _hw_pin.ops->pin_write(&_hw_pin.parent, pin, value);
}
```

参数如下

```c
#define PIN_LOW                 0x00//输出低电平
#define PIN_HIGH                0x01//输出高电平
```

2. 引脚电平读取设置

使用rt_pin_read()读取当前引脚模式

```c
int  rt_pin_read(rt_base_t pin)
{
    RT_ASSERT(_hw_pin.ops != RT_NULL);
    return _hw_pin.ops->pin_read(&_hw_pin.parent, pin);
}
```

一般使用形式为status=rt_pin_read(GPIOx_Pinx);

将读取结果保存在变量status中

3. 使能引脚中断

使用以下API使能引脚中断

```c
#define PIN_IRQ_DISABLE                 0x00
#define PIN_IRQ_ENABLE                  0x01

rt_err_t rt_pin_irq_enable(rt_base_t pin, rt_uint32_t enabled)
{
    RT_ASSERT(_hw_pin.ops != RT_NULL);
    if(_hw_pin.ops->pin_irq_enable)
    {
        return _hw_pin.ops->pin_irq_enable(&_hw_pin.parent, pin, enabled);
    }
    return RT_ENOSYS;
}
```

引脚中断设置、绑定并开启后才能启用

==上述所有API与使用的设备驱动相关，实际使用时需要查阅驱动程序==