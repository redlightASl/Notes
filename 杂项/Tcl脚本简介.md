[TOC]

# Tcl脚本在IC领域的主要用途

## 复杂文本处理

Tcl可以把文本中的每一行变为一个**列表**，最简单的列表就是包含由任意个空格、制表符、换行符分隔开的任意多个元素的字符串，可以直接根据元素编号来获取字符串内容

Tcl也支持正则表达式

## 自动化执行flow

对于一些流程化的flow，可以编写Tcl脚本来自动执行，一键得到结果和report

## 辅助EDA开发

Tcl易上手、使用简便，可以简便地设计图形化界面；也可以针对大型项目设计EDA辅助工具

# Tcl脚本简介

Tcl即Tool command language工具控制语言，读作Tickle

Tcl包含了一个脚本语言和一个库包：Tcl脚本主要用于发布命令给交互程序，语法简单、扩展性强；Tcl库可以被嵌入应用程序，它包含了一个分析器、用于执行内建命令的例程和一个可以允许用户扩充的库函数。使用Tcl库，应用程序可以产生Tcl命令并执行，命令可以由用户产生，也可以从用户接口的输入中读取，Tcl库收到命令后将他分解并执行内建的命令。

目前大部分EDA工具都支持Tcl语言，如Design Complier、quartus、Synplify、modesim、finesim等，Tcl在IC设计中非常常用

Tcl程序有两种运行方式，一种是将程序写入脚本中，通常以.tcl命名；另一种是在tcl命令行中直接执行

## Tcl解释器

Tcl是解释型语言，与Python、Perl等类似，它依靠Tcl脚本语言解释器工作，逐行执行Tcl命令，遇到错误时它会停止运行

helloworld程序如下：

```tcl
#!/usr/bin/tclsh
puts "helloworld"
```

在shell中如下执行：

```shell
$ tclsh hello.tcl # Unix
> tclsh hello.tcl # Windows
```

## Tcl数据类型

Tcl只支持**字符串**数据类型：所有命令、参数、命令结果、变量等都是字符串

==字符串的实际解释依赖于上下文==

Tcl允许使用字符串组合出多种高级数据类型

```tcl
#!/usr/bin/tclsh

set a hello
puts $a
set b "hello world"
set c {hello world}
puts $b
puts $c # 这里b和c打印的值都是 hello world
```

### 列表

**使用一组单词与双引号、中括号或者大括号的组合表示列表**，如下所示：

```tcl
#!/usr/bin/tclsh

set myVariable {red green blue} # set listName [list item1 item2 item3] 中括号、大括号都可以
puts [lindex $myVariable 2]
set myVariable "red green blue"
puts [lindex $myVariable 1]
```

注意：==Tcl的列表以0为第一个元素的坐标==，所以以上输出为

```shell
$ blue
$ green
```

使用`append`或`lappend`命令追加项目到列表

```tcl
append 列表名 原来的项目 追加项目 # 或 lappend 列表名 追加项目
```

使用`llength`变量控制列表的长度

使用`lsort`命令排序列表

使用`lreplace`替换列表项，如下所示

```tcl
#!/usr/bin/tclsh

set var {orange blue red green}
set var [lreplace $var 2 3 black white]
puts $var # 输出 orange blue black white （第3、4个列表项被替换为了black、white）
```

使用`lassign`将列表的值赋值给变量，如下所示

```tcl
#!/usr/bin/tclsh

set var {orange blue red green}
lassign $var colour1 colour2
puts $colour1 # 输出 orange
puts $colour2 # 输出 blue
```

### 关联数组（字典）

可以使用以下形式创建关联数组，或者说**键值对（字典）**

```tcl
#!/usr/bin/tclsh

set  marks(english) 80
puts $marks(english) # 输出 80
set  marks(mathematics) 90
puts $marks(mathematics) # 输出 90
```

特别地，==Tcl的键值对不要求索引（键）是整数==

使用`dict set 字典名 键 值`来格式化创建字典

使用`dict size`获取字典的大小

使用以下方法遍历字典

```tcl
#!/usr/bin/tclsh

set colours [dict create colour1 "black" colour2 "white"]

foreach item [dict keys $colours] {
    set value [dict get $colours $item]
    puts $value
}

# 或以下方法

#!/usr/bin/tclsh

set colours [dict create colour1 "black" colour2 "white"]
set values [dict values $colours]
puts $values
```

输出如下：

```shell
$ black
$ white
```

使用以下方法(`dict exists`)检索字典

```tcl
#!/usr/bin/tclsh

set colours [dict create colour1 "black" colour2 "white"]
set result [dict exists $colours colour1]
puts $result # 输出 1
```

### 句柄

TCL句柄通常用于表示文件和图形对象，也可以包括句柄网络请求以及其它流设备，如串口、套接字或I/O设备

使用例如下

```tcl
set myfile [open "filename" r]
```

## Tcl基本语法

### 注释

使用`#`作为单行注释

如果第一个非空字符是`#`，这一行的所有东西都是注释

特别地，可以使用条件判断语句作为多行注释，不过这样会影响代码可读性

