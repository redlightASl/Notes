# MobileNet的原理与PyTorch实现

Mobilenet和ShuffleNet是目前应用比较广泛的两种轻量级卷积神经网络，轻量级网络参数少、计算量小、推理时间短，更适用于存储空间和功耗受限的边缘端和嵌入式平台。其中ShuffleNet是Face++在2017提出的轻量级网络，通过引入**group和Channel Shuffle**操作来让神经网络运算量大大减小。MobileNet是谷歌团队在同年提出的专注于移动端或者嵌入式设备中的轻量级CNN网络，提出了**Inverted Residual Block**结构，在此基础上能大大降低卷积层的消耗。二者的核心目标都是**在尽可能减小准确率损失的条件下大量减少参数与运算量**。到目前为止，MobileNet已经出现了三个版本，MobileNetv1、v2、v3；ShuffleNet也出现了两个版本：v1和v2。

由于MobileNetv2版本中也借鉴ShuffleNet使用了group操作，所以这里主要基于MobileNet介绍其结构和PyTorch官方实现（v2版本）

> MobileNetv2已经被官方收录到PyTorch库中，可以直接调用；MobileNetv3还只有一个简单的个人实现。二者的GitHub仓库如下：
>
> * V2：https://github.com/pytorch/vision/blob/6db1569c89094cf23f3bc41f79275c45e9fcb3f3/torchvision/models/mobilenet.py#L77
> * V3：https://github.com/xiaolai-sqlai/mobilenetv3/blob/adc0ca87e1dd8136cd000ae81869934060171689/mobilenetv3.py#L75

## MobileNetv2















## MobileNetv3









