# SPI设备

RTT的SPI设备驱动遵循SPI协议进行编写，一般为四线SPI（MOSI、MISO、CS、SCLK）或四线DSPI模式或六线QSPI模式

SPI工作在全双工模式，MISO和MOSI同时发送数据，一般在设备内部采用移位寄存器的方式实现；DSPI工作在半双工模式，MOSI和MISO换成SIO0、SIO1，在一个时钟周期内传输两个比特数据；QSPI也工作在半双工模式，设置SIO0、SIO1、SIO2、SIO3四条数据信号线和SCLK、CS两条控制信号线，在同一时钟周期内能传输4个比特数据

在相同时钟下，线数越多传输速率越高

## SPI设备挂载和配置

使用SPI驱动程序将SPI总线注册，SPI设备需要挂载到已经注册好的SPI总线上，使用以下API将一个SPI设备挂载到指定的总线

```c
rt_err_t rt_spi_bus_attach_device(struct rt_spi_device *device,//SPI设备句柄
                                  const char *name,//设备名
                                  const char *bus_name,//总线名
                                  void *user_data)//用户数据指针
```

user_data会被自动保存到对应SPI设备的设备控制块中

**SPI总线命名为spix，SPI设备命名为spixy，user_data一般设为SPI设备的CS引脚指针**，比如spi10表示挂载到spi1总线上的0号设备

针对不同设备可能API有所不同，如使用stm32对应的bsp

`rt_hw_spi_device_attach(const char *bus_name, const char *device_name, GPIO_TypeDef* cs_gpiox, uint16_t cs_gpio_pin)`

使用例如下：将SPI FLASH作为0号设备挂载到SPI1总线

```c
static int rt_hw_spi_flash_init(void)
{
    __HAL_RCC_GPIOB_CLK_ENABLE();
    rt_hw_spi_device_attach("spi1", "spi10", GPIOB, GPIO_PIN_14);

    if (RT_NULL == rt_sfud_flash_probe("W25Q128", "spi10"))
        return -RT_ERROR;
    return RT_EOK;
}
```

使用以下API配置SPI设备的参数

```c
rt_err_t rt_spi_configure(struct rt_spi_device *device,//SPI设备句柄
                          struct rt_spi_configuration *cfg)//SPI配置参数指针

//配置结构体如下
struct rt_spi_configuration
{
    rt_uint8_t mode; /* 模式：从下面的宏定义中选择，可以使用位与连接 */
    rt_uint8_t data_width; /* 数据宽度：可取8位、16位、32位 */
    rt_uint16_t reserved; /* 保留位 */
    rt_uint32_t max_hz; /* 最大频率：单位Hz */
};

//可使用【模式】设置如下
/* 设置数据传输顺序是MSB位在前还是LSB位在前 */
#define RT_SPI_LSB      (0<<2)                        /* bit[2]: 0-LSB */
#define RT_SPI_MSB      (1<<2)                        /* bit[2]: 1-MSB */

/* 设置SPI的主从模式 */
#define RT_SPI_MASTER   (0<<3)                        /* SPI主设备模式 */
#define RT_SPI_SLAVE    (1<<3)                        /* SPI从设备模式 */

/* 设置时钟极性和时钟相位 */
#define RT_SPI_MODE_0   (0 | 0)                       /* CPOL = 0, CPHA = 0 */
#define RT_SPI_MODE_1   (0 | RT_SPI_CPHA)             /* CPOL = 0, CPHA = 1 */
#define RT_SPI_MODE_2   (RT_SPI_CPOL | 0)             /* CPOL = 1, CPHA = 0 */
#define RT_SPI_MODE_3   (RT_SPI_CPOL | RT_SPI_CPHA)   /* CPOL = 1, CPHA = 1 */

#define RT_SPI_CS_HIGH  (1<<4)                        /* 片选信号高电平有效 */
#define RT_SPI_NO_CS    (1<<5)                        /* 无片选信号 */
#define RT_SPI_3WIRE    (1<<6)                        /* 3线SPI模式 */
#define RT_SPI_READY    (1<<7)                        /* 从设备发送低电平信号表示暂停 */
```

## QSPI

QSPI协议一般用于片外SPI FLASH、SRAM等的操作

