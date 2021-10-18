本系列博文主要根据开源的[thorough-pytorch](https://github.com/datawhalechina/thorough-pytorch)项目编写，感谢datawhalechina团队的dalao们分享学习经验

# PyTorch基础简介

**PyTorch**是由Facebook人工智能研究小组开发的一种基于**Lua**编写的Torch库的**Python实现**的**深度学习库**，目前被广泛应用于学术界和工业界，由于Caffe2（一个简单易用基于python的深度学习框架）并入了PyTorch，它的社区逐渐膨胀并开始影响到TensorFlow在深度学习应用框架领域的统治地位。*PyTorch自从提出就获得巨大的关注以及用户数量的剧增*

> 时代变了，大人
>
> 到现在为止PyTorch还是有不如别的框架的地方，但是框架只是给我们提供了轮子，让我们造汽车更加方便，最重要的还是我们个人的科学素养的提升
>
> PyTorch提供类似NumPy的接口和调试方法，这使它容易上手且方便易用

对于现在的边缘计算设备，跑一个由PyTorch实现的深度学习模型已经不是天方夜谭，而PyTorch除了能够实现深度学习模型的开发，还可以作为前向软件框架将一个完整的模型跑在嵌入式平台

最常见的嵌入式AI平台有下面几个：

* Nvidia Jetson TX2与Nvidia Jetson NX：Nvidia Jetson是老牌嵌入式AI设备之一，提供高性能的ARM Cortex-A57及以上内核，跑一个Ubuntu，再利用Cuda资源部署模型很顺滑。Nano已经很难应付一些大算力需求的模型了，因此需要使用更高端的版本

    Nvidia官方推荐使用的一般是TensorRT，但是对于PyTorch的兼容也在逐年完善

* Atlas系列：比较常见的Atlas200，华为昇腾内核，资源相对较少，但是根据学长的评价跑PyTorch还挺行的

* ASIC或FPGA：一个发展方向，硬件佬狂喜的平台。Xilinx的Pynq就能使用Zynq基于PyTorch部署AI模型，甚至可以利用硬件加速和HLS即时实现AI模型训练（虽然很拉跨）

这里是学习PyTorch可以利用的资源：

[PyTorch官方文档](https://pytorch.org/docs/stable/index.html)

[PyTorch官方社区](https://discuss.pytorch.org/)

[Pytorch-handbook](https://github.com/zergtant/pytorch-handbook)

网上的教程也都很多

## PyTorch安装

一般基于Anaconda安装PyTorch比较方便，正常的安装方法网上一大堆，但是这里面向的是硬件人，所以需要说明如何在嵌入式linux上安装PyTorch

* Jetson TX2：依旧有很多资源。[官网](https://forums.developer.nvidia.com/t/pytorch-for-jetson-version-1-9-0-now-available/72048)

    如果不嫌费事，可以直接编译源码

* 树莓派：目前只能通过编译源码实现了

    先下载源码然后切换到想用的版本

    需要注意：**树莓派不支持cuda**，所以需要设置环境变量，把cuda支持去掉

    ```shell
    export NO_CUDA=1
    export NO_DISTRIBUTED=1
    export NO_MKLDNN=1
    export NO_QNNPACK=1
    export NO_NNPACK=1
    ```

    编译前记得安装依赖

    ```shell
    sudo apt-get install libopenblas-dev cython3 libatlas-base-dev m4 libblas-dev cmake
    pip3 install -r requirements.txt 
    ```

    最后

    ```shell
    python3 setup build
    ```

    如果一切顺利就ok了；如果不行那就必须stackoverflow/google/百度/csdn找解决办法

    慢慢来罢

安装成功以后需要先验证启用cuda

```python
import torch
torch.cuda.is_available()
```

 **如果返回True那就是可以用Cuda了，如果返回False那就不能用Cuda，只能CPU跑**

**如果返回的是报错信息......查查自己的环境哪里配错了**

## 张量











## PyTorch自动求导机制











## 并行计算















