//
//  MJAnimationManager.h
//  
//
//  Created by 刘鹏 on 2018/3/30.
//  Copyright © 2018年 Musjoy. All rights reserved.
//  动画管理

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// 每个动画循环开始前的用于调整视图的初始位置
typedef void(^ConfigBlock)(NSArray<UIView *> *arrViews, CAAnimation *animation);

/// 动画控制模式
typedef NS_ENUM(NSUInteger, MJAnimationManagerMode) {
    MJAnimationManagerMode_CompleteAnimat, ///< 每次动画都均完整执行后才停止
    MJAnimationManagerMode_Default,        ///< 普通模式（此模式下不会干涉动画的重复，适用于：动画中开启了往返的情况）
};

@interface MJAnimationManager : NSObject <CAAnimationDelegate>
@property (nonatomic, assign) MJAnimationManagerMode mode;///< 动画控制模式 （默认：CompleteAnimat每次动画都均完整执行）
@property (nonatomic, assign) CGFloat interval;///< 动画间隔

/**
 创建执行动画的管理器
 
 @param viewArray 需要动画的视图数组（所有视图同步动画）
 @param animation 动画
 @return 动画管理器实例
 */
- (instancetype)initWithViewArray:(NSArray *)viewArray withAnimation:(CAAnimation *)animation NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithView:(UIView *)view withAnimation:(CAAnimation *)animation;

/// 每个动画循环开始前的用于调整视图的初始位置 (❗️参数中的block会存储起来，所以使用外部对象时需使用弱引用)
- (void)configBeforeEachStart:(ConfigBlock)config;

/// 更新动画（如果之前的动画正在重复进行中，则立即停止并开始新的动画）
- (void)setAnimation:(CAAnimation *)animation;


/// 开始、继续动画
- (void)startAnimation;

/// 停止动画（当前动画的一次循环完整执行后停止）
- (void)stopAnimation;

/// 暂停动画（立即停在当前位置）
- (void)pauseAnimation;

/// 重置动画（立即停止动画，视图恢复到原样）
- (void)resetAnimation;

/*
 ❗️❗️❗️❗️页面消失后，动画会自动暂停。所以调用下面方法，保证页面重新显示后，能重新开始动画。
 因为不知道怎么获取UIView什么时候显示、消失，所以改用所属控制器的显示、消失
 */
/// 在所属控制器页面将要显示时调用
- (void)viewWillAppear;
/// 在所属控制器页面将要消失时调用
- (void)viewWillDisappear;
@end