使用以下API配置QSPI设备的传输参数

```c
rt_err_t rt_qspi_configure(struct rt_qspi_device *device,//QSPI设备句柄
                           struct rt_qspi_configuration *cfg);//QSPI配置参数指针

//QSPI参数配置结构体如下
struct rt_qspi_configuration
{
    struct rt_spi_configuration parent; /* 继承自 SPI 设备配置参数 */
    rt_uint32_t medium_size; /* 介质大小：外设存储器大小 */
    rt_uint8_t ddr_mode; /* 双倍速率模式 */
    rt_uint8_t qspi_dl_width ; /* QSPI总线位宽，单线模式 1 位、双线模式 2 位，4 线模式 4 位 */
};
```

## 访问SPI设备

==注意：SPI数据传输相关接口会调用rt_mutex_take()（使用了互斥量），所以不能在中断服务程序中调用SPI传输相关API，否则会导致assertion报错==

### 查找SPI设备

使用以下API通过设备名获取SPI设备句柄

```c
rt_device_t rt_device_find(const char* name);
```

使用例如下：

```c
#define W25Q_SPI_DEVICE_NAME     "qspi10"   /* SPI 设备名称 */
struct rt_spi_device *spi_dev_w25q;     /* SPI 设备句柄 */

/* 查找 spi 设备获取设备句柄 */
spi_dev_w25q = (struct rt_spi_device *)rt_device_find(W25Q_SPI_DEVICE_NAME);
```

### 自定义传输数据

通过以下API传输SPI数据

```c
struct rt_spi_message *rt_spi_transfer_message(struct rt_spi_device *device,//设备句柄
                                               struct rt_spi_message *message)；//SPI消息结构体指针
    
struct rt_spi_message
{
    const void *send_buf;           /* 发送缓冲区指针 */
    void *recv_buf;                 /* 接收缓冲区指针 */
    rt_size_t length;               /* 发送 / 接收 数据字节数，单位 word */
    struct rt_spi_message *next;    /* 指向继续发送的下一条消息的指针（消息链表的指针域） */
    unsigned cs_take    : 1;        /* 片选选中 */
    unsigned cs_release : 1;        /* 释放片选 */
};
//当send_buf=RT_NULL时，表示本次传输位只接收状态，不发送数据
//当recv_buf=RT_NULL时，表示本次传输位只发送状态，会将收到的数据直接丢弃
//如果只发送一条消息，应将next=NULL
//cs_take为1时表示传输数据前，设置对应的CS为有效状态；cs_release为1时表示传输数据结束后，释放对应的CS
```

注意：**当send_buf或recv_buf不为空时，两者的可用空间必须大于等于length**

一般传输第一条消息的cs_take和最后一条消息的cs_release要置1，中间的消息的cs_take和cs_release都置0

使用例如下：

```c
/* 查找 spi 设备获取设备句柄 */
spi_dev_w25q = (struct rt_spi_device *)rt_device_find(W25Q_SPI_DEVICE_NAME);
struct rt_spi_message msg1, msg2;//实例化两个消息

msg1.send_buf   = &w25x_read_id;
msg1.recv_buf   = RT_NULL;
msg1.length     = 1;
msg1.cs_take    = 1;//第一个消息置1
msg1.cs_release = 0;
msg1.next       = &msg2;//连接到msg2

msg2.send_buf   = RT_NULL;
msg2.recv_buf   = id;
msg2.length     = 5;
msg2.cs_take    = 0;
msg2.cs_release = 1;//第二个消息置0
msg2.next       = RT_NULL;

rt_spi_transfer_message(spi_dev_w25q, &msg1);//只调用msg1，API会自动遍历SPI消息链表
```

### 单次传输数据

```c
rt_size_t rt_spi_transfer(struct rt_spi_device *device,//设备句柄
                          const void *send_buf,//发送缓冲区指针
                          void *recv_buf,//接收缓冲区指针
                          rt_size_t length);//发送、接收数据字节数
```

此函数等同于调用上面的spi_transfer_message()传输一条消息，开始发送数据时片选选中，函数返回时释放片选

### 单次发送数据

使用以下API发送一次数据，忽略接收到的数据

