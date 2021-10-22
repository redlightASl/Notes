==**本系列博文主要根据开源的[thorough-pytorch](https://github.com/datawhalechina/thorough-pytorch)项目编写（照抄），感谢datawhalechina团队的dalao们分享学习经验**==

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

**几何代数**中定义的**张量（Tensor）**是基于向量和矩阵的推广——标量是零阶张量，矢量是一阶张量，矩阵是二阶张量——张量是一个可用来表示在一些矢量、标量和其他张量之间的线性关系的多线性函数，比较数学的说法是“线性算子”

更广义的张量就包括RGB图片、文本数据乃至股价等数据

**计算机**学意义下，**张量**是现代机器学习的基础，它的核心是一个数据容器，多数情况下，它包含数字，有时候它也包含字符串，但这种情况比较少

三维张量：时间序列

四维张量：图像

五维张量：视频

一个图像可以用三个独立的数据（更数学一点，可以称这些数据正交）表示，包含了它的宽度、长度、色彩通道；但在机器学习中，经常要处理不止一张图片或一篇文档，因此需要使用四维张量来描述数据，除了以上三个数据，还需要指定一个样本量。

在PyTorch中，`torch.Tensor类`是存储和变换数据的主要工具。Tensor和NumPy的多维数组非常类似，但Tensor提供GPU计算和自动求梯度等更多功能，这些使Tensor这一数据类型更加适合深度学习

直接使用数据，构造一个张量：

```python
x = torch.tensor([5.5, 3])
print(x)

# tensor([5.5000, 3.0000])
```

基于已经存在的tensor，创建一个tensor：

```python
# 创建一个新的tensor，返回的tensor默认具有相同的 torch.dtype和torch.device
x = x.new_ones(4, 3, dtype=torch.double) 
# 也可以像之前的写法 x = torch.ones(4, 3, dtype=torch.double)
print(x)
x = torch.randn_like(x, dtype=torch.float)
# 重置数据类型
print(x)
# 结果会有一样的size

# tensor([[1., 1., 1.],
#         [1., 1., 1.],
#         [1., 1., 1.],
#         [1., 1., 1.]], dtype=torch.float64)
# tensor([[ 0.2626, -0.6196,  1.0963],
#         [ 1.1366, -0.6543,  0.6040],
#         [-0.6623,  0.1115,  0.2433],
#         [ 1.1626, -2.3529, -0.9417]])
```

获取它的维度信息：

```python
print(x.size())
print(x.shape)
torch.Size([4, 3])
```

返回的torch.Size其实就是一个tuple，⽀持所有tuple的操作

还有一些常见的构造Tensor的函数：

|                                  函数 | 功能                             |
| ------------------------------------: | -------------------------------- |
|                      Tensor(**sizes*) | 基础构造函数                     |
|                        tensor(*data*) | 类似于np.array                   |
|                        ones(**sizes*) | 构造全1矩阵                      |
|                       zeros(**sizes*) | 构造零矩阵                       |
|                         eye(**sizes*) | 构造单位矩阵（对角为1，其余为0） |
|                    arange(*s,e,step*) | 从s到e，步长为step               |
|                 linspace(*s,e,steps*) | 从s到e，均匀分成step份           |
|                  rand/randn(**sizes*) | 随机构造                         |
| normal(*mean,std*)/uniform(*from,to*) | 正态分布/均匀分布                |
|                         randperm(*m*) | 随机排列                         |

### 运算

1. 加法

    ```python
    y = torch.rand(4, 3)
    
    print(x + y)
    print(torch.add(x, y))
    
    result = torch.empty(5, 3) 
    torch.add(x, y, out=result) 
    print(result)
    
    y.add_(x) 
    print(y)
    ```

2. 索引

    操作类似matlab和numpy

    ```python
    # 取第二列
    print(x[:, 1])
    
    y = x[0,:]
    y += 1
    print(y)
    print(x[0, :]) # 源tensor也被改了了
    ```

3. 改变大小

    使用`torch.view`改变一个tensor的大小或形状（排列）

    ```python
    x = torch.randn(4, 4)
    y = x.view(16)
    z = x.view(-1, 8) # -1是指这一维的维数由其他维度决定
    print(x.size(), y.size(), z.size())
    
    # torch.Size([4, 4]) torch.Size([16]) torch.Size([2, 8])
    ```

    需要注意：view()返回的新tensor会和原来的tensor共享内存——实际上view()做的正像函数名那样，让tensor“看起来”变成了用户指定的形状（原文：仅仅是改变了对这个张量的观察⻆度），但实际上

4. 广播

    当对两个形状不同的Tensor按元素运算时，可能会触发广播（broadcasting）机制：先适当复制元素使这两个Tensor形状相同后再按元素运算

     ```python
     x = torch.arange(1, 3).view(1, 2)
     print(x)
     y = torch.arange(1, 4).view(3, 1)
     print(y)
     print(x + y)
     ```

    由于 x 和 y 分别是1行2列和3行1列的矩阵，如果要计算 x + y ，那么 x 中第一行的2个元素被广播 (复制)到了第二行和第三行，⽽ y 中第⼀列的3个元素被广播(复制)到了第二列。如此就可以对2 个3行2列的矩阵按元素相加。

## PyTorch自动求导机制

PyTorch中，所有神经网络的核心是`autograd`包，它为张量上的所有操作提供自动求导机制

autograd包是一个运行时定义（define-by-run）的框架，也就是说反向传播是根据代码如何运行来决定的，并且每次迭代可以是不同的。torch.Tensor类就被包含在这个包里，通过设置它的属性`requires_grad`为`True`来追踪对于张量对象的所有操作。当完成计算后可以通过调用`backward()`，来自动计算所有的梯度，这个张量的所有梯度将会自动累加到`grad`属性

`Tensor`和`Function`互相连接生成了一个**无环图**(acyclic graph)，它编码了完整的计算历史。每个Tensor对象都有一个`grad_fn`属性，该属性引用了创建`Tensor`自身的`Function`

如果需要在未开启自动求导功能情况下计算导数，可以在`Tensor`上调用`backward()`。如果`Tensor`是一个标量（即它包含一个元素的数据），则不需要为 `backward()`指定任何参数，但是如果它有更多的元素，则需要指定一个`gradient`参数——该参数是形状匹配的张量









## 并行计算















