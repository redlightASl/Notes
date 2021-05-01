本文章参考https://blog.csdn.net/long_fly/article/details/78897158总结

Tcl是一种通用的脚本语言，它在**几乎所有平台上都可以解释运行**，很多软件都支持用Tcl脚本的方式执行，学会了用这个东西就相当于从GNOME、KDE换成了bash shell（确信）。Vivado也内置了Tcl解释器并提供Tcl命令行执行各种操作，更神奇的是Tcl脚本比GUI下操作VIVADO效率更高。而且Xilinx官网的文档很多都是用Tcl命令来完成操作

总结来说学习Tcl脚本语言的好处：

1. 标准语法，一通百通
2. 快速执行，增加工作效率
3. 支持程序间通信


Tcl的语法都已经在之前的博文中讲述过，下面着重介绍Vivado中的Tcl命令

# Vivado中的Tcl脚本

虽然已经品鉴过无数次，但还是先问一下，你听说过~~侠客行~~Tcl的语法吗

## 复习Tcl语法

1. 一条Tcl的命令串包含了多条命令时，用**换行符**`\n`或**分号**`;`来隔开，也就也是说Tcl可以*随便写*，后面加不加分号都没事 

2. 一条命令就是一个域的集合，域使用**空白**分开，第一个域是命令的名字，其它的作为参数来传给它

3. Tcl只支持一种数据结构：**字符串**，所有东西都是字符串，把python的对象扔掉就成了Tcl（确信）

4. 简单的示例

   ```tcl
   #这是注释
   #单行注释前要先用分号把命令结束掉，或者就换行注释
   set a 1
   #将字符串1赋值给a
   unset a;#将a取消赋值
   set b hello_1;#将字符串hello_1赋值给b
   set c "ok sir";#当字符串中间有空白时加双引号
   ```

5. 使用`$v`来引用变量`v`

6. 数组使用很方便，可以随便乱用，并且Tcl支持任意维数的数组

   ```tcl
   set i(1) 123;
   set i(16) hi;
   
   set i(1,2,3) hi;set i(1,2,4) hello;#多维数组
   puts $i(1,2,3);#输出hi
   puts $i(1,2,4);#输出hello
   ```

## 配置开发环境

如果想要一个单纯的Tcl环境，只要单独安装Tcl即可，Linux下使用`sudo apt install tcl`一键安装，照着别的教程随便写写helloworld就完事了，不过这里介绍的是在Vivado中使用特定的Tcl命令行，所以需要

1.  安装好Vivado

2. 在安装目录下找到Vivado Tcl Shell（或者找遍你的硬盘，总之找到这个东西就行）

   像下面这样：

   ![image-20210501134029745](C:\Users\NH55\AppData\Roaming\Typora\typora-user-images\image-20210501134029745.png)

   其实还可以把它放到Windows Terminal中，这个就请自行翻阅其他教程罢！

3. 在Vivado Tcl Shell中尝试输入以下命令

   ```tcl
   set i hello,world;puts i;puts $i
   ```

   应该会输出

   ```tcl
   i
   hello,world
   ```

   好的，开发环境准备完毕

## Tcl脚本常用命令与语法

* parray命令

  打印出一个数组的全部值

  ```tcl
  set i(0,0,0) h
  set i(0,0,1) e
  set i(0,1,0) l
  set i(1,0,0) l
  set i(1,1,1) o
  parray i; 
  ```

* array命令

  用于对数组进行特殊操作

  ```tcl
  #格式A：array option arrayName
  #其中option是操作选项
  array name i;#返回数组中所有元素名称
  array size i;#返回数组长度
  array startsearch i;#初始化一次遍历，返回一个遍历标识符searchId，这个东西在下面用到
  
  #格式B：array option arrayName searchId
  array nextelement i 1;#返回数组中下一个元素，如果没有则返回空
  array anymore i 1;#如果接下来还有元素则返回1，否则返回0
  array donesearch i 1;#结束遍历
  ```

* append命令

  在字符串后面追加字符串

  可以无限拼接

* split命令

  将字符串转换为列表

  ```tcl
  split niconiconi i
  #后面的字符为分隔符，需要从字符串中找，字符串会以它为分割裂开
  #输出如下
  n con con {}
  ```

* 数字操作命令

  由于Tcl中只有字符串，所以在进行数字运算时需要使用特殊的命令

  * incr

    变量自加

    ```tcl
    set a 0;
    incr a 3;#自增3
    incr a -3;#自增-3
    ```

    最后a的值还是0

  * expr

    用于识别各种表达式

    ```tcl
    expr 2>1
    1
    
    expr 10/2.0
    5.0
    
    set a [expr 1?1:0]
    1
    
    set a [expr ?1:0]
    0
    
    expr cos(0)
    1.0
    
    expr abs(-3)
    3
    
    expr round(3.456)
    3
    
    set pi 3.14;
    expr sin($pi);
    0.0015926529164868282
    ```