```c
rt_size_t rt_spi_send(struct rt_spi_device *device,//SPI设备句柄
                      const void *send_buf,//发送数据缓冲区指针
                      rt_size_t length)//发送数据字节数
```

此函数等同于调用上面的spi_transfer_message()传输一条消息，开始发送数据时片选选中，函数返回时释放片选（都是套皮封装）

### 单次接收数据

```c
rt_size_t rt_spi_recv(struct rt_spi_device *device,//SPI设备句柄
                      void *recv_buf,//接收数据缓冲区指针
                      rt_size_t length);//接收数据字节数
```

此函数是对rt_spi_transfer()的封装，在接收数据时主设备会发送数据0xFF

### 连续两次发送数据

使用以下API先后连续发送 2 个缓冲区的数据，**中间片选不释放**

```c
rt_err_t rt_spi_send_then_send(struct rt_spi_device *device,//SPI设备句柄
                               const void *send_buf1,//发送数据1缓冲区指针
                               rt_size_t send_length1,//发送数据1字节数
                               const void *send_buf2,//发送数据2缓冲区指针
                               rt_size_t send_length2);//发送数据2字节数
```

此函数可以连续发送2个缓冲区的数据，忽略接收到的数据，发送send_buf1时片选选中，发送完send_buf2后释放片选

用处（摘自RTT官方教程）

> 本函数适合向 SPI 设备中写入一块数据，第一次先发送命令和地址等数据，第二次再发送指定长度的数据。之所以分两次发送而不是合并成一个数据块发送，或调用两次 `rt_spi_send()`，是因为在大部分的数据写操作中，都需要先发命令和地址，长度一般只有几个字节。如果与后面的数据合并在一起发送，将需要进行内存空间申请和大量的数据搬运。而如果调用两次 `rt_spi_send()`，那么在发送完命令和地址后，片选会被释放，大部分 SPI 设备都依靠设置片选一次有效为命令的起始，所以片选在发送完命令或地址数据后被释放，则此次操作被丢弃

和上面rt_spi_transfer_message()的使用例不能说是比较像，只能说是完全一致（但是更方便）

### 先发送后接收数据

使用以下API向从设备先发送数据，然后接收从设备发送的数据，**中间片选不释放**

```c
rt_err_t rt_spi_send_then_recv(struct rt_spi_device *device,//SPI设备句柄
                               const void *send_buf,//发送数据缓冲区指针
                               rt_size_t send_length,//发送数据字节数
                               void *recv_buf,//接收数据缓冲区指针
                               rt_size_t recv_length);//接收数据字节数
```

此函数发送第一条数据send_buf时开始片选，此时忽略接收到的数据；然后发送第二条数据，此时主设备会发送数据0XFF，接收到的数据保存在recv_buf里，函数返回时释放片选

> 本函数适合从 SPI 从设备中读取一块数据，第一次会先发送一些命令和地址数据，然后再接收指定长度的数据

等同于调用两次rt_spi_transfer_message()，一次发送一次接收，中间不释放片选

## 访问QSPI设备

1. 传输数据API

```c
rt_size_t rt_qspi_transfer_message(struct rt_qspi_device *device,//QSPI设备句柄
                                   struct rt_qspi_message *message);//消息指针
```

rt_qspi_message结构体设置消息内容，原型如下

```c
struct rt_qspi_message
{
    struct rt_spi_message parent;   /* 继承自struct rt_spi_message */
    struct
    {
        rt_uint8_t content;         /* 指令内容 */
        rt_uint8_t qspi_lines;      /* 指令模式，单线模式 1 位、双线模式 2 位，4 线模式 4 位 */
    } instruction;                  /* 指令阶段 */

     struct
    {
        rt_uint32_t content;        /* 地址/交替字节 内容 */
        rt_uint8_t size;            /* 地址/交替字节 长度 */
        rt_uint8_t qspi_lines;      /* 地址/交替字节 模式，单线模式 1 位、双线模式 2 位，4 线模式 4 位 */
    } address, alternate_bytes;     /* 地址/交替字节 阶段 */

    rt_uint32_t dummy_cycles;       /* 空指令周期阶段 */
    rt_uint8_t qspi_data_lines;     /*  QSPI 总线位宽 */
};
```

2. 接收数据API

