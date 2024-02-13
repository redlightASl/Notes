# 三维重建3【ADCensus】





立体匹配算法，总体来讲包含以下6个步骤：

​    1. Preprocess ( GaussBlur , SobelX, ...etc)

​    2. Cost Compute ( AD, SAD, SSD, BT, NCC, Census, ...etc)

​    3. Cost Aggregation ( Boxfilter, CBCA, WMF, MST, ...etc)

​    4. Cost Optimization ( BP, GC, HBP, CSBP, doubleBP,  ...)

​    5. Disparity Compute( WTA)

​    6. Postprocess ( MedianFilter, WeightMedianFilter, LR-check, ...etc)

​       一般情况下，组合12356称为局部立体匹配算法， 12456称为全局立体匹配算法，区别在于是否构建全局能量优化函数









SGM（semi-global matching）是一种用于计算双目视觉中视差的半全局匹配算法。在OpenCV中的实现为semi-global block matching（SGBM）

SGBM的思路是：通过选取每个像素点的disparity，组成一个disparity map，设置一个和disparity map相关的全局能量函数，使这个能量函数最小化，以达到求解每个像素最优disparity的目的







# AD算法



Absolute differences
