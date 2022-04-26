==**本系列博文主要根据开源的[thorough-pytorch](https://github.com/datawhalechina/thorough-pytorch)项目编写，感谢datawhalechina团队的dalao们分享学习经验**==

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

一般基于Anaconda安装PyTorch比较方便，正常的安装方法网上一大堆，但是这里面向的是硬件人，所以需要说明如何在嵌入式linux上安装PyTorch——毕竟安了PyTorch才能用训练好的模型

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

> 如果熟悉OpenCV的话会发现这里所说的张量和OpenCV中的Mat类有一定相似性

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

    需要注意：view()返回的新tensor会和原来的tensor共享内存——实际上view()做的正像函数名那样，让tensor“看起来”变成了用户指定的形状（原文：仅仅是改变了对这个张量的观察角度）

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

## 基于Cuda的运算加速

PyTorch可以通过调用Nvidia提供的Cuda接口实现运算加速，具体的方法就是将CPU中的顺序运算转换成GPU内基于Cuda核的并行运算，主要有三种方法：

* 网络分布（Network partitioning）

    将一个模型的各个部分拆分，然后将不同的部分放入到GPU来做不同任务的计算

    这个方法的缺点在于不同模型组件在不同的GPU上运算，对GPU之间的传输带宽要求高，因此现在这种方法不常用

* 层级并行（Layer-wise partitioning）

    将同一层的模型拆分，让不同GPU去训练同一层模型的部分任务

    在需要大量的训练，同步任务加重的情况下，会出现和第一种方式一样的问题

* 数据并行（Data parallelism）

    不拆分模型，但是将输入的数据拆分：同一个模型在不同GPU中*训练*一部分数据，然后再分别*计算*一部分数据后，将输出的数据汇总，然后再反向传播，整体修正模型的参数

    这种方法没有上面两个方法的缺点，是现在模型训练中比较常用的方式

目前主流的Nvidia GPU（GTX10系、RTX20、30系）都内置了Cuda核心，通过安装Cuda驱动、cuDNN（Cuda深度学习库）和python包就可以使用

Nvidia还针对嵌入式平台推出了Jetson系列SoC，集成了ARM Cortex-A处理器核心和Cuda计算单元，虽然一般不会用它训练模型，但是在模型部署以后的运算过程中还会需要大量的并行运算，使用pyTorch这个结合了训练-部署-运行的统一框架可以直接对上面的Cuda核进行调用

在开始下面的内容之前，推荐读者先去了解一些机器学习和深度学习的[基本知识](../神经网络基础概念.md)

## 深度学习与传统机器学习的区别

思考机器学习的总体实现步骤：首先**确定训练平台**和对数据进行**预处理**，包括统一数据格式和必要的数据变换，同时需要在数据集中划分出训练集和测试集。接下来**选择模型**，并**设定损失函数和优化函数**，以及对应的**超参数**。最后用模型去**拟合训练集数据**，并在验证集/测试集上计算模型表现。

深度学习和机器学习在流程上类似，但在代码实现上有较大的差异。

* **深度学习所需的样本量很大**，一次加载全部数据运行可能会超出内存容量而无法实现，同时存在批训练等提高模型表现的策略，需要每次训练读取固定数量的样本送入模型中训练，因此深度学习需要专门实现数据加载
* **深度神经网络层数往往较多**，同时会有一些用于实现特定功能的层，因此深度神经网络往往需要*“逐层”搭建*，或预定义好可以实现特定功能的模块，再把这些模块组装起来。这种模块化构建方式能够充分保证模型的灵活性，也对代码的复用性实现提出较高要求
* 由于模型设定的灵活性，因此损失函数和优化器算法必须保证反向传播能在用户自行定义的模型结构上实现
* 代码实现中，需要使用GPU运算模型和数据，这就要求数据使用显存存储；还要保证损失函数和优化器算法能够在GPU上正常工作；完成计算后还需要把结果和中间数据转移回CPU，这就涉及到很多关于GPU的配置和操作。如果使用FPGA加速的话更需要针对硬件进行有效的并行化编程以满足部署后的加速需求

深度学习中训练和验证过程最大的特点在于读入数据是按批的，每次读入一个批次的数据，放入GPU中训练，然后将损失函数反向传播回网络最前面的层，同时使用优化器调整网络参数

## PyTorch实现DNN模型

pyTorch作为一个完善的深度学习框架，配备了很多函数去实现上面所述流程中的每个步骤

由于篇幅所限，**这里只介绍到使用PyTorch实现深度神经网络模型**

### 配置环境

在开始训练前首先导入python包。

下面列出了几个常用的python包和他们的功能

```python
import os #有关操作系统API的python接口
import matplotlib #matplotlib用于数据可视化处理
import cv2 #opencv的python接口 用于顶层图像处理算法
import numpy as np #numpy用于矩阵格式的数据算法
import pandas as pd #pandas用于处理格式化数据的读写
import torch #pytorch框架
import torch.nn as nn #pytorch的神经网络框架
from torch.utils.data import Dataset, DataLoader #pytorch的数据集处理功能
import torch.optim as optimizer #pytorch的优化器框架
```

同时需要设置超参数和GPU环境，如下所示：

```python
batch_size = 16 #批大小
lr = 1e-4 #初始学习率
max_epochs = 100 #训练次数

"""GPU配置"""
os.environ['CUDA_VISIBLE_DEVICES'] = '0,1'
#使用os.environ，这种情况如果使用GPU不需要设置

device = torch.device("cuda:1" if torch.cuda.is_available() else "cpu")
#使用“device”，后续对要使用GPU的变量用.to(device)即可

"""可以设置其他环境配置"""
```

### 加载数据

PyTorch通过Dataset+Dataloader的方式完成数据加载

Dataset是定义好的数据集格式，同时也确定了数据变换的形式；Dataloader用迭代的方法的方式不断读入批次数据。

Dataset类主要包含三个函数：

- `__init__`：用于向类中传入外部参数，同时定义训练集
- `__getitem__`：逐个读取样本集合中的元素，可以进行一定的变换，并将返回训练/验证所需的数据
- `__len__`：用于返回数据集的样本数

使用如下方式构建数据集：

```python
train_dataset = datasets.ImageFolder("./trainer", transform=data_transform) #加载训练集
test_dataset = datasets.ImageFolder("./data", transform=data_transform) #加载测试集
```

这里使用了PyTorch自带的ImageFolder类，用于读取按一定结构存储的图片数据，第一个参数就描述了训练集/测试集所在目录，pytorch会从该目录中读取对应数据集进行加载；“transform”可以对图像进行一定的变换，如翻转、裁剪等操作，可自己定义

本质上读取步骤是使用python**迭代器**（iterator）完成的，因此可以直接使用next和iter方法实现

```python
import matplotlib.pyplot as plt
images, labels = next(iter(val_loader)) #与上面的代码等效
print(images.shape)
plt.imshow(images[0].transpose(1,2,0))
plt.show() 
```

如果是图片存放在一个文件夹，另有一个csv文件给出了图片名称对应的标签这种图片-标签分离的数据集吗，需要自己定义Dataset类：

```python
class MyDataset(Dataset):
    def __init__(self, data_dir, info_csv, image_list, transform=None):
        """
        Args:
            data_dir: path to image directory.
            info_csv: path to the csv file containing image indexes
                with corresponding labels.
            image_list: path to the txt file contains image names to training/validation set
            transform: optional transform to be applied on a sample.
        """
        label_info = pd.read_csv(info_csv) #使用pandas读取csv
        image_file = open(image_list).readlines()
        self.data_dir = data_dir #设置关键参数
        self.image_file = image_file
        self.label_info = label_info
        self.transform = transform

    def __getitem__(self, index):
        """
        Args:
            index: the index of item
        Returns:
            image and its labels
        """
        image_name = self.image_file[index].strip('\n') #设置文件名格式
        raw_label = self.label_info.loc[self.label_info['Image_index'] == image_name] #设置标签格式
        label = raw_label.iloc[:,0]
        image_name = os.path.join(self.data_dir, image_name) #设置文件和标签的对应
        image = Image.open(image_name).convert('RGB')
        if self.transform is not None:
            image = self.transform(image)
        return image, label

    def __len__(self):
        return len(self.image_file)
```

之后就可以照常调用函数进行加载了

```python
train_loader = torch.utils.data.DataLoader(
    			train_data, 
    			batch_size=batch_size, 
    			num_workers=4, #有多少个进程用于读取数据
    			shuffle=True, #是否将读入的数据打乱
    			drop_last=True #对于样本最后一部分没有达到批次数的样本，丢弃并不再参与训练
)

val_loader = torch.utils.data.DataLoader(
    			val_data, 
    			batch_size=batch_size, 
    			num_workers=4, 
    			shuffle=False
)
```

### 实现模型

pyTorch使用`nn`模块里提供的`Module`模型构造类，`Module`是所有神经网络模块的基类，通过继承它可以定义我们想要的模型

```python
class MLP(nn.Module):
    """构造多层感知机"""
	def __init__(self, **kwargs):
    	#创建模型参数（结构）
    	super(MLP, self).__init__(**kwargs) #调用MLP父类Block的构造函数
		self.hidden = nn.Linear(784, 256) #隐藏层
		self.act = nn.ReLU() #使用ReLu函数的激活层
		self.output = nn.Linear(256,10) #输出层
    
    def forward(self, x):
    	#定义模型的前向计算（正向传播），即如何根据输入x计算返回所需要的模型输出
		o = self.act(self.hidden(x))
		return self.output(o)
```

因为上面介绍过的pyTorch自动求导机制，MLP类中无须定义反向传播函数，框架会经由自动求梯度自动生成反向传播所需的backward 函数。

对MLP类实例化后就得到了所需的模型变量，下面的代码展示了如何使用net对象：

```python
X = torch.rand(2,784) #设置一个随机张量用于检验模型
net = MLP() #实例化
print(net)
net(X) #调用MLP继承自Module类的call函数以调用forward函数实现前向计算
```

上面的代码会返回

```python
"""
print(net)的结果：输出模型结构
"""
MLP(
  (hidden): Linear(in_features=784, out_features=256, bias=True)
  (act): ReLU()
  (output): Linear(in_features=256, out_features=10, bias=True)
)

"""
net(X)的结果：输出计算后得到的输出张量
"""
tensor([[ 0.0149, -0.2641, -0.0040,  0.0945, -0.1277, -0.0092,  0.0343,  0.0627,
         -0.1742,  0.1866],
        [ 0.0738, -0.1409,  0.0790,  0.0597, -0.1572,  0.0479, -0.0519,  0.0211,
         -0.1435,  0.1958]], grad_fn=<AddmmBackward>)
```

需要注意：**Module类是一个可以自由设置的组件，它的子类可以是层（如pytorch内置的Linear类就是这样），也可以是一个完整的模型（如这里的MLP类），还可以是模型的一个部分**

PyTorch的模型实现思路就是用Module类的子类构建完整模型

### 实现层

Module的最基础功能就是定义一个**不含模型参数的自定义层**，如下所示：

```python
class MyLayer(nn.Module):
    """自定义层"""
    def __init__(self, **kwargs):
		super(MyLayer, self).__init__(**kwargs) #调用MLP父类Block的构造函数
    
    def forward(self, x):
        """自定义的前向传播函数"""
        return x - x.mean() #x-\bar{x}
```

该自定义层设置的函数即
$$
ouput = x - \bar{x}
$$
**输入值减去均值后输出**

测试代码如下：

```python
layer = MyLayer() #实例化
layer(torch.tensor([1, 2, 3, 4, 5], dtype=torch.float)) #设置输入是一个浮点数张量
```

输入取平均得3，可以预料到会输出一个同样是5行的张量[-2,-1,0,1,2]

实际验证结果

```python
tensor([-2., -1.,  0.,  1.,  2.])
```

其中有`.`是因为输入数据类型是浮点数

进一步还可以自定义**含模型参数的自定义层**。其中的模型参数可以通过训练学出：

```python
class MyLayer_Dense(nn.Module):
    """自定义层"""
    """这里选择构建一个全连接层Dense"""
    def __init__(self):
        super(MyLayer_Dense, self).__init__()
        self.params = nn.ParameterList([nn.Parameter(torch.randn(4, 4)) for i in range(3)])
        #遍历所有参数得到一个参数列表
        self.params.append(nn.Parameter(torch.randn(4, 1)))
        #在每个参数后面追加参数

    def forward(self, x):
        #前向传播函数
        for i in range(len(self.params)):
            x = torch.mm(x, self.params[i])
        return x
    
net = MyListDense()
print(net)
```

其中使用了`Parameter`类，它是`Tensor`的子类，**如果一个Tensor被识别为Parameter，它就会被自动添加到模型的参数列表中**。在自定义含参数模型的层时应该把参数定义成Parameter，同时**可以用`ParameterList`和`ParameterDict`分别定义参数组成的列表和字典**

```python
class MyDictDense(nn.Module):
    """使用字典构建的上述全连接层"""
    def __init__(self):
        super(MyDictDense, self).__init__()
        self.params = nn.ParameterDict({
                'linear1': nn.Parameter(torch.randn(4, 4)),
                'linear2': nn.Parameter(torch.randn(4, 1))
        })
        self.params.update({'linear3': nn.Parameter(torch.randn(4, 2))}) #新增参数字典项

    def forward(self, x, choice='linear1'):
        return torch.mm(x, self.params[choice])

net = MyDictDense()
print(net)
```

### CNN中常见层的PyTorch实现

* 二维卷积层

    二维卷积层将输入和**卷积核**做**互相关运算**，并加上一个**标量偏差**来得到输出

    > 卷积的概念在这里不再介绍，如有需要可以参考之前的博文《神经网络基础概念》

    卷积层的模型参数包括了**卷积核**和**标量偏差**。训练模型时，我们通常先对卷积核随机初始化，然后通过反向传播不断迭代卷积核和偏差来让达到损失函数最小

    ```python
    def corr2d(X, K):
        """卷积运算（二维互相关运算）"""
        h, w = K.shape
        X, K = X.float(), K.float()
        Y = torch.zeros((X.shape[0] - h + 1, X.shape[1] - w + 1))
        for i in range(Y.shape[0]):
            for j in range(Y.shape[1]):
                Y[i, j] = (X[i: i + h, j: j + w] * K).sum()
        return Y
    
    class Conv2D(nn.Module):
        """二维卷积层"""
        def __init__(self, kernel_size):
            super(Conv2D, self).__init__()
            self.weight = nn.Parameter(torch.randn(kernel_size))
            self.bias = nn.Parameter(torch.randn(1))
    
        def forward(self, x):
            return corr2d(x, self.weight) + self.bias #卷积运算+标量偏差
    ```

    卷积窗口形状是$p \times q$的卷积层被称为$p \times q$卷积层，说明卷积核的高和宽分别为$p$和$q$

    下面我们大小为3x3的二维卷积层，然后设输⼊高和宽两侧的填充数**分别为1**。那么给定一个长和宽均为8的输入张量，可以发现输出的高和宽也是8

    ```python
    def comp_conv2d(conv2d, X):‘
        #定义一个函数来计算卷积层
        #它对输入和输出做相应的升维和降维
      	X = X.view((1, 1) + X.shape) #(1, 1)代表批大小和通道数
    	Y = conv2d(X) #进行卷积
    	return Y.view(Y.shape[2:]) #排除不关心的前两维（批量和通道），输出张量
    
    #注意这里是两侧分别填充1行/列，等同于在两侧一共填充2⾏或列
    conv2d = nn.Conv2d(in_channels=1, out_channels=1, kernel_size=3,padding=1)
    
    X = torch.rand(8, 8)
    comp_conv2d(conv2d, X).shape
    
    """
    输出
    torch.Size([8, 8])
    """
    ```

    当卷积核的高和宽不同时，我们也可以通过设置高和宽上不同的填充数使输出和输入具有相同的高和宽；同时也可以自行设置步幅

    总体来说，**填充可以增加输出的高和宽，步幅可以减小输出的高和宽**

    ```python
    conv2d = nn.Conv2d(1, 1, kernel_size=(3, 5), padding=(0, 1), stride=(3, 4))
    comp_conv2d(conv2d, X).shape
    
    """
    输出
    torch.Size([2, 2])
    """
    ```

* 池化层

    池化层专用于对输入数据的一个固定形状窗口（即**池化窗口**）中的元素计算输出，这里直接计算池化窗口内元素的最大值或者平均值，分别叫做**最大池化算子**或**平均池化算子**

    它通过降低特征图的分片率获得特征图里具有空间不变性的特征

    下面将实现一个二维最大池化层，池化窗口会从输入的最上方开始，按从左往右、从上往下的顺序遍历数组，当池化窗口滑动到某位置时，窗口的输入数组最大值即输出数组中相应位置的元素

    ```python
    def pool2d(X, pool_size, mode='max'):
        p_h, p_w = pool_size
        Y = torch.zeros((X.shape[0] - p_h + 1, X.shape[1] - p_w + 1))
        for i in range(Y.shape[0]):
            for j in range(Y.shape[1]):
                if mode == 'max':
                    Y[i, j] = X[i: i + p_h, j: j + p_w].max()
                elif mode == 'avg':
                    Y[i, j] = X[i: i + p_h, j: j + p_w].mean()
        return Y
    ```

### 复现论文

学习深度学习最基本的方法就是复现经典论文中的模型，并对他们进行训练验证

下面构造几个经典的模型作为本篇博文的总结

> 可以**使用nn包来构建神经网络**，实际上**它依赖于autograd包来定义模型并实现自动求导功能**，一个Module子类实现的模型总包含模型各个层的结构和一个forward(input)方法用于最终的模型输出
>
> 这就是使用PyTorch构建模型的总体思路

* **LeNet**：手写数字识别

    它的结构很简单，是经典的**前馈神经网络**，也是最早出现的CNN模型之一

    ![3.4.1](硬件人的PyTorch【基础内容】.assets/3.4.1.png)

    LeNet由7层网络组成，上图中输入的原始图像大小是32×32像素，**卷积层用Ci表示，池化层用Si表示，全连接层用Fi表示**

    根据上图来定义LeNet的网络结构：

    ```python
    import torch
    import torch.nn as nn
    import torch.nn.functional as F
    
    class Net(nn.Module):
    	"""定义LeNet类"""
        def __init__(self):
            """
            在这里定义CNN的结构和要调用的参数（占用内存空间）
            """
            super(Net, self).__init__()
            self.conv1 = nn.Conv2d(1, 6, 5) #从INPUT到C1的卷积层
            self.conv2 = nn.Conv2d(6, 16, 5) #从C1到C3的卷积层
            self.fc1 = nn.Linear(16 * 5 * 5, 120) #从S4到C5的全连接层
            self.fc2 = nn.Linear(120, 84) #从C5到F6的全连接层
            self.fc3 = nn.Linear(84, 10) #从F6到输出的全连接层
    
        def forward(self, x):
            """
            定义前向传播函数
            在这里定义具体的实现，参考上面的网络结构图即可
            """
            #先经过conv1这个卷积层C1
            #再进入ReLu激活层
            #最后经过2x2池化核的最大池化层S2
            x = F.max_pool2d(F.relu(self.conv1(x)), (2, 2))
            #与上面同理，先进入conv2代表的卷积层C3
            #通过ReLu函数激活后
            #再进入2x2池化核的最大池化层S4
            x = F.max_pool2d(F.relu(self.conv2(x)), 2)
            #通过num_flat_features除去批处理维度的其他所有维度
            #由于S4层的大小为5×5，而该层的卷积核大小也是5×5
            #因此特征图大小为(5-5+1)×(5-5+1)=1×1，该层刚好变成了全连接层同时也是卷积层C5
            x = x.view(-1, self.num_flat_features(x))
            #先通过S4到C5的全连接层fc1
            #再通过ReLu函数
            x = F.relu(self.fc1(x))
            #这是从C5到F6的全连接层fc2
            #和上面一样
            x = F.relu(self.fc2(x))
            #最后通过全连接层fc3输出
            x = self.fc3(x)
            return x
    
        def num_flat_features(self, x):
            size = x.size()[1:]  #除去批处理维度的其他所有维度
            num_features = 1
            for s in size: #全连接
                num_features *= s
            return num_features
    
    net = Net()
    print(net)
    
    """
    输出网络结构
    Net(
      (conv1): Conv2d(1, 6, kernel_size=(5, 5), stride=(1, 1))
      (conv2): Conv2d(6, 16, kernel_size=(5, 5), stride=(1, 1))
      (fc1): Linear(in_features=400, out_features=120, bias=True)
      (fc2): Linear(in_features=120, out_features=84, bias=True)
      (fc3): Linear(in_features=84, out_features=10, bias=True))
    """
    ```

    一个模型的可学习参数可以通过`net.parameters()`返回

    ```python
    params = list(net.parameters())
    print(len(params))
    print(params[0].size())  #conv1的权重
    
    """
    输出
    10
    torch.Size([6, 1, 5, 5])
    """
    ```

    注意：**LeNet的输入是32x32的张量（图像矩阵）。如果使用MNIST数据集来训练这个网络，要提前把图片大小重新调整到32x32**

    ```python
    input = torch.randn(1, 1, 32, 32)
    out = net(input)
    print(out)
    ```

    在下一轮开始前需要清零所有参数的梯度缓存，然后进行随机梯度的反向传播：

    ```python
    net.zero_grad()
    out.backward(torch.randn(1, 10))
    ```

    注意：`torch.nn`只支持小批量处理 (mini-batches），整个`torch.nn`包只支持小批量样本的输入，不支持单个样本的输入。如果是一个单独的样本，需要使用`input.unsqueeze(0)`来添加一个“假的”批大小

* **AlexNet**：早期的深度学习分类算法

    [原论文下载](https://link.zhihu.com/?target=http%3A//www.cs.toronto.edu/~fritz/absps/imagenet.pdf)

    AlexNet中包含了几个比较新的技术点，也首次在CNN中成功应用了ReLU、Dropout和LRN等技术。同时AlexNet也使用了GPU进行运算加速。它将LeNet的思想发扬光大，把CNN的基本原理应用到了很深很宽的网络中

    ![3.4.2](硬件人的PyTorch【基础内容】.assets/3.4.2.png)

    ```python
    class AlexNet(nn.Module):
        def __init__(self):
            super(AlexNet, self).__init__()
            self.conv = nn.Sequential(
                #这里使用了Sequential方法实现连续层的实现
                nn.Conv2d(1, 96, 11, 4),
                nn.ReLU(),
                nn.MaxPool2d(3, 2),
                nn.Conv2d(96, 256, 5, 1, 2),
                nn.ReLU(),
                nn.MaxPool2d(3, 2),
                #连续3个卷积层，且使用更小的卷积窗口
                #除了最后的卷积层外，进一步增大了输出通道数
                #前两个卷积层后不使用池化层来减小输入的高和宽
                nn.Conv2d(256, 384, 3, 1, 1),
                nn.ReLU(),
                nn.Conv2d(384, 384, 3, 1, 1),
                nn.ReLU(),
                nn.Conv2d(384, 256, 3, 1, 1),
                nn.ReLU(),
                nn.MaxPool2d(3, 2)
            )
            #这里全连接层的输出个数比LeNet中的大数倍
            #需要使用丢弃层来缓解过拟合
            self.fc = nn.Sequential(
                nn.Linear(256*5*5, 4096),
                nn.ReLU(),
                nn.Dropout(0.5),
                nn.Linear(4096, 4096),
                nn.ReLU(),
                nn.Dropout(0.5),
                #由于这里使用Fashion-MNIST，所以用类别数为10，而非论文中的1000
                nn.Linear(4096, 10), #输出层
            )
    
        def forward(self, img):
            feature = self.conv(img) #提取特征图
            output = self.fc(feature.view(img.shape[0], -1)) #输出
            return output
    ```

    上面的代码给出了AlexNet的结构，读者可以自行测试