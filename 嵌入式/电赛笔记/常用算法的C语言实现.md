## 控制算法



### 位置型PID









### 增量型PID

incremental_pid.c

```c
/**
 * @file incremental_pid.c
 * @brief
 * @author 木.
 * @version 1.0
 * @date 2021-08-03
 *
 * @copyright Copyright (c) 2021  木.
 *
 * @par 修改日志:
 * <table>
 * <tr><th>Date       <th>Version <th>Author  <th>Description
 * <tr><td>2021-08-03 <td>1.0     <td>wangh     <td>Content
 * </table>
 */
#include "incremental_pid.h"

//增量式PID：u(k)=Kp * e(k-1)+Ki *e(t) +Kd *(e(k)-2e(k-1)+e(k-2))；

/**
 * @brief PID结构体
 */
typedef struct {
	float kp;		//比例系数
	float ki;		//积分系数
	float kd;	    //微分系数
	float error;    //误差值
	float lastError;	//上一个误差值
	float dError;        //e(k)
	float ddError;       //e(k-1)
	float dError_last;   //e(k-2)
	float output;         //输出值
	float output_last;    //上次的输出值
	float output_new;
}pid_info;

/**
 * @brief 初始化PID
 * @param  pid              PID结构体
 * @param  kp               比例系数
 * @param  ki               积分系数
 * @param  kd               微分系数
 */
void reset_pid(pid_info* pid, float kp, float ki, float kd)
{
	pid->kp = kp;
	pid->ki = ki;
	pid->kd = kd;
	pid->error = 0;
	pid->lastError = 0;
	pid->dError = 0;
	pid->ddError = 0;
	pid->dError_last = 0;
	pid->output = 0;
	pid->output_last = 0;
}

/**
 * @brief 增量式PID实现
 * @param  error            误差值
 * @param  pid              PID结构体
 * @return float PID输出值
 */
float increment_pid(float error, pid_info* pid)
{
	pid->error = error;
	pid->dError = error - pid->lastError;//e的变化值 e（k） 
	pid->ddError = pid->dError - pid->dError_last;//e （k-1） 
	pid->lastError = error;//下一次使用 
	pid->dError_last = pid->dError;//下一次使用 
	pid->output = (pid->kp * pid->dError) + (pid->ki * error) + (pid->kd * pid->ddError) + pid->output_last;//增量式计算公式 
	pid->output_last = pid->output;
	// int32_t pidoutput= (int32_t)pid->output;
	return pid->output;
}
```







### 双环PID











### 大林算法

```c
//首先定义中间变量，然后根据前面计算得到的大林算法公式，用C语言实现，同时还有进行限幅，以免超过PWM的周期。
long DaLin(float mubiao,float shiji)
{
	int b0=0.4,b1=0.2,a0=12,a1=8;
	static float error,last_error;
	static long DaLin_u,last_DaLin_u,last_DaLin_u1,DaLin_result;
	error = mubiao - shiji;
	DaLin_u = b0*last_DaLin_u + b1*last_DaLin_u1 + a0*error+a1*last_error;大林算法表达式
	last_error = error;
	last_DaLin_u1 = last_DaLin_u;
	last_DaLin_u = DaLin_u;
	DaLin_result = DaLin_u;
	if(error>=-0.6&&error<=0.6)				 //开始保温计时
	{
	    if(wendu<=49.5)		flag=1;
	    if(wendu>49.5&&wendu<=59.5)		flag=3;
			if(wendu>59.5)		flag=5;
	}
	if(DaLin_result > 60)	 		//离目标温度太大（实际温度过小）
		DaLin_result = 60;       //限幅
	if(DaLin_result < 0)			//超过目标温度
		DaLin_result = 0;
		DaLin_result=(int)DaLin_result;      //强制转换成整数
	return DaLin_result;
	
}
```









### 模糊控制算法





## 数字信号处理算法





## 滤波





### 卡尔曼滤波

```c
/**
 * @file karman.c
 * @brief 卡尔曼滤波程序
 * @author RedlightASl (dddbbbdd@foxmail.com)
 * @version 1.0
 * @date 2021-07-31
 *
 * @copyright Copyright (c) 2021  RedlightASl
 *
 * @par 修改日志:
 * <table>
 * <tr><th>Date       <th>Version <th>Author  <th>Description
 * <tr><td>2021-07-31 <td>1.0     <td>wangh     <td>Content
 * </table>
 */

 /**
  * @brief 卡尔曼滤波结构体
  */
struct kalman {
	double filterValue;  //k-1时刻的滤波值，即是k-1时刻的值
	double kalmanGain;   //   Kalamn增益
	double A;   // x(n)=A*x(n-1)+u(n),u(n)~N(0,Q)
	double H;   // z(n)=H*x(n)+w(n),w(n)~N(0,R)
	double Q;   //预测过程噪声偏差的方差
	double R;   //测量噪声偏差，(系统搭建好以后，通过测量统计实验获得)
	double P;   //估计误差协方差
};
typedef struct kalman KalmanStructure;

/**
* @brief Kalman_Init   初始化滤波器的初始值
* @param info  滤波器指针
* @param Q 预测噪声方差 由系统外部测定给定
* @param R 测量噪声方差 由系统外部测定给定
*/
void Kalman_Init(KalmanStructure* info, double Q, double R)
{
	info->A = 1;  //标量卡尔曼
	info->H = 1;  //
	info->P = 10;  //后验状态估计值误差的方差的初始值（不要为0问题不大）
	info->Q = Q;    //预测（过程）噪声方差 影响收敛速率，可以根据实际需求给出
	info->R = R;    //测量（观测）噪声方差 可以通过实验手段获得
	info->filterValue = 0;// 测量的初始值
}

/**
 * @brief 卡尔曼滤波实现
 * @param  info       滤波器指针
 * @param  lastMeasurement  上一时刻的值
 * @return double
 */
double Kalman_Filter(KalmanStructure* info, double lastMeasurement)
{
	//预测下一时刻的值
	//x的先验估计由上一个时间点的后验估计值和输入信息给出，此处需要根据基站高度做一个修改
	double predictValue = info->A * info->filterValue;

	//求协方差
	info->P = info->A * info->A * info->P + info->Q; //计算先验均方差 p(n|n-1)=A^2*p(n-1|n-1)+q
	double preValue = info->filterValue; //记录上次实际坐标的值

	//计算kalman增益
    //Kg(k)= P(k|k-1) H’ / (H P(k|k-1) H’ + R)
	info->kalmanGain = info->P * info->H / (info->P * info->H * info->H + info->R); 
	//修正结果，即计算滤波值
    //利用残余的信息改善对x(t)的估计，给出后验估计，这个值也就是输出  X(k|k)= X(k|k-1)+Kg(k) (Z(k)-H X(k|k-1))
	info->filterValue = predictValue + (lastMeasurement - predictValue) * info->kalmanGain; 
	//更新后验估计
	info->P = (1 - info->kalmanGain * info->H) * info->P; //计算后验均方差  P[n|n]=(1-K[n]*H)*P[n|n-1]

	return  info->filterValue;
}
```