* 判断、循环指令

  * 判断

    if语句、switch语句

    基本与C语言一致

  * 循环

    for循环

    ```tcl
    for {set i 0} {$i < 4} {incr i} {
    	puts $i;
    }
    ```

    **注意这里的大括号间都要用空格隔开**

    while循环

    ```tcl
    set i 5;
    while {$i != 3} {
    	puts $i;
    	incr i -1;
    }
    ```

    这里的大括号间也要用空白隔开

    特别地，Tcl支持foreach循环，用于遍历整个数组或给出的数

    ```tcl
    foreach i {0 2 3 x 1 4} {
    	switch $i {
    		0 {puts a}
    		1 {puts b}
    		2 {puts c}
    		3 {puts d}
    		4 {puts e}
    		default {puts z}
    	}
    }
    
    #输出
    a
    c
    d
    z
    b
    e
    ```

    这个东西比较常用，类似python中的for循环

    ```tcl
    for {set i 0} {$i < 4} {incr i} {
    	set a[$i] [expr $i + 1];
    }
    
    #下面这个代码是错误的
    #注意分辨foreach的逻辑是一口气将i赋值成一套数组，再带入switch的控制变量中
    foreach i {0,1,2,3} {
    	switch $a($i) {
    		1 {puts a}
    		2 {puts b}
    		3 {puts c}
    		4 {puts d}
    		default {puts z}
    	}
    }
    #报错如下
    #can't read "a(0,1,2,3)": no such element in array
    #应该像下面这样使用
    for {set i 0} {$i < 4} {incr i} {
    	switch $a($i) {
    		1 {puts a}
    		2 {puts b}
    		3 {puts c}
    		4 {puts d}
    		default {puts z}
    	}
    }
    ```

* 输入/输出

  * **format命令**

    格式化输入输出

    ```tcl
    format "%s %d" hello 123
    ```

  * **scan命令**

    把字符串拆分后格式化赋值给变量

    ```tcl
    scan 12.34.56.78 %d.%d.%d.%d a b c d
    #将12.34.56.78拆分，并分别赋值给a b c d四个变量，命令返回赋值成功的变量的个数
    ```

  * **puts命令**

    直接输出到屏幕/终端

  * **文件操作**

    * cd

      和shell中的cd一样用于切换当前目录

      推荐在shell中而不是Tcl命令行中使用该操作

    * pwd

      查看当前目录

    * glob

      查看当前目录下的文件，类似shell中的ls命令，但是可以支持查询等高级功能

      ```tcl
      glob *
      
      glob *.c *.exe#查看当前目录下特定后缀的文件
      ```

    * open

      打开文件，该命令返回一个文件描述符

      ```tcl
      #命令格式如下
      #open 文件名 模式
      #能使用r只读、r+可读写、w只写（文件存在则清空内容；文件不存在则创建文件）、a追加（文件不存在则创建；文件存在，则会在文件内容最后面追加写入的数据）
      set f [open hello.tcl w]
      ```

    * read和gets

      用于读取当前文件

      ```tcl
      read $f 65536;
      #从文件指针f指向的文件中读取65536个字节的数据
      read $f
      #从文件中读取全部内容
      gets $f
      #读取文件中的单行内容
      ```

    * close

      关闭当前文件

    * eof

      用于判断是否已经读完文件，读完返回1，否则返回0

    * flush

      刷新缓冲区

    总体上文件操作和C语言的不能说完全一致，至少是一模一样

* **time**

  计算某个命令执行的时间

  ```tcl
  time "set i 1"
  ```

* **Tcl面向对象**（？）

  Tcl支持命名空间的概念

  **命名空间是命令和变量的集合，可以看成一个丐版的类**

  通过封装命名空间，就可以保证它们不会影响其他命名空间的变量和命令——封装

  所有东西都是字符串——抽象

  ——多态？不存在的！这不是c++，是Tcl哒！

  * 设置与删除命名空间

    ```tcl
    #只要在命令之前加上"namespace eval 名称"就可以设置命名空间了
    namespace eval test {
    	pro hello {} {
    		puts hello;
    	}
    }
    
    set test::i 123;#设置命名空间内的私有变量
    
    #调用“方法”和“私有变量”
    puts test::i;
    test::hello;
    
    namespace delete test;#删除命名空间
    ```

  * 不同命名空间之间的过程共享（public类）

    使用`export`和`import`完成命名空间的导出和导入就可以实现过程共享

## Vivado的Tcl库

