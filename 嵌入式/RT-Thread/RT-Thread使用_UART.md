# UART设备简介

UART：通用异步收发传输器，可以将传输数据的每个字符一位接一位地顺序传输

## 物理层

需要两个传输线，一根Rx接收数据，一根Tx发送数据

需要设置**波特率**、起始位、数据为、停止位、奇偶效验位，对于两个通过UART连接的端口，这些参数必须匹配，否则会造成传输出错

波特率：串口通信速率，用单位时间内传输的二进制代码的有效位表示，理论上可以是任意值，但常用4800、9600、38400、115200等特定值，数值越大数据传输越快。单位位每秒比特数bit/s(bps)

**UART的起始位规定为逻辑电平0，停止位规定为逻辑电平1**

数据位：表示传输几个比特位数据，可以设置为5、6、7、8、9，通常使用8bit，因为一个ASCII字符为8位

奇偶效验位：用于奇偶效验，不必须，使用时校验逻辑电平1的位数为偶数或奇数

## RTT中使用UART

RTT提供了数个API供用户访问串口硬件，直接使用IO设备模型中的API配合串口设备名称即可使用UART

### 查找设备

使用rt_device_find()查找设备

```c
rt_device_t rt_device_find(const char *name)
{
    struct rt_object *object;
    struct rt_list_node *node;
    struct rt_object_information *information;

    /* enter critical */
    if (rt_thread_self() != RT_NULL)
        rt_enter_critical();

    /* try to find device object */
    information = rt_object_get_information(RT_Object_Class_Device);
    RT_ASSERT(information != RT_NULL);
    for (node  = information->object_list.next;
         node != &(information->object_list);
         node  = node->next)
    {
        object = rt_list_entry(node, struct rt_object, list);
        if (rt_strncmp(object->name, name, RT_NAME_MAX) == 0)
        {
            /* leave critical */
            if (rt_thread_self() != RT_NULL)
                rt_exit_critical();
            return (rt_device_t)object;
        }
    }
    /* leave critical */
    if (rt_thread_self() != RT_NULL)
        rt_exit_critical();
    /* not found */
    return RT_NULL;
}
```

本质上是遍历设备链表获取设备信息并返回设备句柄

## 打开/关闭串口

**使用rt_device_open()打开串口**

UART支持以下打开方式

```c
/* 流模式 */
#define RT_DEVICE_FLAG_STREAM           0x040//流模式
/* 接收模式 */
#define RT_DEVICE_FLAG_INT_RX           0x100//中断接收模式
#define RT_DEVICE_FLAG_DMA_RX           0x200//DMA接收模式
/* 发送模式 */
#define RT_DEVICE_FLAG_INT_TX           0x400//中断发送模式
#define RT_DEVICE_FLAG_DMA_TX           0x800//DMA发送模式
```

使用时这发送模式、接收模式只能**选择其一**，打开参数默认为轮询模式，但可以使用|运算符与流模式共存使用

若使用流模式，当输出的字符是'\n'(十六进制值0x0A)时，自动在前面补一个'\r'(十六进制值0x0D)作为分行

**使用rt_device_close()关闭串口**

## 发送/接收数据

**使用rt_device_write()和rt_device_read()发送、接收数据**

注意：发送数据时数据长度应为`sizeof(buffer)-1`来去掉多余的'\0'

**使用rt_device_set_tx_complete()设置回调函数来让底层硬件送数据发送完成后调用**

rt_device_set_rx_indicate()的使用同理，在串口中有数据到达时通知上层应用程序处理

常见使用方法如下

```c
#define UART_NAME "uart2"
static rt_device_t serial;
static struct rt_semaphore rx_sem;

/* 接收数据回调函数 */
static rt_err_t uart_input(rt_device_t dev,rt_size_t size)
{
    rt_sem_release(&rx_sem);//串口接收数据产生中断，调用该函数发送接收信号量
    return RT_EOK;
}
/* UART开启函数 */
static int uart_open_sample(int argc,char* argv[])
{
    serial=rt_device_find(UART_NAME);
    rt_device_open(serial,RT_DEVICE_FLAG_INT_RX);//设置中断接收模式打开串口
    rt_sem_init(&rx_sem,"rx_sem",0,RT_IPC_FLAG_FIFO);//初始化信号量
    rt_device_set_rx_indicate(serial,uart_input);//设置接收数据回调函数
}
/* UART处理函数 */
static void serial_thread_entry(void* parameter)//单独开一个线程
{
    char ch;
    /* 接收到信号量后处理串口数据 */
    while(1)
    {
        while(rt_device_read(serial,-1,&ch,1)!=1)//阻塞等待接收信号量，等到信号量后读取1个字节的数据
            rt_sem_take(&rx_sem,RT_WAITING_FOREVER);
        ch++;
		rt_device_write(serial,0,&ch,1);//读取到的数据通过串口错位输出 
    }
}
```

上面的例子将一直开启串口

## 控制串口

使用rt_device_control()控制串口状态和配置

可用的设置如下所示

