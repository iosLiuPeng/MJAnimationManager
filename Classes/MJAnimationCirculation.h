///Users/liupeng/Desktop/OhBug/CustomView/AnimationManager/AnimationManager
//  AnimationCirculation.h
//  
//
//  Created by 刘鹏 on 2018/4/10.
//  Copyright © 2018年 Musjoy. All rights reserved.
//  连续、无限循环显示同一视图

#import "MJAnimationManager.h"

typedef NS_ENUM(NSUInteger, MJAnimationCirculationDirection) {
    MJAnimationCirculationDirection_Right,   ///< 向右
    MJAnimationCirculationDirection_Left,    ///< 向左
};

@interface MJAnimationCirculation : MJAnimationManager <CALayerDelegate>
/**
 实例化连续循环动画管理
 
 @param view 需要动画的视图(开始能看到)
 @param viewCopy 视图的另一份copy（开始看不到）
 @param duration 单次循环耗时
 @param direction 运动方向
 @return 实例
 */
- (instancetype)initWithView:(UIView *)view
                    copyView:(UIView *)viewCopy
                    duration:(NSTimeInterval)duration
                   direction:(MJAnimationCirculationDirection)direction;

/*
 连续循环动画，需要两个相同view才能完成。
 1.目前没有找到方便复制view的方法
 2.如果使用复制view的layer(目前有initWithLayer:和CAReplicatorLayer两种办法)，都需要add到原layer上，都无法在当前类中管理layer的布局（将原layer的delegate指向当前类会崩溃）
 
 所以暂时只能手动在xib或SB中复制一遍view，让系统自动管理布局
 */
@end
