[TOC]

下面是RTT的网络结构框架，供参考

  ![网络框架图](https://www.rt-thread.org/document/site/programming-manual/sal/figures/network_frame.jpg)

# 网卡netdev

netdev（network interface device）即网络接口设备，又称网卡

RTT中每个用于网络连接的设备都可以注册成网卡，RTT提供了netdev组件用于适配更多种类的网卡并进行管理和控制

网卡的主要作用：

1. **解决设备多网卡连接时网络连接问题**

2. **统一管理各个网卡信息与网络连接状态**
3. **提供统一的网卡调试命令接口**

特性如下：

* 将网卡抽象为类，每个网络连接设备可以唯一注册
* 提供多种网络连接信息查询，方便用户实时获取当前网卡网络状态
* 建立网卡列表和默认网卡
* 提供多种网卡操作接口（设置 IP、DNS 服务器地址，设置网卡状态等）
* 适配了unix-like网络工具（ping、ifconfig、netstat、dns等命令），可直接在FinSH调用

## 工作原理

### 网络概念简介

协议栈是指网络中各层协议的总和，每种协议栈反映了不同的网络数据交互方式

平常接触较多的协议栈就是TCP/IP，但嵌入式设备中需要精简、低性能需求的协议，所以RTT目前支持的协议栈不太一样：

* lwIP协议栈
* AT Socket协议栈
* WIZnet TCP/IP硬件协议栈

每种协议栈对应一种协议簇类型，上述协议栈分别对应的协议簇类型为：AF_INET、AF_AT、AF_WIZ

**网卡的初始化和注册建立在协议簇类型上**，所以每种网卡对应唯一的协议簇类型

**套接字描述符的创建建立在网卡基础上**，所以每个创建的套接字对应唯一的网卡

比如有ESP12-F、ESP32-WROOM-E两个设备连在了跑着RTT的ART-Pi上，

如果它们运行着同一个协议，比如AT协议，那么它们会被分派成两个不同的netdev（比如netdev0和netdev1），然后连接在同一个family（如AT）上，每个设备都唯一对应着自己的套接字，也就是说形成了这样的关系：

【ESP12-F】-【netdev0】-【AT协议】-【socket0】

【ESP32-WROOM-E】-【netdev1】-【AT协议】-【socket1】

如果它们运行着不同的协议，比如ESP12-F运行AT，ESP32-WROOM-E运行lwIP，那么它们会形成如下关系

【ESP12-F】-【netdev0】-【AT协议】-【socket0】

【ESP32-WROOM-E】-【netdev1】-【lwIP协议】-【socket1】

下面是RTT的网络结构框架（梅开二度）

  ![网络框架图](https://www.rt-thread.org/document/site/programming-manual/sal/figures/network_frame.jpg)

RTT使用网卡结构体对象来管理网卡，如下所示

```c
/* 网卡结构体对象 */
struct netdev
{
    rt_slist_t list;                                   /* 网卡列表 */

    char name[RT_NAME_MAX];                            /* 网卡名称 */
    ip_addr_t ip_addr;                                 /* IP 地址 */
    ip_addr_t netmask;                                 /* 子网掩码地址 */
    ip_addr_t gw;                                      /* 网关地址 */
    ip_addr_t dns_servers[NETDEV_DNS_SERVERS_NUM];     /* DNS 服务器地址 */
    uint8_t hwaddr_len;                                /* 硬件地址长度 */
    uint8_t hwaddr[NETDEV_HWADDR_MAX_LEN];             /* 硬件地址 */

    uint16_t flags;                                    /* 网卡状态位 */
    uint16_t mtu;                                      /* 网卡最大传输单元 */
    const struct netdev_ops *ops;                      /* 网卡操作回调函数 */

    netdev_callback_fn status_callback;                /* 网卡状态改变回调 */
    netdev_callback_fn addr_callback;                  /* 网卡地址改变回调 */

#ifdef RT_USING_SAL
    void *sal_user_data;                               /* 网卡中协议簇相关参数数据 */
#endif /* RT_USING_SAL */
    void *user_data;                                   /* 预留用户数据 */
};
```

### 网卡的状态和配置

netdev组件提供对网卡网络状态的管理和控制，其类型主要包括下面四种：

* **up/down**：底层网卡初始化完成之后置为up状态，用于判断网卡**开启还是禁用**
* **link_up/link_down**：用于判断网卡设备是否具有有效的**链路连接**，连接后可以与其他网络设备进行通信。该状态一般由网卡底层驱动设置
* **internet_up/internet_down**：用于判断设备是否**连接到因特网**，接入后才可以与外网设备进行通信
* **dhcp_enable/dhcp_disable**：用于判断当前网卡设备是否开启**DHCP功能支持**

up/down状态以及dhcp_enable/dhcp_disable状态可以通过netdev组件提供的接口设置，可以在应用层控制；其他状态是由网卡底层驱动或者netdev组件根据当前网卡网络连接情况自动设置

netdev组件中还提供**网卡列表**用于统一管理各个网卡设备，系统中每个网卡在初始化时会创建和注册网卡对象到网卡列表中，网卡列表中有且只有一个**默认网卡**，**一般为系统中第一个注册的网卡**，也可以通过API设置默认网卡

默认网卡的主要作用：确定优先使用的进行网络通讯的网卡类型，方便网卡的切换和网卡信息的获取

## 开启网卡组件

当我们使用 netdev 组件时需要在 `rtconfig.h` 中定义如下宏定义：

| **宏定义**                | **描述**                     |
| ------------------------- | ---------------------------- |
| RT_USING_NETDEV           | 开启 netdev 功能             |
| NETDEV_USING_IFCONFIG     | 开启 ifconfig 命令支持       |
| NETDEV_USING_PING         | 开启 ping 命令支持           |
| NETDEV_USING_NETSTAT      | 开启 netstat 命令支持        |
| NETDEV_USING_AUTO_DEFAULT | 开启默认网卡自动切换功能支持 |

或直接在RTT Studio中的【RT-Thread Settings】-【更多配置】-【网络】-【网络接口设备】-【使能网络接口设备】中勾选相关选项

也可以通过ENV工具通过以下路径进行配置

```c
RT-Thread Components  --->
    Network  --->
        Network interface device  --->
        [*] Enable network interface device
        [*]   Enable ifconfig features
        [*]   Enable ping features
        [*]   Enable netstat features
        [*]   Enable default netdev automatic change features
```

开启组件后还需要调用头文件才能使用相关API，如下所示

```c
#include <arpa/inet.h> /* 包含 ip_addr_t 等地址相关的头文件 */
#include <netdev.h> /* 包含全部的 netdev 相关操作接口函数 */
```

## 网卡组件的使用

### 网卡设备注册和注销

每一个网卡在初始化完成之后，需要调用以下API注册网卡到网卡列表中

一般**该函数不需要用户调用**，一般网卡驱动初始化完成后会自动调用

```c
int netdev_register(struct netdev *netdev,//网卡结构体对象句柄
                    const char *name,//设备名
                    void *user_data);//用户数据
```

可以使用以下API注销网卡设备

```c
int netdev_unregister(struct netdev *netdev);
```

### 配置网卡和获取网卡信息

1. 可以使用以下API获取与传入状态参数匹配的网卡

```c
struct netdev *netdev_get_first_by_flags(uint16_t flags);
```

flag为指定匹配的状态

可用参数如下所示

```c
NETDEV_FLAG_UP //网卡是否启用（up状态）
NETDEV_FLAG_LINK_UP //网卡是否连接内网（link_up状态）
NETDEV_FLAG_INTERNET_UP //网卡是否连接外网
NETDEV_FLAG_DHCP //网卡是否开启DHCP功能
```

2. 使用以下API获取网卡列表中第一个网卡对象（一般是**默认网卡**）

```c
struct netdev *netdev_get_by_family(int family);
```

family为协议簇类型

可用参数如下

```c
AF_INET //lwIP协议栈
AF_AT //AT Socket协议栈
AF_WIZ //WIZnet TCP/IP硬件协议栈
```

该函数主要用于指定协议簇网卡操作，以及多网卡环境下，同协议簇网卡之间的切换的情况

3. 使用以下API通过IP地址获取网卡对象

每个网卡中都会包含该网卡的基本信息，包括IP地址、网关、子网掩码等，所以这个API是通用的

```c
struct netdev *netdev_get_by_ipaddr(ip_addr_t *ip_addr);
```

*该函数主要用于bind函数绑定指定IP地址时获取网卡状态信息的情况*

可以通过`inet_aton()`函数将IP地址从字符串格式转化为ip_addr_t类型

4. 使用以下API通过名称获取网卡对象

```c
struct netdev *netdev_get_by_name(const char *name);
```

当前网卡列表中名称可通过 `ifconfig` 命令在FinSH中查看

5. 使用以下API切换默认网卡

```c
void netdev_set_default(struct netdev *netdev);
```

6. 设置网卡up/down状态（是否启用）

```c
int netdev_set_up(struct netdev *netdev);//启用网卡
int netdev_set_down(struct netdev *netdev);//禁用网卡
```

禁用网卡之后，该网卡上对应的 Socket 套接字将无法进行数据通讯，并且将无法在该网卡上创建和绑定Socket套接字，直到网卡状态设置为up状态

7. 设置网卡DHCP功能状态

```c
int netdev_dhcp_enabled(struct netdev *netdev,//网卡结构体对象句柄
                        rt_bool_t is_enabled);//是否启用DHCP
```

如果开启该网卡DHCP功能将无法设置该网卡 IP 、网关和子网掩码地址等信息，网卡会自行通过DHCP获得IP；如果关闭该功能则可以设置上述信息

注意：==部分网卡不支持设置 DHCP 状态功能，如 M26、EC20 等 GRPS 模块，在调用该函数时会报错提示==

8. 设置网卡地址信息

```c
/* 设置网卡 IP 地址 */
int netdev_set_ipaddr(struct netdev *netdev,//网卡结构体对象句柄
                      const ip_addr_t *ipaddr);//IP地址

/* 设置网卡网关地址 */
int netdev_set_gw(struct netdev *netdev,//网卡结构体对象句柄
                  const ip_addr_t *gw);//网关地址

/* 设置网卡子网掩码地址 */
int netdev_set_netmask(struct netdev *netdev,//网卡结构体对象句柄
                       const ip_addr_t *netmask);//子网掩码

/* 设置网卡DNS服务器地址 */
int netdev_set_dns_server(struct netdev *netdev,//网卡结构体对象句柄
                          uint8_t dns_num,//需要设置的DNS服务器
                          const ip_addr_t *dns_server);//需要设置的DNS服务器地址
```

注意：==设置 IP地址、网关和子网掩码时，需要确定当前网卡 DHCP 状态，只有当网卡 DHCP 状态关闭时才可以设置==

8. 设置网卡回调函数

**状态回调函数在网卡状态改变时被调用**，**地址回调函数在网卡地址改变时被调用**，可以**使用状态机来处理网卡状态**

```c
/* 状态回调函数 */
void netdev_set_status_callback(struct netdev *netdev,
                                netdev_callback_fn status_callback);//回调函数

/* 地址回调函数 */
void netdev_set_addr_callback(struct netdev *netdev,
                              netdev_callback_fn addr_callback)//回调函数
```

回调函数需要用以下形式定义

```c
typedef void (*netdev_callback_fn)(struct netdev *netdev, enum netdev_cb_type type);
```

9. 获取网卡信息

```c
#define netdev_is_up(netdev)//判断网卡是否为 up 状态
#define netdev_is_link_up(netdev)//判断网卡是否为 link_up 状态
#define netdev_is_internet_up(netdev)//判断网卡是否为 internet_up 状态
#define netdev_is_dhcp_enable(netdev)//判断网卡 DHCP 功能是否开启
```

### 默认网卡自动化切换

在menuconfig中配置开启如下选项，可使能默认网卡自动切换功能：

```c
[*]   Enable default netdev automatic change features
```

也可以在RTT Studio中进行可视化操作

【摘自官网】多网卡模式下，如果开启默认网卡自动切换功能，当前默认网卡状态改变为 down 或 link_down 时，默认网卡会切换到网卡列表中第一个状态为 up 和 link_up 的网卡。这样可以使一个网卡断开后快速切换到另一个可用网卡，简化用户应用层网卡切换操作

## 可用的FinSH指令

和linux下用shell工具一样

```shell
ping www.fsf.org

ifconfig

dns #目前每个网卡只同时支持 2 个 DNS 服务器地址

netstat
```

# 套接字网络抽象层

RTT提供了一套SAL（Socket Abstract Layer套接字抽象层）组件

SAL组件完成对不同网络协议栈或网络实现接口的抽象并对上层提供一组标准的BSD Socket API，开发者只需要关心和使用网络应用层提供的网络接口，而无需关心底层具体网络协议栈类型和实现

特点如下

* 抽象、统一多种网络协议栈接口
* 提供Socket层面的TLS加密传输特性
* 支持标准的BSD Socket API
* 统一的FD管理，可使用read/write 、poll/select来操作网络功能

下面是RTT的网络结构框架（再 放 送）

  ![网络框架图](https://www.rt-thread.org/document/site/programming-manual/sal/figures/network_frame.jpg)

终于能讲一下这玩意了（毕竟官网只在这有讲解，这叫遵循原著）

BSD 网络应用层，提供一套标准 BSD Socket API，写应用程序就和这玩意打交道，他是第一层封装

SAL 套接字抽象层用于适配下层不同的网络协议栈，并提供给上层统一的网络编程接口，他是第二层封装

netdev 网卡层，用于解决多网卡情况设备网络连接和网络管理相关问题，这一层通过上面讲的网卡结构体对象和API把底层的各种传输协议都封装起来了，它是第三层封装

协议栈层目前包括三个部分，以后如果RTT加入了新的协议栈则会得到扩充，包括嵌入式开发中常用的轻型TCP/IP协议栈lwIP、传统TCP/IP、AT指令适配的协议等，这一层会直接和底层硬件接触，通过操作寄存器/使用外设来控制网络器件

**RTT的网络应用层提供的接口主要以标准BSD Socket API为主**，可移植性较好

## 工作原理

### 多协议栈接入与接口函数统一抽象功能

目前SAL组件支持的协议栈或网络实现类型有：**lwIP 协议栈**、**AT Socket 协议栈**、**WIZnet 硬件 TCP/IP 协议栈**，组件在socket创建时通过**判断传入的协议簇（domain）类型来判断使用的协议栈或网络功能**，完成多协议的接入与使用

标准BSD Socket API中使用以下API创建套接字Socket

```c
int socket(int domain,//协议域，又称协议簇，用于判断使用哪种协议栈或网络实现
           int type,
           int protocol);
```

套接字：**对网络中不同主机上的应用进程之间进行双向通信的端点的抽象，一个套接字就是网络上进程通信的一端，提供了应用层进程利用网络协议交换数据的机制，它是TCP/IP协议通信的基本单元**

==当服务器监听的端口有连接请求发来而服务器选择接收连接时，这个端口被移除出监听队列而在这个端口上建立新的套接字==

domain有如下取值

```c
AF_AT//AT Socket 协议栈
AF_INET//lwIP 协议栈
AF_WIZ//WIZnet 协议栈
```

SAL组件中对于每个协议栈或者网络实现提供两种协议簇类型匹配方式：**主协议簇类型和次协议簇类型**；socket 创建时先判断传入协议簇类型是否存在已经支持的主协议类型，如果是则使用对应协议栈或网络实现，如果不是则判断次协议簇类型是否支持

目前系统支持协议簇类型如下：


> lwIP 协议栈： family = AF_INET、sec_family = AF_INET
> AT Socket 协议栈： family = AF_AT、sec_family = AF_INET
> WIZnet 硬件 TCP/IP 协议栈： family = AF_WIZ、sec_family = AF_INET

调用SAL组件API的示例如下：

```c
/*
connect：SAL 组件对外提供的抽象的 BSD Socket API，用于统一 fd 管理
sal_connect：SAL 组件中 connect 实现函数，用于调用底层协议栈注册的 operation 函数
lwip_connect：底层协议栈提供的层 connect 连接函数，在网卡初始化完成时注册到 SAL 组件中，是最终调用的操作函数
*/

//这部分应该在用户程序中
/* SAL 组件为应用层提供的标准 BSD Socket API - connect*/
int connect(int s, const struct sockaddr *name, socklen_t namelen)
{
    /* 获取 SAL 套接字描述符 */
    int socket = dfs_net_getsocket(s);
    /* 通过 SAL 套接字描述符执行 sal_connect 函数 */
    return sal_connect(socket, name, namelen);
}

//这部分应该在SAL实现中
/* SAL 组件抽象函数接口实现 */
int sal_connect(int socket, const struct sockaddr *name, socklen_t namelen)
{
    struct sal_socket *sock;
    struct sal_proto_family *pf;
    int ret;

    /* 检查 SAL socket 结构体是否正常 */
    SAL_SOCKET_OBJ_GET(sock, socket);

    /* 检查当前 socket 网络连接状态是否正常  */
    SAL_NETDEV_IS_COMMONICABLE(sock->netdev);
    /* 检查当前 socket 对应的底层 operation 函数是否正常  */
    SAL_NETDEV_SOCKETOPS_VALID(sock->netdev, pf, connect);

    /* 执行底层注册的 connect operation 函数 */
    ret = pf->skt_ops->connect((int) sock->user_data, name, namelen);
#ifdef SAL_USING_TLS
    if (ret >= 0 && SAL_SOCKOPS_PROTO_TLS_VALID(sock, connect))
    {
        if (proto_tls->ops->connect(sock->user_data_tls) < 0)
        {
            return -1;
        }
        return ret;
    }
#endif
    return ret;
}

//这部分应该在SAL实现中
/* lwIP 协议栈函数底层 connect 函数实现 */
int lwip_connect(int socket, const struct sockaddr *name, socklen_t namelen)
{
    ...
}
```

### SAL TLS加密传输功能

#### 基础网络知识讲解（摘自官方文档）

在 TCP、UDP等协议数据传输时，由于数据包是明文的，所以很可能被其他人拦截并解析出信息，这给信息的安全传输带来很大的影响。为了解决此类问题，一般需要用户在应用层和传输层之间添加 SSL/TLS 协议

TLS（Transport Layer Security传输层安全协议）是建立在传输层TCP之上的协议，其前身是SSL（Secure Socket Layer安全套接字层），主要作用是将应用层的报文进行非对称加密后再由 TCP 协议进行传输，实现了数据的加密安全交互

目前常用的 TLS 方式有**MbedTLS、OpenSSL、s2n**等，但是对于不同的加密方式，**需要使用其指定的加密接口和流程进行加密**，对于部分应用层协议的移植较为复杂；

因此，SAL TLS的主要作用是**提供 Socket 层面的 TLS 加密传输特性，抽象多种 TLS 处理方式，提供统一的接口用于完成 TLS 数据交互**

#### 使用方式

1. 配置开启任意网络协议栈支持
2. 配置开启 MbedTLS 软件包（目前RTT只支持MbedTLS类型加密方式）
3. 配置开启SAL_TLS功能支持

配置完成之后，只要在 socket 创建时传入的 protocol类型使用**PROTOCOL_TLS**或**PROTOCOL_DTLS**，即可使用标准BSD Socket API接口，完成TLS连接的建立和数据的收发

示例代码如下所示

```c
#include <stdio.h>
#include <string.h>

#include <rtthread.h>

#include <sys/socket.h> 
#include <netdb.h>//要include这两个头文件才能使用网络组件

/* RT-Thread 官网，支持TLS功能 */
#define SAL_TLS_HOST    "www.rt-thread.org"
#define SAL_TLS_PORT    443
#define SAL_TLS_BUFSZ   1024

//发送request
static const char *send_data = "GET /download/rt-thread.txt HTTP/1.1\r\n"
    "Host: www.rt-thread.org\r\n"
    "User-Agent: rtthread/4.0.1 rtt\r\n\r\n";

void sal_tls_test(void)
{
    int ret, i;
    char *recv_data;
    struct hostent *host;
    int sock = -1, bytes_received;
    struct sockaddr_in server_addr;

    /* 传入url通过函数获得host地址（如果是域名，会自动做域名解析） */
    host = gethostbyname(SAL_TLS_HOST);

    recv_data = rt_calloc(1, SAL_TLS_BUFSZ);
    if (recv_data == RT_NULL)
    {
        rt_kprintf("No memory\n");
        return;
    }

    /* 创建一个socket，类型是SOCKET_STREAM，TCP 协议, TLS 类型 */
    if ((sock = socket(AF_INET, SOCK_STREAM, PROTOCOL_TLS)) < 0)
    {
        rt_kprintf("Socket error\n");
        goto __exit;
    }

    /* 初始化预连接的服务端地址 */
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(SAL_TLS_PORT);
    server_addr.sin_addr = *((struct in_addr *)host->h_addr);
    rt_memset(&(server_addr.sin_zero), 0, sizeof(server_addr.sin_zero));

    if (connect(sock, (struct sockaddr *)&server_addr, sizeof(struct sockaddr)) < 0)
    {
        rt_kprintf("Connect fail!\n");
        goto __exit;
    }

    /* 发送数据到 socket 连接 */
    ret = send(sock, send_data, strlen(send_data), 0);
    if (ret <= 0)
    {
        rt_kprintf("send error,close the socket.\n");
goto __exit;//注意这里因为发送失败而跳转到了最后的标签进行处理----------------------------------------
    }

    /* 接收响应的数据，使用加密数据传输 */
    bytes_received = recv(sock, recv_data, SAL_TLS_BUFSZ  - 1, 0);
    if (bytes_received <= 0)
    {
        rt_kprintf("received error,close the socket.\n");
        goto __exit;
    }

    /* 打印获得的数据 */
    rt_kprintf("recv data:\n");
    for (i = 0; i < bytes_received; i++)
    {
        rt_kprintf("%c", recv_data[i]);
    }

__exit://这里是跳转到的标签----------------------------------------------------------------------
    if (recv_data)
        rt_free(recv_data);
    if (sock >= 0)
        closesocket(sock);
}
```

## 开启与初始化

### 开启SAL组件

当我们使用 SAL 组件时需要在 rtconfig.h 中定义如下宏定义：

| **宏定义**      | **描述**                                                     |
| --------------- | ------------------------------------------------------------ |
| RT_USING_SAL    | 开启 SAL 功能                                                |
| SAL_USING_LWIP  | 开启 lwIP 协议栈支持                                         |
| SAL_USING_AT    | 开启 AT Socket 协议栈支持                                    |
| SAL_USING_TLS   | 开启 SAL TLS 功能支持                                        |
| SAL_USING_POSIX | 开启 POSIX 文件系统相关函数支持，如 read、write、select/poll 等 |

ENV 工具中具体配置路径如下：

```c
RT-Thread Components  --->
    Network  --->
        Socket abstraction layer  --->
        [*] Enable socket abstraction layer
            protocol stack implement --->
            [ ] Support lwIP stack 
            [ ] Support AT Commands stack
            [ ] Support MbedTLS protocol
        [*]    Enable BSD socket operated by file system API
```

配置完成可以通过 scons 命令重新生成功能，完成 SAL 组件的添加

或使用RTT Studio进行可视化配置

注意：==系统中开启SAL需要至少开启一种协议栈支持==

### 初始化SAL组件

如果程序中已经使用了组件自动初始化，则不再需要额外进行单独的初始化，否则需要在初始化任务中调用如下函数进行初始化

```c
int sal_init(void);
```

该初始化函数主要是对SAL组件进行初始化，支持组件重复初始化判断，完成对组件中使用的互斥锁等资源的初始化；**SAL组件中没有创建新的线程**，资源占用极小：目前**SAL 组件资源占用为 ROM 2.8K 和 RAM 0.6K**

## BSD Socket API简介

### 创建、关闭、设置、获取套接字和套接字信息

```c
//创建
int socket(int domain,///协议簇类型
           int type,//协议类型
           int protocol);//实际使用的传输层协议

//直接关闭
int closesocket(int s);//用于关闭连接，释放资源

//按设置关闭
int shutdown(int s, int how);

//设置套接字选项
//该函数用于设置套接字模式，修改套接字配置选项
int setsockopt(int s,//套接字描述符
               int level,//协议栈配置选项
               int optname,//需要设置的选项名
               const void *optval,//设置选项值的缓冲区地址
               socklen_t optlen);//设置选项值的缓冲区长度

//获取套接字选项
int getsockopt(int s,//套接字描述符
               int level,//协议栈配置选项
               int optname,//需要设置的选项名
               void *optval,//设置选项值的缓冲区地址
               socklen_t *optlen);//设置选项值的缓冲区长度地址

//获取远端地址信息
///该函数用于获取与套接字相连的远端地址信息
int getpeername(int s,//套接字描述符
                struct sockaddr *name,//接收信息的地址结构体指针
                socklen_t *namelen);//接收信息的地址结构体长度

//获取本地地址信息
int getsockname(int s,//套接字描述符
                struct sockaddr *name,//接收信息的地址结构体指针
                socklen_t *namelen);//接收信息的地址结构体长度

//配置套接字参数
int ioctlsocket(int s,//套接字描述符
                long cmd,//套接字操作命令
                void *arg);//操作命令所带参数
//cmd支持命令 FIONBIO：开启或关闭套接字的非阻塞模式，arg 参数 1 为开启非阻塞，0 为关闭非阻塞
```

可用的设置参数如下

```c
# domain
AF_INET //IPv4
AF_INET6 //IPv6
    
# type
SOCK_STREAM //流套接字
SOCK_DGRAM //数据报套接字
SOCK_RAW //原始套接字

# how 套接字控制的方式
0 //停止接收当前数据并拒绝以后的数据接收（直接ban掉）
1 //停止发送数据并丢弃未发送的数据（直接挂掉）
2 //停止接收和发送数据（断开连接）
    
# level 协议栈配置选项（要配置哪一层）
SOL_SOCKET //套接字层
IPPROTO_TCP //TCP层
IPPROTO_IP //IP层
    
# optname 需要设置的选项名
SO_KEEPALIVE //设置保持连接选项
SO_RCVTIMEO //设置套接字数据接收超时
SO_SNDTIMEO //设置套接数据发送超时
```

### 绑定、监听套接字

1. 绑定套接字

```c
int bind(int s,//套接字描述符
         const struct sockaddr *name,//指向sockaddr结构体的指针，代表要绑定的地址
         socklen_t namelen);//sockaddr结构体的长度
```

该函数用于将端口号和 IP 地址绑定带指定套接字上

注意：SAL组件依赖于netdev组件，当使用bind()函数时，可以*通过netdev网卡名称获取网卡对象中IP地址信息（上面提到过）*，用于将创建的Socket套接字绑定到指定的网卡对象，使用如下接口

```c
struct netdev *netdev_get_by_ipaddr(ip_addr_t *ip_addr);
```

使用例：

```c
#include <rtthread.h>
#include <arpa/inet.h>
#include <netdev.h>

#define SERVER_HOST   "192.168.1.123"//要绑定的地址
#define SERVER_PORT   1234//端口号

static int bing_test(int argc, char **argv)
{
    struct sockaddr_in client_addr;
    struct sockaddr_in server_addr;
    struct netdev *netdev = RT_NULL; 
    int sockfd = -1;

    if (argc != 2)
    {
        rt_kprintf("bind_test [netdev_name]  --bind network interface device by name.\n");
        return -RT_ERROR;
    }

    /* 通过名称获取 netdev 网卡对象 */
    netdev = netdev_get_by_name(argv[1]);//这个常用API---------------------------------<<<
    if (netdev == RT_NULL)
    {
        rt_kprintf("get network interface device(%s) failed.\n", argv[1]);
        return -RT_ERROR;
    }

    if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
        rt_kprintf("Socket create failed.\n");
        return -RT_ERROR;
    }

    /* 初始化需要绑定的客户端地址 */
    client_addr.sin_family = AF_INET;
    client_addr.sin_port = htons(8080);
    /* 获取网卡对象中 IP 地址信息 */
    client_addr.sin_addr.s_addr = netdev->ip_addr.addr;
    rt_memset(&(client_addr.sin_zero), 0, sizeof(client_addr.sin_zero));

    if (bind(sockfd, (struct sockaddr *)&client_addr, sizeof(struct sockaddr)) < 0)
    {
        rt_kprintf("socket bind failed.\n");
        closesocket(sockfd);
        return -RT_ERROR;
    }
    rt_kprintf("socket bind network interface device(%s) success!\n", netdev->name);

    /* 初始化预连接的服务端地址 */
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(SERVER_PORT);
    server_addr.sin_addr.s_addr = inet_addr(SERVER_HOST);
    rt_memset(&(server_addr.sin_zero), 0, sizeof(server_addr.sin_zero));

    /* 连接到服务端 */
    if (connect(sockfd, (struct sockaddr *)&server_addr, sizeof(struct sockaddr)) < 0)
    {
        rt_kprintf("socket connect failed!\n");
        closesocket(sockfd);
        return -RT_ERROR;
    }
    else
    {
        rt_kprintf("socket connect success!\n");
    }

    /* 关闭连接 */
    closesocket(sockfd);
    return RT_EOK;
}
```

connect()这个接口会在下面提到

2. 监听套接字

```c
int listen(int s,//套接字描述符
           int backlog);//一次能够等待的最大连接数目
```

该函数用于TCP服务器监听指定套接字连接

### 接收、建立连接

```c
/* 接收连接 */
int accept(int s,//套接字描述符
           struct sockaddr *addr,//客户端设备地址结构体
           socklen_t *addrlen);//客户端设备地址结构体的长度
```

当应用程序监听来自其他主机的连接时，使用 `accept()` 函数初始化连接，`accept()` **为每个连接创立新的套接字并从监听队列中移除这个连接**

```c
/* 建立连接 */
int connect(int s,//套接字描述符
            const struct sockaddr *name,//服务器设备地址结构体
            socklen_t namelen);//服务器设备地址结构体的长度
```

该函数用于建立与指定socket的连接

### 发送、接收TCP数据

```c
int send(int s, const void *dataptr, size_t size, int flags);//发送
int recv(int s, void *mem, size_t len, int flags);//接收
```

s表示套接字描述符

dataptr为发送的数据指针；mem为接收的数据指针

size为发送的数据长度；len为接收的数据长度

flags为标志，一般设为0

### 发送、接收UDP数据

```c
/* 发送 */
int sendto(int s,//套接字描述符
           const void *dataptr,//发送的数据指针
           size_t size,//发送的数据长度
           int flags,//标志，一般为0
           const struct sockaddr *to,//目标地址结构体指针
           socklen_t tolen);//目标地址结构体长度

/* 接收 */
int recvfrom(int s,//套接字描述符
             void *mem,//接收的数据指针
             size_t len,//接收的数据长度
             int flags,//标志，一般为0
             struct sockaddr *from,//接收地址结构体指针
             socklen_t *fromlen);//接收地址结构体长度
```

## 网络协议栈的接入方式

网络协议栈或网络功能实现的接入，主要是对协议簇结构体的初始化和注册处理, 并且添加到 SAL 组件中协议簇列表中

协议簇结构体如下所示

```c
struct sal_socket_ops
{
    int (*socket)     (int domain, int type, int protocol);
    int (*closesocket)(int s);
    int (*bind)       (int s, const struct sockaddr *name, socklen_t namelen);
    int (*listen)     (int s, int backlog);
    int (*connect)    (int s, const struct sockaddr *name, socklen_t namelen);
    int (*accept)     (int s, struct sockaddr *addr, socklen_t *addrlen);
    int (*sendto)     (int s, const void *data, size_t size, int flags, const struct sockaddr *to, socklen_t tolen);
    int (*recvfrom)   (int s, void *mem, size_t len, int flags, struct sockaddr *from, socklen_t *fromlen);
    int (*getsockopt) (int s, int level, int optname, void *optval, socklen_t *optlen);
    int (*setsockopt) (int s, int level, int optname, const void *optval, socklen_t optlen);
    int (*shutdown)   (int s, int how);
    int (*getpeername)(int s, struct sockaddr *name, socklen_t *namelen);
    int (*getsockname)(int s, struct sockaddr *name, socklen_t *namelen);
    int (*ioctlsocket)(int s, long cmd, void *arg);
#ifdef SAL_USING_POSIX
    int (*poll)       (struct dfs_fd *file, struct rt_pollreq *req);
#endif
};

/* sal network database name resolving */
struct sal_netdb_ops
{
    struct hostent* (*gethostbyname)  (const char *name);
    int             (*gethostbyname_r)(const char *name, struct hostent *ret, char *buf, size_t buflen, struct hostent **result, int *h_errnop);
    int             (*getaddrinfo)    (const char *nodename, const char *servname, const struct addrinfo *hints, struct addrinfo **res);
    void            (*freeaddrinfo)   (struct addrinfo *ai);
};

/* 协议簇结构体定义 */
struct sal_proto_family
{
    int family;                                  /* 主协议簇类型 */
    int sec_family;                              /* 次协议簇类型 */
    const struct sal_socket_ops *skt_ops;        /* socket相关执行函数，每种协议簇都有不同的实现 */
    const struct sal_netdb_ops *netdb_ops;       /* 非socket相关执行函数，每种协议簇都有不同的实现 */
};
```

AT Socket 网络实现的接入注册流程示例如下（摘自官网）

```c
#include <rtthread.h>
#include <netdb.h>
#include <sal.h>            /* SAL 组件结构体存放头文件 */
#include <at_socket.h>      /* AT Socket 相关头文件 */
#include <af_inet.h>       

#include <netdev.h>         /* 网卡功能相关头文件 */

#ifdef SAL_USING_POSIX
#include <dfs_poll.h>       /* poll 函数实现相关头文件 */
#endif

#ifdef SAL_USING_AT

/* 自定义的 poll 执行函数，用于 poll 中处理接收的事件 */
static int at_poll(struct dfs_fd *file, struct rt_pollreq *req)
{
    int mask = 0;
    struct at_socket *sock;
    struct socket *sal_sock;

    sal_sock = sal_get_socket((int) file->data);
    if(!sal_sock)
    {
        return -1;
    }

    sock = at_get_socket((int)sal_sock->user_data);
    if (sock != NULL)
    {
        rt_base_t level;

        rt_poll_add(&sock->wait_head, req);

        level = rt_hw_interrupt_disable();
        if (sock->rcvevent)
        {
            mask |= POLLIN;
        }
        if (sock->sendevent)
        {
            mask |= POLLOUT;
        }
        if (sock->errevent)
        {
            mask |= POLLERR;
        }
        rt_hw_interrupt_enable(level);
    }

    return mask;
}
#endif

/* 定义和赋值 Socket 执行函数，SAL 组件执行相关函数时调用该注册的底层函数 */
static const struct proto_ops at_inet_stream_ops =
{
    at_socket,
    at_closesocket,
    at_bind,
    NULL,
    at_connect,
    NULL,
    at_sendto,
    at_recvfrom,
    at_getsockopt,
    at_setsockopt,
    at_shutdown,
    NULL,
    NULL,
    NULL,

#ifdef SAL_USING_POSIX
    at_poll,
#else
    NULL,
#endif /* SAL_USING_POSIX */
};

static const struct sal_netdb_ops at_netdb_ops = 
{
    at_gethostbyname,
    NULL,
    at_getaddrinfo,
    at_freeaddrinfo,
};

/* 定义和赋值 AT Socket 协议簇结构体 */
static const struct sal_proto_family at_inet_family =
{
    AF_AT,
    AF_INET,
    &at_socket_ops,
    &at_netdb_ops,
};

/* 用于设置网卡设备中协议簇相关信息 */
int sal_at_netdev_set_pf_info(struct netdev *netdev)
{
    RT_ASSERT(netdev);

    netdev->sal_user_data = (void *) &at_inet_family;
    return 0;
}

#endif /* SAL_USING_AT */
```