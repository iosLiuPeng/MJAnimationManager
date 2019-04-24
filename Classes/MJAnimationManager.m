//
//  MJAnimationManager.m
//
//
//  Created by 刘鹏 on 2018/3/30.
//  Copyright © 2018年 Musjoy. All rights reserved.
//

#import "MJAnimationManager.h"

typedef NS_ENUM(NSUInteger, MJAnimationStatus) {
    MJAnimationStatus_Inactive,   ///< 已停止、未开始
    MJAnimationStatus_Active,     ///< 运动中
    MJAnimationStatus_Pause,      ///< 暂停中
    MJAnimationStatus_WaitRecover,///< 待恢复(由于异常情况导致的动画停止)
    MJAnimationStatus_Restart,    ///< 立即重新开始(手动造成的动画意外停止，需要立即重新开始)
};

@interface MJAnimationManager ()
@property (nonatomic, strong) NSArray *arrViews;            ///< 所有参与动画的视图
@property (nonatomic, strong) CAAnimation *animation;       ///< 动画
@property (nonatomic, copy) ConfigBlock configBlock;        ///< 每个动画循环开始前的调整工作(用于调整视图的初始位置。参数中的block会存储起来，所以使用外部对象时需使用弱引用)
@property (nonatomic, copy) GetAnimation getAnimationBlock;///< 取动画

@property (nonatomic, assign) MJAnimationStatus status;   ///< 动画状态
@property (nonatomic, assign) CGFloat totalRepeatCount; ///< 动画总重复次数
@property (nonatomic, assign) NSInteger repeatCount;    ///< 当前动画已重复次数
// TODO: 需要将准备停止，改为动画状态的一种
@property (nonatomic, assign) BOOL willStop;            ///< 是否准备停止
@end

@implementation MJAnimationManager
#pragma mark - Life Circle
/// 创建执行动画的管理器
- (instancetype)init
{
    return [self initWithViewArray:nil withAnimation:nil];
}

/**
 创建执行动画的管理器
 
 @param view 需要动画的视图
 @param animationBlock 取动画
 @return 动画管理器实例
 */
- (instancetype)initWithView:(UIView *)view withAnimation:(GetAnimation)animationBlock
{
    return [self initWithViewArray:view? @[view]: nil withAnimation:animationBlock];
}

/**
 创建执行动画的管理器

 @param viewArray 需要动画的视图数组（所有视图同步动画）
 @param animationBlock 取动画
 @return 动画管理器实例
 */
- (instancetype)initWithViewArray:(NSArray *)viewArray withAnimation:(GetAnimation)animationBlock
{
    self = [super init];
    if (self) {
        _arrViews = viewArray;
        
        _getAnimationBlock = animationBlock;
        if (_getAnimationBlock) {
            self.animation = _getAnimationBlock();
        }
        
        // 监听app活跃、失活通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
        // 监听屏幕将要旋转
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenWillRotation) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
}

#pragma mark - Public
/// 开始、继续动画
- (void)startAnimation
{
    if (_arrViews.count == 0 || _animation == nil) {
        return;
    }
    
    switch (_status) {
        case MJAnimationStatus_Inactive:
        case MJAnimationStatus_Restart:
        case MJAnimationStatus_WaitRecover:
            // 每次动画前的准备工作
            if (_configBlock) {
                _configBlock(_arrViews, _animation);
            }
            
            // 开始动画
            for (NSInteger i = 0; i < _arrViews.count; i++) {
                CAAnimation *animationCopy = [_animation copy];
                if (i == 0) {
                    // 因为多个视图是同步进行一个动画，所以取第一个视图来做进度管理就行了，
                    animationCopy.delegate = self;
                }
                
                UIView *aView = _arrViews[i];
                
                if (_interval > 0) {
                    _status = MJAnimationStatus_Active;
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (self.status == MJAnimationStatus_Inactive || self.status == MJAnimationStatus_Active) {
                            [aView.layer addAnimation:animationCopy forKey:nil];
                        }
                    });
                } else {
                    [aView.layer addAnimation:animationCopy forKey:nil];
                }
            }
            break;
        case MJAnimationStatus_Active:
            // 将要暂停时，又点击了开始，则只切换状态，重新计数
            if (_willStop) {
                _willStop = NO;
                _repeatCount = 0;
            }
            break;
        case MJAnimationStatus_Pause:
            // 继续动画
            [self continueAnimation];
            break;
        default:
            break;
    }
}

/// 停止动画（当前动画的一次循环完整执行后停止）
- (void)stopAnimation
{
    switch (_mode) {
        case MJAnimationManagerMode_CompleteAnimat:
            if (_status == MJAnimationStatus_Active) {
                _willStop = YES;
            }
            break;
        case MJAnimationManagerMode_Default:
            [self removeAllAnimations];
            break;
        default:
            break;
    }
}

/// 暂停动画（立即停在当前位置）
- (void)pauseAnimation
{
    if (_status == MJAnimationStatus_Active) {
        for (UIView *aView in _arrViews) {
            CFTimeInterval pauseTime = [aView.layer convertTime:CACurrentMediaTime() fromLayer:nil];
            aView.layer.timeOffset = pauseTime;
            aView.layer.speed = 0;
        }
        
        _status = MJAnimationStatus_Pause;
    }
}