```c
rt_err_t rt_qspi_send_then_recv(struct rt_qspi_device *device,//QSPI设备句柄
                                const void *send_buf,//发送数据缓存区指针
                                rt_size_t send_length,//发送数据字节数
                                void *recv_buf,//接收数据缓存区指针
                                rt_size_t recv_length);//接收数据字节数
```

3. 发送数据API

```c
rt_err_t rt_qspi_send(struct rt_qspi_device *device,//QSPI设备句柄
                      const void *send_buf,//发送数据缓存区指针
                      rt_size_t length)//发送数据字节数
```

QSPI一般使用接收数据和发送数据API来控制片外FLASH/SRAM

## 特殊使用场景

在特殊情况下，某设备需要独占总线，但独占期间数据传输间断，此时**必须使用rt_spi_transfer_message()函数接口**且**此函数每个待传输消息的片选控制域 cs_take 和 cs_release 都要设置为 0 值**，因为片选信号已经使用其他API控制，无需在数据传输时控制

使用以下API实现CS长时间获取和释放

### 获取与释放总线

```c
rt_err_t rt_spi_take_bus(struct rt_spi_device *device);//获取总线
rt_err_t rt_spi_release_bus(struct rt_spi_device *device);//释放总线
```

多线程情况下，SPI总线资源可能成为临界区资源，悲不同线程使用，为了防止SPI总线上数据丢失，必须在传输前获取总线使用权，使用成功才能够开启片选、传输数据；总线使用完毕后必须释放，否则其他从设备无法使用SPI总线传输数据

### 片选信号控制

```c
rt_err_t rt_spi_take(struct rt_spi_device *device);//选中片选
rt_err_t rt_spi_release(struct rt_spi_device *device);//释放片选
```

从设备获取总线的使用权后，需要设置自己对应的片选信号为有效；从设备数据传输完成后，必须释放片选

### 发送消息

使用rt_spi_transfer_message()函数时，所有消息以单向链表的形式连接起来，挂载等待队列上准备发送

使用以下API在消息链表中增加一条新的待传输消息

```c
void rt_spi_message_append(struct rt_spi_message *list,//待传输的消息链表节点
                           struct rt_spi_message *message);//新增消息指针
```

## SPI设备使用示例

```c
#include <rtthread.h>
#include <rtdevice.h>//需要引入该头文件才能使用SPI设备

//定义设备名
#define W25Q_SPI_DEVICE_NAME "qspi10"

static void spi_w25q_sample(int argc, char *argv[])//示例线程-导出为shell指令
{
    struct rt_spi_device *spi_dev_w25q;
    char name[RT_NAME_MAX];
    rt_uint8_t w25x_read_id = 0x90;
    rt_uint8_t id[5] = {0};

    if (argc == 2)
        rt_strncpy(name, argv[1], RT_NAME_MAX);
    else
        rt_strncpy(name, W25Q_SPI_DEVICE_NAME, RT_NAME_MAX);

    /* 查找 spi 设备获取设备句柄 */
    spi_dev_w25q = (struct rt_spi_device *)rt_device_find(name);
    if (!spi_dev_w25q)
        rt_kprintf("spi sample run failed! can't find %s device!\n", name);//报错
    else
    {
        /* 方式1：使用 rt_spi_send_then_recv()发送命令读取ID */
        rt_spi_send_then_recv(spi_dev_w25q, &w25x_read_id, 1, id, 5);
        rt_kprintf("use rt_spi_send_then_recv() read w25q ID is:%x%x\n", id[3], id[4]);

        /* 方式2：使用 rt_spi_transfer_message()发送命令读取ID */
        struct rt_spi_message msg1, msg2;

        msg1.send_buf   = &w25x_read_id;
        msg1.recv_buf   = RT_NULL;
        msg1.length     = 1;
        msg1.cs_take    = 1;
        msg1.cs_release = 0;
        msg1.next       = &msg2;

        msg2.send_buf   = RT_NULL;
        msg2.recv_buf   = id;
        msg2.length     = 5;
        msg2.cs_take    = 0;
        msg2.cs_release = 1;
        msg2.next       = RT_NULL;

        rt_spi_transfer_message(spi_dev_w25q, &msg1);
        rt_kprintf("use rt_spi_transfer_message() read w25q ID is:%x%x\n", id[3], id[4]);
    }
}
```

