# 基于PyTorch部署YOLO算法





## YOLO算法原理简介











## ultralytics的YOLOv5实现









### 配环境和模型训练

本篇重点在于把YOLO部署在各种设备上，因此仅对环境配置简述

> 需要声明：在算力受限的硬件设备上部署YOLOv5是很nt的，如果想要在MCU上部署算法请选择YOLOv3及以下，或者使用专用算法抑或是YOLOX-tiny这样的魔改版YOLO算法
>
> 下面的配置步骤适用于ultralytics的其他YOLO实现

















## 将YOLO部署到硬件设备









### 带GPU的平台（Desktop或Nvidia Jetson系列）









### 带NPU的平台（K210）











### 算力充足的SoC平台（树莓派）











### 算力不足的MCU平台（STM32）











### 具有硬件加速的其他平台（FPGA）