```tcl
# 下面是多行注释
if 0 {
这里是注释
这里也是注释
}

puts "test" ;# 这里是行内注释

# 这是单行注释
```

### 标示符

Tcl标识符是用来标识变量，函数，或任何其它用户定义的项目的名称。标识符开始以字母A到Z或a〜z或后跟零个或多个字母下划线（_），下划线，美元（$）和数字（0〜9），Tcl不允许标点字符，如@和％标识符，但可以使用转义或`{}`括起来使用标点字符；**Tcl大小写敏感**

**Tcl的保留字不能用做变量名**

### 空格与分隔

Tcl解释器会忽略多余的**空白格**与注释行

Tcl中将**空格、制表符**、换行符、注释统称为**空白格**。空格分开声明中的一个组成部分，使解释器来识别

总体与shell脚本类似，格式自由

**Tcl中句与句之间以换行或分号分隔。如果每行只有一个语句，则分号不是必须的；如果一行中只包含空白格、注释，解释器则会忽略该行；在一个语句中，通过空格来分隔语句的不同部分**

### 命令

Tcl命令实际上是词语的列表。使用要执行表示该命令的第一个字

Tcl命令有以下特点：

* 一个命令就是一个字符串
* **命令用换行符或分号来分隔**
* 一个命令由许多的**域**组成，第一个域是命令名，剩下的域作为参数
* **域通常由空格或制表符分割**

### 引用与替换

如下方法引用变量：

```tcl
$变量名
```

如下方法展开命令或调用过程的值

```tcl
[命令或调用过程]
```

使用`\`将特殊字符转义

使用如下方法展开`[]`、`$`、`\`语句的内容

```tcl
"要展开使用内容"
```

使用如下方法将内容作为一个整体使用（但内部的特殊字符不会被展开或转义）

```tcl
{作为整体使用的内容}
```

### 表达式

使用`expr`表示后面的式子是数学表达式

**Tcl默认精度是12位**，可以使用`tcl_precision`改变精度

```tcl
#!/usr/bin/tclsh

set variableA "10"
set tcl_precision 5
set result [expr $variableA / 9.0];
puts $result # 输出 1.1111
```

### 赋值

使用`set`对变量进行赋值，使用`$`引用变量

综合示例如下：

```tcl
#!/usr/bin/tclsh
set a 114514; # 把114514赋值给a
set b {$a}; # 把$a赋值给b

puts "test!"; # 打印出test!
puts a; # 打印出字符a
puts $a; # 打印出114514
puts $b; #打印出$a 注意并不是114514
```

字符串赋值见Tcl数据类型

### 运算符

1. 算术运算符

支持+ - * / %

与c一样

2. 关系运算符

与c一样

3. 逻辑运算符

与c一样

4. 位运算符

与c一样

5. 三元运算符

与c一样

6. 运算符优先级

| 分类        | 运算符    | 结合性        |
| ----------- | --------- | ------------- |
| 正负号      | + -       | Right to left |
| 乘除法      | * / %     | Left to right |
| 加减法      | + -       | Left to right |
| 移位        | << >>     | Left to right |
| 关系        | < <= > >= | Left to right |
| 位与        | &         | Left to right |
| 位异或      | ^         | Left to right |
| 位或        | \|        | Left to right |
| Logical AND | &&        | Left to right |
| 逻辑或      | \|\|      | Left to right |
| 三元        | ?:        | Right to left |

总体上来说和c语言运算符一致

### 控制语句

Tcl的if语法如下：

```tcl
if {布尔表达式} {
	# 表达式
} else if {布尔表达式} {
	# 表达式
} else if {布尔表达式} {
	# 表达式
} else if {布尔表达式} {
	# 表达式
} else {
	# 表达式
}
```

和c语言不能说差别不大，只能说完全一样

甚至也可以使用switch语句

```tcl
switch switchingString {
   matchString1 {
      body1
   }
   matchString2 {
      body2
   }
...
   matchStringn {
      bodyn
   }
}
```

switch语句也可以嵌套

循环语句则分成2种，和c语言一样的for与while，但是没有do while

```tcl
while {condition} {
   statement(s)
}

for {initialization} {condition} {increment} {
   statement(s);
}
```

### 函数

Tcl支持自定义函数，称为**过程**，语法如下

```tcl
proc 过程名 {参数1 参数2 ...}
{	过程体
return 返回值}
```

参数之间用空白格分开

函数支持递归调用

不支持在函数内部定义函数

### 正则表达式

Tcl支持内嵌正则表达式，**正则表达式以命令形式使用**

```tcl
#!/usr/bin/tclsh

regexp {([A-Z,a-z]*)} "Tcl Tutorial" a b 
puts "Full Match: $a"
puts "Sub Match1: $b"
# 输出如下
Full Match:Tcl
Sub Match1:Tcl
```

Tcl提供了一些参数用于简便使用正则表达式

* -nocase 忽略大小写
* -indices 匹配子模式，而不是匹配字符存储的位置
* -line 新行敏感匹配。换行后忽略字符
* -start index 搜索模式开始设置偏移