```c
struct serial_configure
{
    rt_uint32_t baud_rate;
    rt_uint32_t data_bits               :4;
    rt_uint32_t stop_bits               :2;
    rt_uint32_t parity                  :2;
    rt_uint32_t bit_order               :1;//高位在前还是低位在前
    rt_uint32_t invert                  :1;//模式
    rt_uint32_t bufsz                   :16;//接收数据缓冲区大小
    rt_uint32_t reserved                :4;//保留位
};

//波特率配置
#define BAUD_RATE_2400                  2400
#define BAUD_RATE_4800                  4800
#define BAUD_RATE_9600                  9600
#define BAUD_RATE_19200                 19200
#define BAUD_RATE_38400                 38400
#define BAUD_RATE_57600                 57600
#define BAUD_RATE_115200                115200
#define BAUD_RATE_230400                230400
#define BAUD_RATE_460800                460800
#define BAUD_RATE_921600                921600
#define BAUD_RATE_2000000               2000000
#define BAUD_RATE_3000000               3000000

//数据位
#define DATA_BITS_5                     5
#define DATA_BITS_6                     6
#define DATA_BITS_7                     7
#define DATA_BITS_8                     8
#define DATA_BITS_9                     9

//停止位
#define STOP_BITS_1                     0
#define STOP_BITS_2                     1
#define STOP_BITS_3                     2
#define STOP_BITS_4                     3

//奇偶效验位
#define PARITY_NONE                     0
#define PARITY_ODD                      1
#define PARITY_EVEN                     2

//字节序
#define BIT_ORDER_LSB                   0
#define BIT_ORDER_MSB                   1

//模式
#define NRZ_NORMAL                      0       /* Non Return to Zero : normal mode */
#define NRZ_INVERTED                    1       /* Non Return to Zero : inverted mode */

//缓冲区默认大小
#define RT_SERIAL_RB_BUFSZ              64
```

默认配置如下

```c
#define RT_SERIAL_CONFIG_DEFAULT           \
{                                          \
    BAUD_RATE_115200, /* 115200 bits/s */  \
    DATA_BITS_8,      /* 8 databits */     \
    STOP_BITS_1,      /* 1 stopbit */      \
    PARITY_NONE,      /* No parity  */     \
    BIT_ORDER_LSB,    /* LSB first sent */ \
    NRZ_NORMAL,       /* Normal mode */    \
    RT_SERIAL_RB_BUFSZ, /* Buffer size */  \
    0                                      \
}
```

## 使用示例

中断接收、轮询发送的方式如上面例子一样配置，这里特别强调DMA接收的配置方法

### DMA接收

DMA自动接收UART输入的数据，自动将其放入FIFO后触发中断，中断处理函数调将消息挂至消息队列；应用程序收到消息后触发读取函数，从缓冲区读取字符

```c
#include <rtthread.h>
#define UART_NAME "uart3"

struct rx_msg//串口接收消息结构体
{
    rt_device_t dev;
    rt_size_t size;
}

static rt_device_t serial;//串口设备句柄
static struct rt_messagequeue rx_mq;//消息队列控制块

static rt_err_t uart_input(rt_device_t dev,rt_size_t size)//接收数据回调（消息队列处理）函数
{
    struct rx_msg msg;
    rt_err_t result;
    msg.dev=dev;
    msg.size=size;
    
    result=rt_mq_send(&rx_mq,&msg,sizeof(msg));//发送收取消息到消息队列
    if(result=-RT_EFULL)
        rt_kprintf("message queue full!\n");
    return result;
}

static void serial_thread_entry(void* parameter)//串口处理线程函数
{
    struct rx_msg msg;
    rt_err_t result;
    rt_uint32_t rx_length;
    static char rx_buffer[RT_SERIAL_RB_BUFSZ+1];
    
    while(1)
    {
        rt_memset(&msg,0,sizeof(msg));//清空之前的消息
        result=rt_mq_recv(&rx_mq,&msg,sizeof(msg),RT_WAITING_FOREVER);//从消息队列中轮询消息
        if(result==RT_EOK)//如果读取到消息
        {
            rx_length=rt_device_read(msg.dev,0,rx_buffer,msg.size);
            rt_buffer[rx_length]='\0';//从串口（DMA FIFO）读取数据
            
            rt_device_write(serial,0,rx_buffer,rx_length);
            rt_kprintf("%s\n",rx_buffer);//打印数据
        }
    }
}

static int uart_dma(int argc,char* argv[])//主函数
{
    rt_err_t ret=RT_EOK;
    char uart_name[RT_NAME_MAX];
    static char msg_poll[256];
    char str[]="helloworld!\r\n";
    
    if(argc==2)
        rt_strcpy(uart_name,argv[1],RTNAME_MAX);
    else
        rt_strcpy(uart_name,UART_NAME,RT_NAME_MAX);
    
    serial=rt_device_find(uart_name);//查找串口设备
    if(!serial)
    {
        rt_kprintf("find %s failed!\n",uart_name);
        return RT_ERROR;
    }
    
    /* 消息队列初始化 */
    rt_mq_init(&rx_mq,"rx_mq",
               msg_pool,//缓存区
               sizeof(struct rx_msg),//一条消息的最大长度
               sizeof(msg_pool),//缓存区大小
               RT_IPC_FLAG_FIFP);//按FIFO分配多个线程获得的消息
    
    rt_device_open(serial,RT_DEVICE_FLAG_DMA_RX);//以DMA接收及轮询方式打开串口
	rt_device_set_rx_indicate(serial,uart_input);//设置接收回调（消息队列处理）函数
    rt_device_write(serial,0,str,(sizeof(str)-1));//发送字符串
    rt_thread_t thread=rt_thread_create("serial",serial_thread_entry,RT_NULL,1024,25,10);//创建串口处理线程
    if(thread!=RT_NULL)
        rt_thread_startup(thread);
    else
        ret=RT_ERROR;
    return ret;//返回结果
}

MSH_CMD_EXPORT(uart_dma,uart device dma test);//调试指令
```