# ESP-MQTT库











## MQTT协议简介

MQTT协议是运行在TCP协议栈上的应用层协议，它是Message Queue Telemetry Transport消息队列遥测传输协议的缩写。他并不是传统的消息队列，具有如下突出特点：

* 不需要预先创建要发布的主题
* 消息如果没有被获取，不会暂留而是被直接扔掉
* 一个消息可以被多个订阅者获取，不支持指定消息被单一的客户端获取

MQTT通讯通过 **发布-订阅** 方式实现，消息的发布方和订阅方之间没有直接的连接，需要一个中间方来对消息进行转发和存储，这个中间方被称为Broker；连接到Broker的订阅方和发布方称为Client，细化下订阅方称为Subscriber、发送方称为Publisher。







### MQTT与Socket的区别

协议设计方面：

1. MQTT协议是为了物联网场景所设计工作在低带宽，为了控制设备通讯而设计的协议，而WebSocket则是为了浏览器与服务器全双工通信而设计的一种协议
2. MQTT是IBM开发的一个即时通讯协议；WebSocket是基于HTML5的一种新的协议，基于HTTP握手然后转向TCP协议，用于取代之前的Server Push、Comet、长轮询等老旧实现
3. MQTT是一个基于C-S的消息发布-订阅传输协议，MQTT协议特点就是轻量、简单、开放、易于实现，这些特点使它适用范围更广泛

应用方面：

1. WebSocket需要Web Client Application（通常是浏览器），MQTT不需要
2. WebSocket实现的是Web Client端和服务器端的长连接（即管道），节省多次握手的开销；物联网应用场景中很多应用是没有Web Client的，MQTT的接收广播的消息是通过MQTT client，而不是Web Client，所以MQTT特别适合IoT应用场景
3. MQTT保证每个消息极其小（一个MQTT control message可以只有2byte），因此节约带宽也节约了接收端的电能
4. MQTT Client和Broker之间的连接仍然是基于TCP/IP协议，但是理论上任何支持有序双向连接的网络协议都可以支持MQTT

### MQTT协议基础