/// 继续动画
- (void)continueAnimation
{
    if (_status == MJAnimationStatus_Pause) {
        for (UIView *aView in _arrViews) {
            // 时间转换
            CFTimeInterval pauseTime = aView.layer.timeOffset;
            // 计算暂停时间
            CFTimeInterval timeSincePause = CACurrentMediaTime() - pauseTime;
            aView.layer.timeOffset = 0;
            aView.layer.beginTime = timeSincePause;
            aView.layer.speed = 1;
        }
        
        _status = MJAnimationStatus_Active;
    }
}

/// 移除动画（立即停止动画，视图恢复到原样）
- (void)removeAllAnimations
{
    for (UIView *aView in _arrViews) {
        [aView.layer removeAllAnimations];
        // 修正因为暂停时发生重新布局，导致的布局异常
        aView.layer.timeOffset = 0;
        aView.layer.beginTime = 0;
        aView.layer.speed = 1;
    }
}

/// 重置动画（立即停止动画，视图恢复到原样）
- (void)resetAnimation
{
    [self removeAllAnimations];
}

/// 每个动画循环开始前的用于调整视图的初始位置
- (void)configBeforeEachStart:(ConfigBlock)config
{
    _configBlock = config;
}

#pragma mark - CAAnimationDelegate
/// 动画开始
- (void)animationDidStart:(CAAnimation *)anim
{
    _repeatCount ++;
    _status = MJAnimationStatus_Active;
}

/// 动画结束
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    // 正常停止的才在动画结束时修改状态，异常停止的由触发的地方修改状态
    if (_status == MJAnimationStatus_Active || _status == MJAnimationStatus_Pause) {
        _status = MJAnimationStatus_Inactive;
    }
    
    if (_mode == MJAnimationManagerMode_CompleteAnimat) {
        // 动画每次均完整执行模式
        if (_status == MJAnimationStatus_Restart) {
            _repeatCount --;
        }
        
        if (_willStop == NO && _repeatCount < _totalRepeatCount && (_status == MJAnimationStatus_Restart || flag)) {
            // 进入下次循环
            [self startAnimation];
        } else if (_willStop) {
            // 手动停止
            _willStop = NO;
        } else if ( _repeatCount >= _totalRepeatCount) {
            // 达到次数上限停止,次数归零
            _repeatCount = 0;
        } else {
            // 异常停止，此次动画未执行完，次数减一
            _repeatCount --;
        }
    } else {
        // 普通模式，停止了就必须手动重新开始
        if (_status == MJAnimationStatus_Restart) {
            [self startAnimation];
        }
    }
}

#pragma mark - Set & Get
- (void)setAnimation:(CAAnimation *)animation
{
    _animation = animation;
    
    _repeatCount = 0;
    _totalRepeatCount = animation.repeatCount;
    self.mode = _mode;

    // 如果之前的动画正在重复进行中，则立即停止并开始新的动画
    if (_status == MJAnimationStatus_Pause) {
        [self removeAllAnimations];
    } else if (_status == MJAnimationStatus_Active) {
        _status = MJAnimationStatus_Restart;
        [self removeAllAnimations];
    }
}

- (void)setMode:(MJAnimationManagerMode)mode
{
    _mode = mode;
    
    switch (mode) {
        case MJAnimationManagerMode_CompleteAnimat:
            _animation.repeatCount = 1;
            break;
        case MJAnimationManagerMode_Default:
            _animation.repeatCount = _totalRepeatCount;
            break;
        default:
            break;
    }
}

#pragma mark - Notification Receive
/// 屏幕旋转
- (void)screenWillRotation
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.status == MJAnimationStatus_Pause) {
            // 暂停视图时，改变了View的Layer层速度等，此时旋转屏幕会导致自动布局出错，所以需要重置视图
            if (self.getAnimationBlock) {
                self.animation = self.getAnimationBlock();
            }
            
            [self removeAllAnimations];
            self.status = MJAnimationStatus_WaitRecover;
        } else if (self.status == MJAnimationStatus_Active && self.willStop == NO) {
            // 旋转后视图大小不同，会导致连续两次的动画速度不一致，感觉动画很突兀，这里暂时考虑直接重置动画，然后重新开始
            if (self.getAnimationBlock) {
                self.animation = self.getAnimationBlock();
            }
            
            self.status = MJAnimationStatus_Restart;
            [self removeAllAnimations];
        }
    });
}

// 程序活跃
- (void)appBecomeActive
{
    if (_status == MJAnimationStatus_WaitRecover) {
        [self startAnimation];
    }
}

/// 程序失活
- (void)appWillResignActive
{
    /*
     失活分为:
     1.滑出控制栏、通知栏 (可以使用暂停、继续动画)
     2.回到首页 (会导致view重绘，需要重置视图)
     因为无法区分，所以统一使用重置视图
     */
    [self removeAllAnimations];
    
    if (_status == MJAnimationStatus_Active && _willStop == NO) {
        _status = MJAnimationStatus_WaitRecover;
    } else {
        _status = MJAnimationStatus_Inactive;
    }
}

/// 在所属控制器页面将要显示时调用
- (void)viewWillAppear
{
    if (_status == MJAnimationStatus_WaitRecover) {
        [self startAnimation];
    }
}

/// 在所属控制器页面将要消失时调用
- (void)viewWillDisappear
{
    // 页面消失会导致view重绘，所以需要重置视图，而不能暂停视图
    [self removeAllAnimations];
    
    if (_status == MJAnimationStatus_Active && _willStop == NO) {
        _status = MJAnimationStatus_WaitRecover;
    } else {
        _status = MJAnimationStatus_Inactive;
    }
}

@end