# IIC设备

内部集成电路总线IIC是半双工双向二线制同步串行总线

物理层需要两条数据线：**双向数据线SDA**和**双向时钟线SCL**，IIC使用单线（SDA）进行数据收发

IIC允许多个主设备存在，但**同一时刻只允许有一个主设备**，每个连接到总线上的器件都被分配唯一的地址，主设备启动数据传输并产生时钟信号，从设备被主设备寻址

一般IIC的两条信号线需要上拉到VDD，当**总线空闲时，保证SDA和SCL都处于高电平状态**

## IIC时序

IIC总线的数据传输格式如下：

![image-20210222153308187](RT-Thread使用_通用总线.assets/image-20210222153308187.png)

1. 开始条件：由主机发出的**低电平**信号，表示传输即将开始

2. 从设备地址与读写位：主机发送的第一个字节，**其中高7位表示从机地址，最低位标识R/W读写位**，读写位中**1表示读取，0表示写入**；特别地，可以选择使用10位地址模式，此模式下第一个字节的前7位是11110xxF的组合，最后xx表示10位地址的两个最高位，F表示R/W读写位，表示原则与7位地址模式相同，第二个字节为10位从机地址的剩下8位。图示如下

![image-20210222153819159](RT-Thread使用_通用总线.assets/image-20210222153819159.png)

3. 应答信号ACK：每传输完成**一个字节**的数据，接收方（从设备或主设备）需要回复一个ACK应答信号：==写数据时由从机发送，读数据时由主机发送==。当主机读到最后一个字节的数据时，可以选择发送NACK，然后再发送停止条件
4. 停止条件：**SDA=0，SCL上升沿且保持高电平，再将SDA拉高，表示传输结束**

5. 数据：每个数据规定为8位（1字节），数据字节数无限制
6. 重复开始条件：在一次通信中，主机如果需要和不同的从机传输数据或需要切换读写操作时，可以再发送1个开始条件

## 在RTT中使用IIC设备

**RTT将IIC主机虚拟为IIC总线设备，IIC从机通过IIC设备接口和IIC总线设备（主机）通讯**

以下为API

### 查找IIC设备

```c
rt_device_t rt_device_find(const char* name);
```

使用这个API根据总线设备名称获取设备句柄来操作IIC总线设备

使用例如下

```c
#define AHT10_I2C_BUS_NAME "i2c1" /* I2C总线设备名称 */
struct rt_i2c_bus_device *i2c_bus; /* I2C总线设备句柄 */

/* 查找I2C总线设备，获取I2C总线设备句柄 */
i2c_bus = (struct rt_i2c_bus_device *)rt_device_find(name);
```

一般IIC设备直接命名为iicx或i2cx，x代表数字

### 传输数据

注意：**该API会调用rt_mutex_take()，不能在中断服务函数中调用，否则会导致assertion报错**

```c
rt_size_t rt_i2c_transfer(struct rt_i2c_bus_device *bus,//总线设备句柄
                          struct rt_i2c_msg msgs[],//待传输消息数组指针
                          rt_uint32_t num);//消息数组的元素个数

//消息数据结构原型
struct rt_i2c_msg
{
    rt_uint16_t addr;    /* 从机地址，支持7位和10位二进制地址 */
    rt_uint16_t flags;   /* 读、写标志等 */
    rt_uint16_t len;     /* 读写数据字节数 */
    rt_uint8_t  *buf;    /* 读写数据缓冲区指针　*/
}

//flag可用取值，实际使用中可以使用位与|进行组合
#define RT_I2C_WR              0x0000        /* 写标志 */
#define RT_I2C_RD              (1u << 0)     /* 读标志 */
#define RT_I2C_ADDR_10BIT      (1u << 2)     /* 10 位地址模式 */
#define RT_I2C_NO_START        (1u << 4)     /* 无开始条件 */
#define RT_I2C_IGNORE_NACK     (1u << 5)     /* 忽视 NACK */
#define RT_I2C_NO_READ_ACK     (1u << 6)     /* 读的时候不发送 ACK */
```

使用以上API进行IIC数据传输

IIC数据以消息为单位，参数msgs应为指向待传输数据的消息数组`struct rt_i2c_msg *msg`