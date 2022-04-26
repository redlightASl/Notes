# OpenWrt软件配置

上一篇讲述过如何在硬件设备中部署OpenWrt并进行基础的网络使用，这里重点介绍OpenWrt的软件配置

## 配置路由器

在笔者的项目中，需要实现以下功能：

* 可以通过WAN口连接外网
* 可以通过连接互联网下载软件包
* 通过LAN口连接的设备直接可以直接在静态地址基础上建立tcp连接
* 内网设备可以通过路由器连接互联网

因此选择了对内（LAN口之间）配置为交换机模式，对外（WAN口）配置为路由器模式

通过luci界面就可以很方便地进行配置，这就是折腾OpenWrt的优势——有点折腾但不是太折腾。

基本步骤如下：

1. 重置所有端口为默认状态

2. 设置当前连接LAN口的IP地址、子网掩码等参数（192.168.0.1、255.255.255.0，老生常谈的东西）

3. 重启OpenWrt设备并确保以自己设置的LAN口ip能ping通

4. 切到“交换机”界面，如下图所示和指导进行配置

    其中Port 1、2、3、4都是LAN口，Port5是WAN口

    将第一行Port1、2、3、4都设置为**不关联**；将第一行Port5设置为**关**；将第二行Port1、2、3、4都设置为**关**；将第二行Port5设置为**不关联**；将两行的CPU（eth0）都设置为**关联**

    这是为了划分出两个VLAN，便于服务器联网

    ![image-20210929003040969](OpenWrt配置网络摄像头.assets/image-20210929003040969.png)

5. 切换到OpenWrt设置界面，调整防火墙策略，关闭所有LAN口的防火墙，只保留WAN口的防火墙；同时注意不要保留LAN口上的“桥接”

6. 设置完毕，保存退出重启即可

> 这一套操作花了我将近三天时间，从中得出最好的经验就是有图形界面的情况下千万不要去动配置文件，否则会死得很惨——天知道你什么时候就把文件改炸了——而且一定要**记得备份！记得备份！记得备份！**
>
> 同时需要注意：这个方法仅适用于连接到LAN口的设备使用静态ip并且**静态ip一定要设置在同一个网段内**，否则很容易ping不通，因为dhcp服务器会完全随机地在网段内分配ip，如果连接到的设备内部ip已经被占用，很可能会导致无法分配ip或查找不到对应ip

## 网络摄像头

如果想要在OpenWrt上搭载网络摄像头，需要提前安装一下内核驱动和软件包：

* usbutils：用于lsusb命令支持，使用它可查看USB摄像头是否已经接入
* kmod-i2c-core：IIC总线驱动，用于支持数字摄像头的SCCB总线
* kmod-video-core、kmod-video-uvc、kmod-video-videobuf2、libv4l：免驱摄像头必须安装的驱动库
* mjpg-streamer：使用该软件进行推流

如果OpenWrt版本较新，可以考虑使用luci-app-mjpg-streamer，这是mjpg-streamer的luci界面支持软件，可以更方便的在luci界面中进行mjpg-streamer的配置

连接usb摄像头（最好是免驱摄像头），使用`lsusb`，查看设备是否连接成功

使用指令 `ls /dev/`查看里面是否存在video开头的设备

修改`/etc/config/mjpg-streamer`来配置软件参数

配置完成后，只需要使用`/etc/init.d/mjpg-streamer start`运行程序就可以进行推流

默认使用设备的8080端口，ip地址根据设备地址变化，例如打开`http://192.168.1.1:8080/?action=stream`访问摄像头图像

> 项目中最后并没有采用这个方案
>
> 原因是设备硬件无法兼容Linux的摄像头内核驱动，或者说：19.04版本的驱动得不到兼容，但可以安装mjpg-streamer；14.08版本的驱动可以兼容，但是无法安装mjpg-streamer和负责串口转发的ser2net软件。为了保证设备的基本运行，不得不将摄像头转移到了另一个嵌入式linux平台，串口转发倒是挺正常的——虽然说也给我造成了很大麻烦

## 网口-串口转发

`ser2net`是一个Linux下常用的TCP-串口透传应用程序，使用`sudo apt install ser2net`即可安装

通过修改`/etc/ser2net.conf`进行配置

基本参数如下：

* **最高支持115200波特率**
* 支持tcp报文（字节）、telnet协议通讯
* 根据硬件可支持硬件流控来驱动rs485总线

在它的配置文件里头部会标注很多内容，其中参数说明就在头部注释的最后一段

```shell
#            Sets  operational  parameters  for the serial port.
#            Options 300, 1200, 2400, 4800, 9600, 19200, 38400,
#            57600, 115200 set the various baud rates.  EVEN,
#            ODD, NONE set the parity.  1STOPBIT, 2STOPBITS set
#            the number of stop bits.  7DATABITS, 8DATABITS set
#            the number of data bits.  [-]XONXOFF turns on (-
#            off) XON/XOFF support.  [-]RTSCTS turns on (- off)
#            hardware flow control, [-]LOCAL turns off (- on)
#            monitoring of the modem lines, and
#            [-]HANGUP_WHEN_DONE turns on (- off) lowering the
#            modem control lines when the connextion is done. 
#            NOBREAK disables automatic setting of the break
#            setting of the serial port.
#            The "remctl" option allow remote control (ala RFC
#            2217) of serial-port configuration.  A banner name
#            may also be specified, that banner will be printed
#            for the line.  If no banner is given, then no
#            banner is printed.
```

使用示例如下：

```shell
1234:raw:0:/dev/ttyS0:115200 8DATABITS NONE 1STOPBIT -RTSCTS -XONXOFF LOCAL
```

使用1234端口以TCP报文的形式转发ttyS0收到的串口数据，串口配置为115200波特率、8数据位、无奇偶校验位、1停止位、关闭硬件流控

之后将其添加到`/etc/rc.local`中即可实现开机自启

```shell
/sbin/ser2net -c /etc/ser2net.conf &
```

> 笔者在初次使用该程序时，为了追求效率将串口波特率拉到了921600，发现上传数据一直出错，但是一直没有怀疑是串口软件的问题，排查了将近一周才发现这个软件**不支持115200以上波特率**串口的转发
>
> 这个问题也经常被大家忽视——很多低性能设备默认串口速率较低，不会提供更高速串口的支持。如果在需要高速转发的情况下，很可能就必须要换用其他协议或者选择性地放弃部分速度
>
> 在笔者的项目里，为了节省改动时间，就直接把串口速率降低到了115200
