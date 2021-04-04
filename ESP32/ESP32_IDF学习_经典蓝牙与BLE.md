[TOC]

在这里着重记述低功耗蓝牙BLE相关内容，库函数部分翻译自乐鑫官网文档

# 低功耗蓝牙（BLE）协议栈

低功耗蓝牙协议是蓝牙通信协议的一种，BLE协议栈就是实现低功耗蓝牙协议的代码

## 层次协议

蓝牙协议规定了两个层次的协议，分别为**蓝牙核心协议**（Bluetooth Core）和**蓝牙应用层协议**（Bluetooth Application）

蓝牙核心协议就是对蓝牙技术本身的规范，不涉及其应用方式

蓝牙应用层协议是在蓝牙核心协议的基础上，根据具体的应用需求定义出的特定策略

蓝牙协议栈框图如下所示：

![https://img2018.cnblogs.com/blog/653161/201912/653161-20191204145125985-356995077.png](https://img2018.cnblogs.com/blog/653161/201912/653161-20191204145125985-356995077.png)

## 蓝牙核心协议（Bluetooth Core）

蓝牙核心协议包含BLE Controller和BLE Host两部分

Controller负责定义RF、Baseband等偏硬件的规范

Host负责在逻辑链路的基础上，进行更为友好的封装，这样就可以屏蔽掉蓝牙技术的细节，让Bluetooth Application更为方便的使用

==Controller是工作在物理层、数据链路层、网络层、传输层的协议，Host则是工作在传输层 、会话层、表示层、应用层的协议，Host将Controller封装成可被配置为函数的形式供程序使用==

![https://img2018.cnblogs.com/blog/653161/201912/653161-20191204145156859-489087209.png](https://img2018.cnblogs.com/blog/653161/201912/653161-20191204145156859-489087209.png)

### 包含的层次简介

1. 物理层（PHY）

用于指定BLE所用的无线频段、调制解调方式和方法等

BLE工作在1Mbps自适应跳频的GFSK射频，免于许可证的2.4GHz ISM（工业、课学、医疗）频段

**可以直观理解为规定了BLE的天线部分**

2. 链路层（LL——Link Layer）

**BLE协议栈的核心**

**相当于TCP/IP协议中的数据链路层（负责选择哪个射频通道，管理当前链路）+网络层（负责识别和发送空中数据包）+传输层（负责保证数据包安全、完整的发送、接收、重传等）**

3. 主机控制接口层（HCI——Host Controller Interface）

这一层是**可选**的，HCI主要用于2颗IC实现BLE协议栈的场合，用于贵方两者的通信协议和通信命令等

## 蓝牙应用协议（Bluetooth Application）

### 包含的层次简介

4. 通用访问配置文件层（GAP——Generic access profile）

**实际配置中常接触到的一层**

GAP是对LL层有效数据包（payload）进行解析的两种方式中最简单的一种，主要用于**广播、扫描、发起连接**这些具体行为

5. 逻辑链路控制及自适应协议层（L2CAP——Logical Link Control and Adaptation Protocol）

这一层是对LL的简单封装，在L2CAP中区分出是使用加密通道还是普通通道，同时负责连接间隔的管理

6. 安全管理层（SM——Security Manager）

负责管理BLE连接的加密、安全，需要兼顾安全性和用户使用的便利性

7. 属性协议层（ATT——Attribute protocol）

**实际配置中最常接触到的一层**

负责定义用户命令和命令操作的数据（如读写数据等）

详细内容见后文【BLE的两种模式】和【ATT简述】

8. 通用属性配置文件层（GATT——Generic Attribute profile）

**实际配置中常接触到的一层**

用于规范attribute中的数据内容（attribute见后文【BLE的两种模式】），并使用分组（group）来对attribute进行分类管理

一般地，BLE在没有GATT的情况下也能跑，只不过互联互通会出现问题

BLE**需要在GATT和各种应用profile的支持**下才能实现最便捷高效稳定的通信

# BT与BLE的区别

当前的蓝牙协议分为基础率/增强数据率（BR/EDR）和低耗能（LE）两种技术类型

经典蓝牙统称BT，低功耗蓝牙称为BLE

## 经典蓝牙模块（BT）

> 泛指支持蓝牙协议在4.0以下的模块，一般用于数据量比较大的传输。

**经典蓝牙模块**可再细分为：**传统蓝牙模块和高速蓝牙模块**。

**传统蓝牙模块**在2004年推出，主要代表是支持蓝牙2.1协议的模块，在智能手机爆发的

时期得到广泛支持。

**高速蓝牙模块**在2009年推出，速率提高到约24Mbps，是传统蓝牙模块的八倍。

## 低功耗蓝牙模块（BLE）

> 指支持蓝牙协议4.0或更高的模块，也称为BLE模块（Bluetooth Low Energy Module）,最大的特点是成功和功耗的降低。

蓝牙低功耗技术采用可变连接时间间隔，这个间隔根据具体应用可以设置为几毫秒到几秒不等。

另外，因为BLE技术采用非常快速的连接方式，因此可以处于“非连接”状态（节省能源），此时链路两端相互间仅能知晓对方，必要时可以才开启链路，然后在尽可能短的时间内关闭链路。

## 其他分类

按用途来分：蓝牙模块有**数据**蓝牙模块，**语音**蓝牙模块，**串口**蓝牙模块和**车载**蓝牙模块

按芯片设计来分：蓝牙模块有flash版本和ROM版本。前者一般是BGA封装（球栅阵列封装），外置flash；后者一般是LCC封装（表面贴装型封装），外接EEPROM。

# BLE的两种模式

1. 客户端 Client

请求数据服务

**客户端**可以主动搜索并连接附近的服务端

客户端类似蹭网的

2. 服务端Server

提供数据服务

**服务端**不需要进行主动设置，只要开启广播就可以让附近的客户端搜索到，并提供连接

服务端类似被蹭网的wifi

如果想要让ESP处于别人随时可以搜索连接的情况要配置为服务端；如果想让ESP通过扫描连接周围可连接的蓝牙设备，需要把它设置成客户端，**正好和WiFi模式的设定相反**

Server通过**characteristic**对数据进行封装，多个characteristic组成一个Service——Server是一个基本的BLE应用，如果某个*Service*是一个蓝牙联盟定义的标准服务，也可以称其为*profile*

要具体了解这些内容需要先了解属性协议层ATT

## ATT简述

![https://img2018.cnblogs.com/blog/653161/201912/653161-20191204145156859-489087209.png](https://img2018.cnblogs.com/blog/653161/201912/653161-20191204145156859-489087209.png)

属性协议层ATT（Attribute Protocol）是GATT和GAP的基础，它定义了BLE协议栈上层的数据结构和组织方式；在层内，它定义了属性（Attribute）的内容，规定了访问属性的方法和权限

属性是一个数据结构，**它包括了数据类型和数据值，可以像C语言的结构体那样构造**

属性包括三种类型：**服务项**、**特征值**和**描述符**，三者呈包含关系：服务项包含一个或多个特征值，特征值包含一个或多个描述符，多个服务项组织在一起，构成**属性规范（Attribute Profile）**

### 属性的种类和分组

属性大致可以分为三种类型：**服务项Profile**、**特征值Characteristic**和**描述符Descriptor**

最顶级为Profile, 下面是多个服务项(Service), 服务项下面是多个特征值(Characteristic), 特征值下面是多个描述符(Descriptor)

每个设备都包含以下必要的特征值和服务项：

PROFILE

- Generic Access Service（Primary Service）
  - Device Name（Characteristic）
  - Appearance（Characteristic）
- Generic Attribute Service（Primary Service）
  - Service Changed（Characteristic）
    - CCCD（Descriptor）

### 服务项Service

服务项这种类型本身并不包含数据，仅仅相当于是一个**容器**，用来**容纳特征值**

### 特征值characteristic

特征值用于**保存用户数据**，但它也有自己的UUID——可以把它看作一个变量，变量里存着数据（用户数据），也有自己的地址信息（UUID）

使用特征值时，也要遵循“先声明再赋值”的步骤——先声明特征值自身，再声明它的项

一个characteristic包含三种条目：

1. characteristic声明：每个characteristic的分界符，解析时一旦遇到一个声明，就可以认为接下来又是一个新的characteristic；声明还包含了接下来characteristic值的读写属性等
2. characteristic值：数据的值
3. characteristic描述符：数据的额外信息

一般BLE的属性体系在系统中以GattDB表示，即**属性数据库**，gattDB是BLE协议栈在内存中开辟的一段专有区域，会在特定的时候写入Flash进行保存，并在启动时读取出来回写到内存中去，但**并非所有的BLE数据通信是操作gattDB**

characteristic用**Attribute**数据结构来实现

### 属性Attribute的数据结构

Attribute由四部分组成：

1. 属性句柄Attribute handle：可以视为**指向属性实体的指针**，对端设备通过属性句柄来访问某个属性，大小2字节，起始于0x0001，系统初始化时，各属性的句柄逐步+1，但最大不超过0xFFFF

2. 属性类型Attribute type：用以区分当前属性是服务项或是特征值等，用通用唯一识别码（**UUID**）标识的16字节十六进制字符串（形如f6257d37-34e5-41dd-8f40-e308210498b4，从网上抄来的示例，如有雷同那就是雷同）表示。一个合法的UUID，一定是随机的、全球唯一的，不应该出现两个相同的UUID。属性类型分类如下：

   * 首要服务项Primary Service
   * 次要服务项Secondary Service
   * 包含服务项Include
   * 特征值Characteristic

   他们与UUID的映射关系如下：

   * 0x1800 – 0x26FF ：服务项类型
   * 0x2700 – 0x27FF ：单位
   * 0x2800 – 0x28FF ：属性类型
   * 0x2900 – 0x29FF ：描述符类型
   * 0x2A00 – 0x7FFF ：特征值类型

   为了减少传输的数据量，BLE协议做了一个转换约定，给定一个固定的16字节模板，只设置2个字节为变化量，其他为常量，2字节的UUID在系统内部会被替换，进而转换成标准的16字节UUID；反之，如果一个特征值的UUID是16字节的，在系统内部它的属性类型也可能写成第3、4字节组成的双字节

   示例如下：

   UUID模板为

   ```
   0000XXXX-0000-1000-8000-00805F9B34FB
   ```

   其中从左数第3、4个字节“XXXX”就是变化位，其他为固定位。如：UUID=0x2A00在系统内部会转换成00002A00-0000-1000-8000-00805F9B34FB。

3. 属性值Attribute value：真正的数据值，大小为0-512字节。如果该属性是服务项类型或者是特征值声明类型，那么它的属性值就是UUID等信息；如果是普通的特征值，则属性值是用户的数据，属性值需要预留空间以保存用户数据，**可以将属性值的预留空间看做I2C的数据空间，操作特征值里的用户数据，就是对那块内存空间进行读写**，==所以启用蓝牙后会占用额外的内存==

4. 属性权限Attribute permissions：Attribute的权限属性，主要有四种：

   * 访问权限（Access Permission）：只读或只写或读写
   * 加密权限（Encryption Permission）：加密或不加密
   * 认证权限（Authentication Permission）：需要认证或无需认证。指相互确认对方身份，BLE中所说的“认证”过程就是设备配对
   * 授权权限（Authorization Permission）：需要授权或无需授权。指对授信设备开放权利

   授权的管控等级要高于认证，认证的设备未必被授权，授权的设备一定是认证的——**认证是授权的充分不必要条件**。认证是设备配对，两边都符合协议规定就行，但是授权取决于Server设备对Client设备的主动许可。

   一个没有经过认证的设备，被称为**未知设备（Unknown Device）**；经过了认证，该设备会在绑定信息中被标记为Untrusted，被称为**不可信设备（Untrusted Device）**；经过了认证，并且在绑定信息中被标记为Trusted的设备被称为**可信设备（Trusted Device）**

   具体的权限示例如下所示：

   * Open（随意读写）
   * No Access（禁止读写）
   * Authentication（需要配对才能读写，分成很多子类型用于适配配对的类型）
   * Authorization（允许应用在回调函数中读写）
   * Signed（签名后才能随意读写）

### 属性协议ATT PDU

拥有一组属性的设备称为服务端（Server）；读写该属性值的设备称为客户端（Client）

Client和Server之间通过**ATT PDU**通信

属性协议ATT PDU共有6种，如下表所示：

| ATT PDU种类  | 发送方向         | 触发响应     | 说明                                                         |
| ------------ | ---------------- | ------------ | ------------------------------------------------------------ |
| Command      | Client -> Server | –            | 客户端发送Command，服务器无需任何返回                        |
| Request      | Client -> Server | Response     | 客户端发送Request，服务器需要返回一个Response，表明服务器收到 |
| Response     | Server -> Client | –            |                                                              |
| Notification | Server -> Client | –            | 服务器发送Notification，户端无需任何返回                     |
| Indication   | Server -> Client | Confirmation | 服务器发送Indication，客户端需要返回一个Confirmation，表明客户端收到 |
| Confirmation | Client -> Server | –            |                                                              |

BLE下，所有命令都是“必达”的，每个命令发送完毕后，发送者会等待ACK信息（类似I2C），如果收到了ACK包，发起方认为命令完成；否则发起方会一直重传该命令直到超时导致BLE连接断开（类似CAN的出错重发机制），可以说**只要数据包放到了协议栈射频FIFO中，蓝牙协议栈就能保证该数据包“必达”对方**，但是没有回复相对有回复就是“不太可靠”，这时候就需要特殊的“有回复属性”

### Request后缀

特别地，如果一个命令需要response，那么可以在相应命令后面加上request后缀，这个response包**在应用层有回调事件**，可以用于触发特殊的功能，这是默认的协议ACK恢复不具有的，采用request/response方式，应用层可以按顺序地发送一些数据包；如果一个命令只需要ACK而不需要response，那么它的后面就不会带request

然而Request/response会大大降低通信的吞吐率，因为request/response必须在不同的连接间隔中出现，这就导致两个连接间隔最多只能发一个数据包，而不带request后缀的ATT命令就没有这个问题——一般情况下，在同一个连接间隔中可以同时发多个数据包，这样将大大提高数据的吞吐率

常用的带request命令：所有read命令，writerequest，indication等

常用的不带request命令：write command，notification等

## 通用属性协议GATT简述

GATT(Generic Attribute Profile)，描述了一种使用ATT的服务框架。该框架定义了服务(Server)和服务属性(characteristic)的过程(Procedure)及格式，负责处理具体数据段通过蓝牙连接的发送和接收

**==现在的BLE大多建立在GATT协议之上==**，GATT建立在ATT和L2CAP之上，GATT需要使用通用访问协议GAP来确定设备的连接

![https://img2018.cnblogs.com/blog/653161/201912/653161-20191204145156859-489087209.png](https://img2018.cnblogs.com/blog/653161/201912/653161-20191204145156859-489087209.png)

### 通用访问协议GAP

GAP 使设备被其他设备可见，并决定了当前设备是否可以或者怎样与合同设备进行交互

GAP中，设备被分为**外围设备Peripheral**和**中心设备Central**

外围设备：性能相对较弱、功耗相对低的设备，他们通常被连接到更加强大的中心设备

中心设备：性能相对较强、功耗较高的设备

#### GAP广播

GAP 中外围设备不停向外广播以让中心设备知道它的存在。通过两种方式向外广播数据： 

广播数据（Advertising Data Payload）：*必须的*，外设需要以此来和中心设备取得连接

扫描回复（Scan Response Data Payload）：*可选的*，中心设备可以向外围设备请求扫描回复，向其提供一些设备的额外信息

外围设备会设定一个广播建个，每个间隔中，它会重新发送自己的广播数据，**广播间隔越长约省电，但同时更不容易被扫描到**

基于GATT广播的BLE连接只能是**一个外围设备连接一个中心设备**，可以理解成一个蓝牙耳机只能连接一台手机，不能同时连接两台手机

#### GATT协议

GATT协议建立在ATT协议的基础上。将ATT协议中的Service、Characteristic 及对应数据都保存在一个查找表中，查找表使用16位的ID作为索引。建立GATT连接前必须先经过GAP协议

**GATT连接是独占的**，也就是说同一个BLE外设（外部设备）同时只能被一个中心设备连接，一旦外设被连接，它就会停止GAP广播，对其它设备不可见；当设备断开时它又开始广播。

如果中心设备和外设**需要双向通信，唯一的方式就是建立GATT连接**，GAP通信是单向的，只能让中心设备向外设发送信息

GATT通信双方是C/S关系，外设作为GATT的Server，维持ATT查找表、Service、Characteristic定义；中心设备作为GATT的Client，向Server发起请求，所有通信事件都由中心设备Client发起，从Server接收响应。一旦连接建立，外设将会给中心设备建议一个**连接间隔**，中心设备*可以选择*在每个连接间隔尝试重新连接，检查是否有新数据，不过这个间隔只是建议，中心设备可以不严格按照这个间隔执行请求。

#### GATT结构

GATT结构建立在ATT的属性Attribute数据结构之上（其实和ATT的那些东西一模一样）

**Attribute结构体组成种类不同的Characteristic，多个Characteristic被封装在Servce容器中，Characteristic和Service容器都有着自己的UUID（有官方认证的16位UUID和自定义的128位UUID），各种常用的Service集合成Profile**

BLE外设的通信主要通过Characteristic，通过在Characteristic中读写数据就实现了双向通信，也可以通过实现类似串口的Service来配置TxCharacteristic和RxCharacteristic，这些都是具体项目的选择了

# BLE从初始化到建立连接的过程简述

1. 外围设备开始广播，发送完一个广播包后T_IFS，开启射频Rx窗口接收来自中心设备的数据包
2. 中心设备扫描到广播，在收取此广播T_IFS后如果开启了中心设备的扫描回复，中心设备将向外设发送回复
3. 外设收取到中心设备的回复，做好接收准备，并返回ACK包
4. 如果ACK包未被中心设备接收到，中心设备将一直发送回复直到超时，此期间内只要外设返回过一次ACK包就算连接成功
5. 开始建立通信，后续中心设备将以收取到外设广播的时间为原点，以Connection Interval为周期向外设发送数据包，数据包将具有两个作用：**同步两设备时钟**和**建立主从模式通信**

外设每收到中心设备的一个包，就会把自己的时序原点重新设置，以和中心设备同步（Service向Client同步）

BLE通信在建立成功后变为主从模式，**中心设备Central变为Master，外设Peripheral变为Slave**，Slave只能在Master向它发送了一个包以后才能在规定的时间内把自己的数据回传给Master

6. 连接建立成功
7. 外设自动停止广播，其他设备无法再查找到该外设
8. 按照以下时序进行通信，在中心设备发送包的间隔内，外设可以发送多个包

![在这里插入图片描述](https://img-blog.csdnimg.cn/20190726193026779.png)

8. 需要连接断开时只需要中心设备停止连接（停止发送包）即可
9. 中心设备可以将外设的addr写入Flash或SRAM等存储器件，保持监听此addr，当再次收到外设广播时就可以建立通信。BLE Server设备为了省电，当一段时间内没有数据要发送时，可以不再发送包，双方就会因为连接超时（connection timeout）断开，这时需要中心设备启动监听，这样，当BLE Server设备需要发送数据时，就可以再次连接

# ESP的蓝牙外设配置

## 蓝牙配置相关库函数

### 相关头文件及其作用

```c
#include "bt.h"//蓝牙控制器和VHCI设置头文件
#include "esp_gap_ble_api.h"//GAP设置头文件，广播和连接相关参数配置
#include "esp_gatts_api.h"//GATT配置头文件，创建Service和Characteristic
#include "esp_bt_main.h"//蓝牙栈空间的初始化头文件
```

### 蓝牙控制器

使用esp_bt_controller_init()

```c
esp_bt_controller_init(esp_bt_controller_config_t *cfg);//esp_bt_controller_config_t是蓝牙控制器配置结构体

struct esp_bt_controller_config_t
{
    uint16_t controller_task_stack_size;//蓝牙控制器栈大小
    uint8_t controller_task_prio;//蓝牙控制器任务优先级
    uint8_t hci_uart_no;//使用哪个UART作为HCI的IO，仅能选择UART1或UART2串口
	uint32_t hci_uart_baudrate;//HCI串口波特率
    uint8_t scan_duplicate_mode;//重复扫描模式
    uint8_t scan_duplicate_type;//重复扫描类型
    uint16_t normal_adv_size;//普通广播报文大小
    uint16_t mesh_adv_size;//mesh广播报文大小
    uint16_t send_adv_reserved_size;//蓝牙控制器最小的内存大小（保留出发送报文所需的内存大小）
    uint32_t controller_debug_flag;//蓝牙控制器debug log的属性
    uint8_t mode;//BR/EDR/BLE/Dual模式选择
	uint8_t ble_max_conn;//BLE模式最多连接个数
    uint8_t bt_max_acl_conn;//BR或EDR最大的ACL连接个数
    uint8_t bt_sco_datapath;//SCO数据路径 用于HCI或PCM模块
	bool auto_latency;//BLE自动延迟，用于降低传统蓝牙的功耗
    bool bt_legacy_auth_vs_evt;//BR/EDR传统的授权完毕事件，用于防止BIAS攻击
    uint8_t bt_max_sync_conn;//BR/EDR最多的ACL连接数目，也可以在menuconfig中配配置
    uint8_t ble_sca;//BLE晶振准确度指数
    uint8_t pcm_role;//PCM角色，选择master或slave
    uint8_t pcm_polar;//PCM触发极性，选择下降沿或上升沿
    uint32_t magic;//神奇数字
}
```

初始化蓝牙控制器，==此函数只能被调用一次，且必须在其他蓝牙功能被调用之前调用==

使用esp_bt_controller_deinit()来取消初始化，用于关闭蓝牙并清除其占用的内存，还会将蓝牙任务删除

下面是蓝牙控制器的常用API

```c
esp_bt_controller_enable(esp_bt_mode_t mode);//使能蓝牙控制器，mode是蓝牙模式，如果想要动态改变蓝牙模式不能直接调用该函数，应该先用下面的disable关闭蓝牙再使用该API来改变蓝牙模式
esp_bt_controller_disable(void);//关闭蓝牙控制器
sp_bt_controller_get_status(void);//获取蓝牙控制器状态
esp_bt_get_mac(void);//获取蓝牙MAC地址

esp_bt_controller_mem_release(esp_bt_mode_t mode);//释放蓝牙控制器的所有内存，包括BSS、数据和其他蓝牙使用的堆栈空间
//这个API仅仅应该再esp_bt_controller_init()或after esp_bt_controller_deinit()之前被调用
esp_bt_mem_release(esp_bt_mode_t mode);
//释放蓝牙控制器和蓝牙数据的所有内存，比esp_bt_controller_mem_release()更彻底
esp_bt_sleep_enable(void);//让蓝牙进入睡眠模式，这个函数应该在esp_bt_controller_enable()被调用之后再调用
```

特别地，官方文档中给出了一套在线升级蓝牙设备软件时的关闭流程

```c
esp_bluedroid_disable();
esp_bluedroid_deinit();
esp_bt_controller_disable();
esp_bt_controller_deinit();
esp_bt_mem_release(ESP_BT_MODE_BTDM);
```

### 经典蓝牙

用于蓝牙运行的API如下所示

```c
esp_bluedroid_get_status(void);//获取蓝牙当前状态
//可能的状态如下所示
ESP_BLUEDROID_STATUS_UNINITIALIZED==0//未初始化
ESP_BLUEDROID_STATUS_INITIALIZED//已被初始化但是未开启
ESP_BLUEDROID_STATUS_ENABLED//初始化并开启
    
esp_bluedroid_enable(void);//使能蓝牙
esp_bluedroid_disable(void);//关闭蓝牙
esp_bluedroid_init(void);//初始化蓝牙并分配系统资源，它应该被第一个调用
esp_bluedroid_deinit(void);//取消初始化蓝牙并将系统资源释放，用于蓝牙结束工作后的收尾
```

用于设备蓝牙配置的API如下所示

```c
esp_bt_dev_get_address(void);//获取当前设备蓝牙地址
esp_bt_dev_set_device_name(const char *name);//设置设备名
```

这些函数都应该在蓝牙启用后被调用

## BLE-GAP相关库函数

### 外围设备库函数

```c
esp_ble_gap_start_advertising(esp_ble_adv_params_t *adv_params);//开始广播
esp_ble_gap_stop_advertising(void);//停止广播

esp_ble_gap_config_adv_data(esp_ble_adv_data_t *adv_data);//广播数据参数设置
//adv_data数据结构如下
bool set_scan_rsp//设置是否需要扫描response
bool include_name//广播内容是否包括设备名
bool include_txpower//广播数据是否包括发射功率
int min_interval//最小广播时间间隔
//计算公式：connIntervalmin = Conn_Interval_Min * 1.25 ms
//Conn_Interval_Min在0x0006到0x0C80之间，0xFFFF就是没有特定的最小值
int max_interval//最大广播间隔
//计算公式：connIntervalmax = Conn_Interval_Max * 1.25 ms
//Conn_Interval_Max在0x0006到0x0C80之间，Conn_Interval_Max应大于等于Conn_Interval_Min
//0xFFFF代表没有特定的最大值
int appearance//设备外形（External appearance）
uint16_t manufacturer_len//生产商数据长度
uint8_t *p_manufacturer_data//生产商数据指针
uint16_t service_data_len//Service数据长度
uint8_t *p_service_data//Service数据指针
uint16_t service_uuid_len//Service的UUID长度
uint8_t *p_service_uuid//Service的UUID数组指针
uint8_t flag//广播属性（flag）
    
esp_ble_gap_config_adv_data_raw(uint8_t *raw_data, uint32_t raw_data_len);//设置空的广播数据包，用户需要自行设置包的内容
```

### 中心设备库函数

```c
esp_ble_gap_start_scanning(uint32_t duration);//使用该函数让设备扫描附近正在广播的外设，duration为扫描间隔
esp_ble_gap_stop_scanning(void);//停止扫描

esp_ble_gap_set_scan_params(esp_ble_scan_params_t *scan_params);//设置扫描参数
esp_ble_gap_register_callback(esp_gap_ble_cb_t callback)//间隔回调函数
    
esp_ble_gap_set_pkt_data_len(esp_bd_addr_t remote_device, uint16_t tx_data_length);//设置最大数据包大小

esp_ble_gap_set_prefer_conn_params(esp_bd_addr_t bd_addr, uint16_t min_conn_int, uint16_t max_conn_int, uint16_t slave_latency, uint16_t supervision_tout);//设置当默认连接参数无法使用时的优先连接参数，这个库函数只能用在中心设备master上

esp_ble_gap_config_scan_rsp_data_raw(uint8_t *raw_data, uint32_t raw_data_len);//设置空的response数据包，用户需要自行设置数据

esp_ble_gap_read_rssi(esp_bd_addr_t remote_addr);//读取远程设备的RSSI，结果会在间隔回调函数中随ESP_GAP_BLE_READ_RSSI_COMPLETE_EVT事件返回
```

### 连接配置库函数

```c
esp_ble_gap_update_conn_params(esp_ble_conn_update_params_t *params);//在连接建立后更新连接参数
esp_ble_gap_clear_rand_addr(void);//清空应用的随机地址

esp_ble_gap_update_whitelist(bool add_remove, esp_bd_addr_t remote_bda, esp_ble_wl_addr_type_t wl_addr_type);//新建或移除白名单中的设备
esp_ble_gap_get_whitelist_size(uint16_t *length);//获取白名单的大小

esp_ble_gap_set_device_name(const char *name);//设置本机设备名
esp_ble_gap_get_local_used_addr(esp_bd_addr_t local_used_addr, uint8_t *addr_type);//获取本机设备地址
```

## GATT Server的配置

### Server-Master

#### 基本设置

```c
esp_err_t ret;//用于debug
esp_bt_controller_config_t bt_cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();//设置蓝牙为默认参数

ret = nvs_flash_init();//初始化NVS
if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND)
{
	ESP_ERROR_CHECK(nvs_flash_erase());
	ret = nvs_flash_init();
}
ESP_ERROR_CHECK(ret);
ESP_LOGI(TAG, "%s init NVS finished\n", __func__);

ESP_ERROR_CHECK(esp_bt_controller_mem_release(ESP_BT_MODE_BLE));//释放蓝牙所需空间

ret = esp_bt_controller_init(&bt_cfg);//初始化蓝牙控制器
if (ret)
{
	ESP_LOGE(TAG, "%s enable controller failed: %s\n", __func__, esp_err_to_name(ret));
	return;
}
ret = esp_bt_controller_enable(ESP_BT_MODE_BLE);//使能蓝牙控制器
if (ret)
{
	ESP_LOGE(TAG, "%s enable controller failed: %s\n", __func__, esp_err_to_name(ret));
	return;
}
ret = esp_bluedroid_init();//初始化蓝牙栈bluedroid stack
/*
蓝牙栈bluedroid stack包括了BT和BLE使用的基本的define和API
初始化蓝牙栈以后并不能直接使用蓝牙功能，
还需要用FSM管理蓝牙连接情况
*/
if (ret)
{
	ESP_LOGE(TAG, "%s init bluetooth failed: %s\n", __func__, esp_err_to_name(ret));
	return;
}
ret = esp_bluedroid_enable();//使能蓝牙栈
if (ret) 
{
	ESP_LOGE(TAG, "%s enable bluetooth failed: %s\n", __func__, esp_err_to_name(ret));
	return;
}
ESP_LOGI(TAG, "%s init bluetooth finished\n", __func__);
//建立蓝牙的FSM
//这里使用回调函数来控制每个状态下的响应，需要将其在GATT和GAP层的回调函数注册
ret = esp_ble_gatts_register_callback(BLE_gatts_event_handler);
if (ret)
{
	ESP_LOGE(TAG, "gatts register error, error code = %x", ret);
	return;
}
ret = esp_ble_gap_register_callback(BLE_gap_event_handler);
if (ret)
{
	ESP_LOGE(TAG, "gap register error, error code = %x", ret);
	return;
}
/*BLE_gatts_event_handler和BLE_gap_event_handler处理蓝牙栈可能发生的所有情况，达到FSM的效果*/

//下面创建了两个BLE GATT profile，相当于两个独立的应用程序
ret = esp_ble_gatts_app_register(GATT_APP_A_ID);
if (ret)
{
	ESP_LOGE(TAG, "gatts app register error, error code = %x", ret);
	return;
}
ret = esp_ble_gatts_app_register(GATT_APP_B_ID);
if (ret)
{
	ESP_LOGE(TAG, "gatts app register error, error code = %x", ret);
	return;
}
```

有限状态机FSM（finite state machine），或者说状态机SM（state machine）是一种特殊的控制算法，能够根据**控制信号**按照**预先设定的状态**进行状态转移

若输出只和状态有关而与输入无关，则称为Moore状态机；若输出不仅和状态有关而且和输入有关系，则称为Mealy状态机

控制蓝牙的状态机一般为Moore状态机，随蓝牙所处的状态进行不同的操作（代码中通过switch语句进行控制）

Server的profile利用一个结构体来定义，结构体成员取决于在这个profile中执行的service和characteristic，如下所示

```c
struct gatts_profile_inst {
    esp_gatts_cb_t gatts_cb;//GATT回调函数
    uint16_t gatts_if;//GATT接口
    uint16_t app_id;//应用的ID
    uint16_t conn_id;//连接的ID
    uint16_t service_handle;//Service句柄
    esp_gatt_srvc_id_t service_id;//Service ID
    uint16_t char_handle;//Characteristic句柄
    esp_bt_uuid_t char_uuid;//Characteristic的UUID
    esp_gatt_perm_t perm;//属性Attribute 授权
    esp_gatt_char_prop_t property;//Characteristic的优先级
    uint16_t descr_handle;//Client的Characteristic配置句柄
    esp_bt_uuid_t descr_uuid;//Client的Characteristic UUID
};
```

可以将这个结构体进一步组合为结构体数组

```c
static struct gatts_profile_inst gl_profile_tab[PROFILE_NUM] = {
    [PROFILE_A_APP_ID] = {
        .gatts_cb = gatts_profile_a_event_handler,
        .gatts_if = ESP_GATT_IF_NONE,
    [PROFILE_B_APP_ID] = {
        .gatts_cb = gatts_profile_b_event_handler,
        .gatts_if = ESP_GATT_IF_NONE,
    },
};
```

这样使用类似`gl_profile_tab[i].gatts_if`的语句就可以访问结构体的成员，i用于指示第（i+1）个profile

使用上面的结构体数组来定义每个profile对应的GATT回调函数（gatts_profile_a_event_handler()、gatts_profile_b_event_handler()），就使得每个不同的profile使用不同的接口；初始化时，将gatts_if = ESP_GATT_IF_NONE，在之后通过各自的处理函数将profile连接到接口

最后使用esp_ble_gatts_app_register()这个API将应用的ID注册到GATT

```c
ret = esp_ble_gatts_app_register(GATT_APP_A_ID);//run GATT app A register
if (ret)
{
	ESP_LOGE(TAG, "gatts app register error, error code = %x", ret);
	return;
}
ret = esp_ble_gatts_app_register(GATT_APP_B_ID);//run GATT app B register
if (ret)
{
	ESP_LOGE(TAG, "gatts app register error, error code = %x", ret);
	return;
}
```

#### GAP设置

使用esp_ble_adv_data_t结构体来配置GAP广播情况，并使用esp_ble_gap_config_adv_data()函数进行广播

```c
typedef struct {
    bool set_scan_rsp;//是否作为扫描的回应信号广播
    bool include_name;//是否包括设备名
    bool include_txpower;//是否包括信号的发射功率
    int min_interval;//广播数据显示slave设备的连接最小时间间隔
    int max_interval;//广播数据显示slave设备的连接最大时间间隔
    int appearance;//设备外观（？）
    uint16_t manufacturer_len;//附加数据长度
    uint8_t *p_manufacturer_data;//附加数据指针
    uint16_t service_data_len;//Service数据长度
    uint8_t *p_service_data;//Service数据指针
    uint16_t service_uuid_len;//Servic UUID长度
    uint8_t *p_service_uuid;//Servic UUID指针
    uint8_t flag;//广播的发现模式，可选BLE_ADV_DATA_FLAG枚举值
} esp_ble_adv_data_t;

//设置示例
static esp_ble_adv_data_t adv_data = {
    .set_scan_rsp = false,
    .include_name = true,
    .include_txpower = false,
    .min_interval = 0x0006, //slave connection min interval, Time = min_interval * 1.25 msec=7.5ms
    .max_interval = 0x0010, //slave connection max interval, Time = max_interval * 1.25 msec=20ms
    .appearance = 0x00,
    .manufacturer_len = 0, //TEST_MANUFACTURER_DATA_LEN
    .p_manufacturer_data = NULL, //&test_manufacturer[0]
    .service_data_len = 0,
    .p_service_data = NULL,
    .service_uuid_len = sizeof(adv_service_uuid128),
    .p_service_uuid = adv_service_uuid128,
    .flag = (ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT),
};
```

一个广播的有效数据是31字节，如果超过会导致超出部分被截掉

使用esp_ble_gap_config_adv_data_raw()和esp_ble_gap_config_scan_rsp_data_raw()函数可以广播自定义的空数据

广播数据设置完毕后，会自动进入ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT()或ESP_GAP_BLE_ADV_DATA_RAW_SET_COMPLETE_EVT状态，此时可以在gap_event_handler()中设置FSM控制程序

```c
static void BLE_gap_event_handler(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t* param)
{
    switch (event)
    {
#ifdef CONFIG_SET_RAW_ADV_DATA
    case ESP_GAP_BLE_ADV_DATA_RAW_SET_COMPLETE_EVT:
        adv_config_done &= (~adv_config_flag);
        if (adv_config_done == 0)
        {
            esp_ble_gap_start_advertising(&adv_params);
        }
        break;
    case ESP_GAP_BLE_SCAN_RSP_DATA_RAW_SET_COMPLETE_EVT:
        adv_config_done &= (~scan_rsp_config_flag);
        if (adv_config_done == 0)
        {
            esp_ble_gap_start_advertising(&adv_params);
        }
        break;
#else
    case ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT:
        adv_config_done &= (~adv_config_flag);
        if (adv_config_done == 0)
        {
            esp_ble_gap_start_advertising(&adv_params);
        }
        break;
    case ESP_GAP_BLE_SCAN_RSP_DATA_SET_COMPLETE_EVT:
        adv_config_done &= (~scan_rsp_config_flag);
        if (adv_config_done == 0)
        {
            esp_ble_gap_start_advertising(&adv_params);
        }
        break;
#endif
    case ESP_GAP_BLE_ADV_START_COMPLETE_EVT:
        //advertising start complete event to indicate advertising start successfully or failed
        if (param->adv_start_cmpl.status != ESP_BT_STATUS_SUCCESS)
        {
            ESP_LOGE(TAG, "Advertising start failed\n");
        }
        break;
    case ESP_GAP_BLE_ADV_STOP_COMPLETE_EVT:
        if (param->adv_stop_cmpl.status != ESP_BT_STATUS_SUCCESS)
        {
            ESP_LOGE(TAG, "Advertising stop failed\n");
        }
        else
        {
            ESP_LOGI(TAG, "Stop adv successfully\n");
        }
        break;
    case ESP_GAP_BLE_UPDATE_CONN_PARAMS_EVT:
        ESP_LOGI(TAG, "update connection params status = %d, min_int = %d, max_int = %d,conn_int = %d,latency = %d, timeout = %d",
            param->update_conn_params.status,
            param->update_conn_params.min_int,
            param->update_conn_params.max_int,
            param->update_conn_params.conn_int,
            param->update_conn_params.latency,
            param->update_conn_params.timeout);
        break;
    default:
        break;
    }
}
```

只要使用了esp_ble_gap_start_advertising()函数，GATT Server就会开始广播，在此之前还需要用esp_ble_adv_params_t结构体配置相关的参数

```c
//广播参数
typedef struct {
    uint16_t adv_int_min;
	//非定向和循环定向广播的最小时间间隔
    //间隔设置在0x0020到0x4000，默认0x0800（1.28s），实际时间=N * 0.625 ms，时间范围在20ms到10.24s
    
    uint16_t adv_int_max;
    //非定向和循环定向广播的最大时间间隔
    //间隔设置在0x0020到0x4000，默认0x0800（1.28s），实际时间=N * 0.625 ms，时间范围在20ms到10.24s
    
    esp_ble_adv_type_t adv_type;//广播类型
    esp_ble_addr_type_t own_addr_type;//拥有者的蓝牙设备地址类型
    esp_bd_addr_t peer_addr;//附近的蓝牙设备地址
    esp_ble_addr_type_t peer_addr_type;//附近的蓝牙设备地址类型
    esp_ble_adv_channel_t channel_map;//广播通道映射
    esp_ble_adv_filter_t adv_filter_policy;//广播过滤器设置
}
esp_ble_adv_params_t;

//设置示例
static esp_ble_adv_params_t adv_params = {
    .adv_int_min        = 0x20,//最小时间间隔
    .adv_int_max        = 0x40,//最大时间间隔
    .adv_type           = ADV_TYPE_IND,
    .own_addr_type      = BLE_ADDR_TYPE_PUBLIC,//公共地址
    //.peer_addr            =默认
    //.peer_addr_type       =默认
    .channel_map        = ADV_CHNL_ALL,//全通道
    .adv_filter_policy = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY,//扫描所有连接
};
```

设置完毕后，可以使用esp_ble_gap_start_advertising()进行广播

注意：**esp_ble_gap_config_adv_data()使用esp_ble_adv_data_t结构体进行设置，配置的是广播出去的数据；而esp_ble_gap_start_advertising()使用esp_ble_adv_params_t结构体进行设置，配置的是该怎样广播**

# 经典蓝牙的子集SPP

蓝牙串口协议Serial Port Profile简写为SPP，SPP就是一种能在蓝牙设备之间创建串口进行数据传输的协议，最终目的是在两个不同设备（通信的两端）上的应用之间保证一条完整的通信路径

SPP的协议栈示意图如下

![image-20210205162726034](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210205162726034.png)

### 连接流程

1. 创建虚拟连接
2. 接受虚拟串口连接
3. 在本地SDP数据上注册服务

### SPP协议与GATT协议的对比

| 经典蓝牙BT-SPP | 低功耗蓝牙BLE-GATT         |
| -------------- | -------------------------- |
| 速率高         | 灵活多变、集成很多profile  |
| 兼容性好       | 高速率传输时兼容性难以保障 |
| 对IOS不友好    | 对IOS很友好                |
| APP编程不方便  | 开发资源丰富、接口多       |



