# Socket

Socket即**套接字**，是由UNIX系统开发的网络通信接口，该接口API被纳入了POSIX标准，所有兼容POSIX的操作系统都可以使用该系列API，所以它成为了**网络应用开发时最常用的API**

## Socket简介

Socket套接字是位于应用层和传输层之间的POSIX接口，应用程序可以直接通过Socket进行网络通信，然后由Socket将数据传递到传输层，Socket因此可以像文件一样以打开、读写、关闭的方式实现网络通信，这也是UNIX万物皆文件的思想体现。同时标准化的Socket接口使得应用程序具有良好的可移植性，目前不仅仅是Linux，一些RTOS像FreeRTOS、RT-Thread、uCOS和一些具有网络功能的SoC都实现了Socket API

需要注意：**Socket和Websocket并不是一个东西**，Socket是工作在传输控制层的应用程序接口，WebSocket则是一个应用层协议。Socket将协议簇下层的内容封装起来供上层应用程序调用；而WebSocket作为一个成熟的连接应用解决方案可以单独工作或与其他应用程序共同使用

## Socket API简介

### 创建socket描述符

根据属性设置创建Socket描述符

```c
int socket(int protofamily, int type, int protocol);
```

这个函数返回Socket描述符，这是一个int类型的数值，所有socket操作都基于描述符进行

其中protofamily表示协议簇，一般使用

* AF_INET：IPv4，使用32位IPv4地址与16位端口号组合
* AF_INET6：IPv6，使用IPv6地址与端口号组合
* AF_LOCAL（AF_UNIX）：UNIX域Socket，使用一个绝对路径作为地址
* AF_ROUTE

协议簇决定了Socket的地址类型，设置之后在通信中必须采用对应的地址

type则表示socket的类型，常用下面几种：

* SOCK_STREAM
* SOCK_DGRAM
* SOCK_RAW
* SOCK_PACKET
* SOCK_SEQPACKET

protocol表示指定使用某传输协议，常用协议包括

* IPPROTO_TCP：TCP协议
* IPPROTO_UDP：UDP协议
* IPPROTO_SCTP：SCTP协议
* IPPROTO_TIPC：TIPC协议

注意：**type和protocol不能随意组合**，当protocol为0（NULL）时会自动选择type对应的默认协议

调用该函数创建一个Socket后，返回的套接字描述符描述它存在于某个对应协议簇空间中，并没有一个具体的地址，需要使用bind函数才能赋予描述符一个地址（即端口号），否则当调用connect()、listen()等函数时操作系统会自动随机分配一个端口给套接字

### 绑定唯一端口号

每个应用程序想要使用网络功能，都要指定唯一的一个端口号，在Socket标准API中使用bind()函数为套接字绑定一个端口号，不过这个操作并不是必须的，在应用程序未使用bind指定端口号时，操作系统会自动分配一个随机的端口号

```c
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
```

函数返回int类型的指示符，如果为0则表示bind执行成功，返回`EADDRINUSE`表示端口号已被其他应用程序占用

参数中的sockfd就是通过socket()函数获得的socket描述符

addr则是指向要绑定给socket的协议地址的指针，这个地址结构体会根据地址创建socket时指定使用的地址协议簇的不同而不同：

```c
//IPv4
struct sockaddr_in {
    sa_family_t	 	sin_familt;		/* AF_INET地址协议簇 */
    in_port_t	 	sin_port; 		/* 在网络字节序中的端口 */
    struct in_addr 	sin_addr; 		/* 网络地址结构体 */
}
//其中网络地址结构体如下所示
struct in_addr sin_addr {
    uint32_t	 	s_addr; 		/* 网络地址字节序中的地址 */
}

//IPv6
struct sockaddr_in6 {
    sa_family_t	 	sin6_familt;	/* AF_INET6地址协议簇 */
    in_port_t	 	sin6_port;		/* 在网络字节序中的端口 */
    uint32_t 		sin6_flowinfo;  /* IPv6流信息 */
    uint32_t 		sin6_scope_id;  /* Scope ID */
    struct in6_addr sin6_addr;		/* 网络地址结构体 */
}
//其中网络地址结构体如下所示
struct in6_addr sin6_addr {
	unsigned char	s6_addr[16];	/* IPv6地址 */    
};

//UNIX
#define UNIX_PATH_MAX 108
struct sockaddr_un {
    sa_family_t 	sun_family;		/* AF_UNIX地址协议簇 */
    char 			sun_path[UNIX_PATH_MAX];	/* 路径名 */
}
```

