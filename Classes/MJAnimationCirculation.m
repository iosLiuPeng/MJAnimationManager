//
//  AnimationCirculation.m
//
//
//  Created by 刘鹏 on 2018/4/10.
//  Copyright © 2018年 Musjoy. All rights reserved.
//

#import "MJAnimationCirculation.h"

@implementation MJAnimationCirculation
/**
 实例化连续循环动画管理
 
 @param view 需要动画的视图(开始能看到)
 @param viewCopy 视图的另一份copy（开始看不到）
 @param duration 单次循环耗时
 @param direction 运动方向
 @return 实例
 */
- (instancetype)initWithView:(UIView *)view copyView:(UIView *)viewCopy duration:(NSTimeInterval)duration  direction:(MJAnimationCirculationDirection)direction
{
    if (view == nil || viewCopy == nil) {
        return nil;
    }
    
    self = [super initWithViewArray:@[view, viewCopy] withAnimation:[self translationAnimationWithDuration:duration]];
    if (self) {
        // 配置每次循环前的准备工作
        [self configBeforeEachStart:^(NSArray<UIView *> *arrViews, CAAnimation *animation) {
            // 当完全超出边界后，调整位置
            CGFloat width = arrViews.firstObject.bounds.size.width;
            if (direction == MJAnimationCirculationDirection_Left) {
                // 向左
                for (UIView *aView in arrViews) {
                    if (aView.frame.origin.x <= -width) {
                        CGRect frame = aView.frame;
                        frame.origin.x = width;
                        aView.frame = frame;
                    }
                }
            } else {
                // 向右
                for (UIView *aView in arrViews) {
                    if (aView.frame.origin.x >= width) {
                        CGRect frame = aView.frame;
                        frame.origin.x = -width;
                        aView.frame = frame;
                    }
                }
            }
            
            // 计算需要移动的偏移量
            CABasicAnimation *aAnimation = (CABasicAnimation *)animation;
            if (direction == MJAnimationCirculationDirection_Left) {
                // 向左
                aAnimation.byValue = @(-width);
            } else {
                // 向右
                aAnimation.byValue = @(width);
            }
        }];
    }
    return self;
}

- (CAAnimation *)translationAnimationWithDuration:(NSTimeInterval)duration
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation"];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.repeatCount = CGFLOAT_MAX;
    animation.duration = duration;
    return animation;
}
@end
