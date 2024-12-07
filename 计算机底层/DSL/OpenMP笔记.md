# OpenMP学习笔记

OpenMP（Open Multi-Processing）是一套支持跨平台共享内存方式的多线程并发的编程API，支持使用C/C++和Fortran在大多数处理器体系和操作系统中运行。OpenMP包含一套编译器指令、库和一些能够影响运行行为的环境变量。当前GCC、Clang、MSVC均支持OpenMP接口，在编译时添加编译器指定的标志即可启用OpenMP

> GCC中使用 `-fopenmp` 即可

OpenMP是基于线程的**并行编程模型**。它通过高级抽象的方式，隐藏了线程管理的复杂性，使得开发者可以专注于并行化的算法设计。OpenMP的核心概念包括：

* 并行区域（Parallel Regions）：代码中并行执行的块
* 工作共享结构（Work-sharing Constructs）：将并行区域内的工作分配给多个线程
* 同步结构（Synchronization Constructs）：线程间的同步机制，如临界区（critical sections）和屏障（barriers）
* 数据环境（Data Environment）：定义变量的作用域和存储方式，如私有（private）或共享（shared）

OpenMP早期是用来实现跨平台的多线程并发编程的一套标准。到了OpenMP4.0加入了对SIMD指令的支持，以实现跨平台的向量化支持。

## 基本概念

首先介绍OpenMP的基本使用方法。通过下面代码可以很简单地启用OpenMP多线程并行运算

```c
#include <stdio.h>
#include <omp.h>

int main(int argc,char** argv) {
    #pragma omp parallel for
    for (int i = 0; i < 10; i++) {
        printf("Thread %d executes loop iteration %d\n", omp_get_thread_num(), i);
    }
    return 0;
}
```

使用下列语句进行编译

```shell
g++ -std=c++17 -O0 -g -fopenmp -lstdc++ -o main main.cpp
```

执行输出为

```shell
Thread 0 executes loop iteration 0
Thread 9 executes loop iteration 9
Thread 2 executes loop iteration 2
Thread 4 executes loop iteration 4
Thread 5 executes loop iteration 5
Thread 1 executes loop iteration 1
Thread 3 executes loop iteration 3
Thread 6 executes loop iteration 6
Thread 7 executes loop iteration 7
Thread 8 executes loop iteration 8
```

可以发现循环中的printf被乱序执行了10次



  1、index的值必须是整数，一个简单的for形式：for(int i = start; i < end; i++){…} 。

  2、start和end可以是任意的数值表达式，但是它在并行化的执行过程中值不能改变，也就是说在for并行化执行之前，编译器必须事先知道你的程序执行多少次，因为编译器要把这些计算分配到不同的线程中执行。

  3、循环语句只能是单入口但出口的。这里只要你避免使用跳转语句就行了。具体说就是不能使用goto、break、return。但是可以使用continue，因为它并不会减少循环次数。另外exit语句也是可以用的，因为它的能力太大，他一来，程序就结束了。



## OpenMP结构拆分







工作共享指令

`#pragma omp for`或`#pragma omp do`：将循环迭代分配给线程

`#pragma omp sections`：将代码块分配给线程。

`#pragma omp single`：指定一个线程执行代码块。



数据作用域指定子

`shared`：变量在所有线程中共享。

`private`：每个线程有自己的变量副本

`firstprivate`和`lastprivate`：类似于`private`，但有特殊的初始化和赋值方式



同步是并行编程中的一个重要概念，它确保了程序的正确性。OpenMP提供了多种同步机制

`#pragma omp critical`：临界区，一次只有一个线程可以执行。

`#pragma omp barrier`：屏障，使所有线程在此等待直到所有线程都到达这里后再继续

`#pragma omp atomic`：原子操作，保证特定的存储操作的原子性。



## 循环展开/并行化