其中addrlen代表地址长度，也根据地址协议簇决定

### 启动连接

客户端会使用connect()函数来启用一个Socket连接，在使用TCP时，客户端需要连接到TCP服务器，成功后才能继续通信

```c
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
```

函数返回0表示connect成功，否则返回错误码，错误码有以下几种：

* ETIMEDOUT：TCP客户端没有收到SYN分节相应
* ECONNREFUSED：服务器主机在客户端指定的端口上没有进程在等待与之连接，属于发生硬错误（hard error）
* EHOSTUNREACH或ENETUNREACH：客户端发出的SYN在中间某个路由器上引发了一个“目标地不可达”（destination unreachable）的ICMP错误，属于发生软错误（soft error）

参数中sockfd为Socket描述符，addr表示绑定给sockfd的协议地址指针，addrlen为地址长度

### 监听Socket

如果是作为服务器，在调用socket()和bind()后，会**调用listen()来监听当前Socket**，调用成功后**如果有客户端调用connect()发起连接请求，服务器就会接收到这个请求**

```c
int listen(int sockfd, int backlog);
```

函数返回0表示成功，返回-1表示出错

参数中sockfd依旧为Socket描述符

backlog表示未完成连接队列和已完成连接队列的总和的最大值

内核会给任何给定的监听Socket套接字维护两个队列（FIFO），一个是客户端已经发出连接请求，而服务器正在等待完成响应的TCP三次握手过程队列（TCP三次握手模型为了解决在不可靠信道上建立可靠连接，一个直观的例子就是——客户端请求建立传输，请确认！收到，服务器允许建立传输，请确认！收到，可以建立传输！——三次握手就是发送三次包的过程，可以有效防止错误地建立不必要的传输，不过因此会导致一定延迟，计算机为了进行三次握手要在FIFO中缓存当前握手信息，这就占用了未完成连接队列）；另一个是已经完成三次握手，连接成功的客户端队列

一般来说对于专用服务器，这个数值应该定义得较大，即使超过操作系统内核能支持的最大值也无妨，操作系统会自动将偏大值改成自身支持的最大值

### 处理连接

由服务器调用accept()函数来**处理**从已完成连接队列对头返回的**下一个已完成连接**

```c
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
```

如果服务器与客户端正确建立连接，accept()函数会返回一个全新的Socket套接字，服务器通过这个新的套接字来和客户端进行通信

里面的参数都和之前的一样，这里不再赘述

### 收发Socket网络数据

使用read和write函数族来从网络收发数据

```c
ssize_t write(int fd, const void *buf, size_t count);
ssize_t read(int fd, void *buf, size_t count);

ssize_t send(int sockfd, const void *buf, size_t len, int flags);
ssize_t recv(int sockfd, void *buf, size_t len, int flags);
    
ssize_t sendto(int sockfd, const void *buf, size_t len, 
               int flags, const struct sockaddr * dest_addr, socklen_t adrlen);
ssize_t recvfrom(int sockfd, void *buf, size_t len, 
               int flags, struct sockaddr * src_addr, socklen_t adrlen);
    
ssize_t sendmsg(int sockfd, const struct msghdr *msg, int flags);
ssize_t recvmsg(int sockfd, struct msghdr *msg, int flags);
```

read系列函数将套接字视为文件，从套接字描述符中读取内容到缓存buf，读成功时，read返回实际所读的字节数，如果返回值为0，则表示已经读到文件末尾，小于0则表示出现错误，如果错误为EINTR，说明读错误是由中断引起 ，如果是ECONNREST，表示网络连接出现问题

write系列函数将buf中的nbytes字节内容写入套接字描述符，成功时返回写的字节数；失败时返回-1，并设置errno变量。入股write返回值大于0，表示写了部分或全部数据；如果返回值小于0，则表示出现错误，如果是EINTR则表示由中断引起；如果是EPIPE，表示网络连接出现问题（对方已关闭连接）

### 关闭Socket

使用

```c
int close(int fd);
```

关闭套接字并终止TCP连接

该函数实际上的作用是将某个socket标记为已关闭并立即返回到调用进程。被关闭的描述字不能再由调用进程使用，也就是不能再作为read或write的第一个参数

