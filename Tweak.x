// LockColorSwitch
// Target: iOS 16.6.1 / iPhone 14 Pro Max / RootHide
//
// 功能：
// 1. 锁屏通知：默认 / 纯白 / 纯黑
// 2. 锁屏播放器：默认 / 纯白 / 纯黑
// 3. 锁屏 Live Activity：默认 / 纯白 / 纯黑
// 4. 不修改背景颜色
// 5. 不修改字体、布局、圆角、动画
// 6. 不主动处理 Dynamic Island
//
// 注意：
// iOS SpringBoard 的私有类名可能随系统版本变化。
// 因此这里采用“类名 + UIKit 控件类型”的保守方式处理。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#pragma mark - Preference

static NSString * const LCSPreferenceDomain =
    @"com.lockcolorswitch.preferences";

static BOOL LCS_Enabled = YES;

static NSInteger LCS_NotificationMode = 0;
static NSInteger LCS_PlayerMode = 0;
static NSInteger LCS_LiveActivityMode = 0;


// 读取 BOOL 设置
static BOOL LCS_ReadBool(NSString *key, BOOL defaultValue) {

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            (__bridge CFStringRef)key,
            (__bridge CFStringRef)LCSPreferenceDomain
        );

    if (!value) {
        return defaultValue;
    }

    BOOL result = defaultValue;

    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        result = CFBooleanGetValue((CFBooleanRef)value);
    } else if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        int number = 0;
        CFNumberGetValue(
            (CFNumberRef)value,
            kCFNumberIntType,
            &number
        );
        result = (number != 0);
    }

    CFRelease(value);

    return result;
}


// 读取整数设置
static NSInteger LCS_ReadInteger(NSString *key,
                                 NSInteger defaultValue) {

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            (__bridge CFStringRef)key,
            (__bridge CFStringRef)LCSPreferenceDomain
        );

    if (!value) {
        return defaultValue;
    }

    NSInteger result = defaultValue;

    if (CFGetTypeID(value) == CFNumberGetTypeID()) {

        int number = 0;

        CFNumberGetValue(
            (CFNumberRef)value,
            kCFNumberIntType,
            &number
        );

        result = (NSInteger)number;
    }

    CFRelease(value);

    return result;
}


// 每次处理锁屏 UI 前重新读取设置
static void LCS_LoadPreferences(void) {

    LCS_Enabled =
        LCS_ReadBool(@"enabled", YES);

    LCS_NotificationMode =
        LCS_ReadInteger(@"notificationMode", 0);

    LCS_PlayerMode =
        LCS_ReadInteger(@"playerMode", 0);

    LCS_LiveActivityMode =
        LCS_ReadInteger(@"liveActivityMode", 0);

    // 防止 PreferenceLoader 中出现异常数值
    if (LCS_NotificationMode < 0 ||
        LCS_NotificationMode > 2) {
        LCS_NotificationMode = 0;
    }

    if (LCS_PlayerMode < 0 ||
        LCS_PlayerMode > 2) {
        LCS_PlayerMode = 0;
    }

    if (LCS_LiveActivityMode < 0 ||
        LCS_LiveActivityMode > 2) {
        LCS_LiveActivityMode = 0;
    }
}


#pragma mark - Color

static UIColor *LCSColorForMode(NSInteger mode) {

    switch (mode) {

        // 默认
        case 0:
            return nil;

        // 纯白 #FFFFFF
        case 1:
            return [UIColor colorWithRed:1.0
                                   green:1.0
                                    blue:1.0
                                   alpha:1.0];

        // 纯黑 #000000
        case 2:
            return [UIColor colorWithRed:0.0
                                   green:0.0
                                    blue:0.0
                                   alpha:1.0];
    }

    return nil;
}


#pragma mark - Lock Screen Detection

// 判断某个 UIView 是否处于锁屏相关 UI
static BOOL LCS_IsLockScreenContext(UIView *view) {

    if (!view) {
        return NO;
    }

    for (UIView *current = view;
         current != nil;
         current = current.superview) {

        NSString *name =
            NSStringFromClass(current.class);

        if ([name containsString:@"LockScreen"] ||
            [name containsString:@"Lockscreen"] ||
            [name containsString:@"NCNotification"] ||
            [name containsString:@"MediaControls"] ||
            [name containsString:@"NowPlaying"] ||
            [name containsString:@"LiveActivity"] ||
            [name containsString:@"Activity"] ||
            [name containsString:@"SBLockScreen"]) {

            return YES;
        }
    }

    return NO;
}


// 排除 Dynamic Island。
// 这里不主动处理 Dynamic Island。
static BOOL LCS_IsDynamicIslandContext(UIView *view) {

    if (!view) {
        return NO;
    }

    for (UIView *current = view;
         current != nil;
         current = current.superview) {

        NSString *name =
            NSStringFromClass(current.class);

        if ([name containsString:@"DynamicIsland"] ||
            [name containsString:@"DynamicIslandContainer"] ||
            [name containsString:@"Island"] ||
            [name containsString:@"SBDynamicIsland"]) {

            return YES;
        }
    }

    return NO;
}


#pragma mark - Foreground Detection

// 只处理可能属于前景文字 / 图标 / 控件的 UIView。
// 不处理背景、Blur、Backdrop、Material 等。
static BOOL LCS_IsForegroundCandidate(UIView *view) {

    if (!view) {
        return NO;
    }

    NSString *name =
        NSStringFromClass(view.class);

    // 明确排除背景相关 View
    if ([name containsString:@"Background"] ||
        [name containsString:@"Backdrop"] ||
        [name containsString:@"Blur"] ||
        [name containsString:@"Material"] ||
        [name containsString:@"Vibrancy"]) {

        return NO;
    }

    // UILabel：文字
    if ([view isKindOfClass:[UILabel class]]) {
        return YES;
    }

    // UIImageView：图标
    if ([view isKindOfClass:[UIImageView class]]) {
        return YES;
    }

    // UIButton：按钮文字 / 图标
    if ([view isKindOfClass:[UIButton class]]) {
        return YES;
    }

    // 其他 UIControl：例如播放控制按钮
    if ([view isKindOfClass:[UIControl class]]) {
        return YES;
    }

    return NO;
}


#pragma mark - Apply Foreground Color

static void LCS_ApplyToViewTree(UIView *root,
                                UIColor *color) {

    if (!root || !color) {
        return;
    }

    // 必须是锁屏上下文
    if (!LCS_IsLockScreenContext(root)) {
        return;
    }

    // 不处理 Dynamic Island
    if (LCS_IsDynamicIslandContext(root)) {
        return;
    }


    // 只改变前景控件
    if (LCS_IsForegroundCandidate(root)) {

        // 文字
        if ([root isKindOfClass:[UILabel class]]) {

            UILabel *label =
                (UILabel *)root;

            label.textColor = color;
        }


        // 按钮
        else if ([root isKindOfClass:[UIButton class]]) {

            UIButton *button =
                (UIButton *)root;

            [button setTitleColor:color
                         forState:UIControlStateNormal];

            [button setTitleColor:color
                         forState:UIControlStateHighlighted];

            [button setTitleColor:color
                         forState:UIControlStateSelected];

            button.tintColor = color;
        }


        // 图片 / 图标
        else if ([root isKindOfClass:[UIImageView class]]) {

            UIImageView *imageView =
                (UIImageView *)root;

            imageView.tintColor = color;
        }


        // 其他控件
        else if ([root isKindOfClass:[UIControl class]]) {

            root.tintColor = color;
        }
    }


    // 继续处理子 View
    for (UIView *subview in root.subviews) {

        LCS_ApplyToViewTree(
            subview,
            color
        );
    }
}


#pragma mark - Detect Color Mode

static UIColor *LCS_ColorForView(UIView *view) {

    if (!view) {
        return nil;
    }

    NSString *name =
        NSStringFromClass(view.class);


    // Dynamic Island 永远不处理
    if (LCS_IsDynamicIslandContext(view)) {
        return nil;
    }


    // 通知
    if ([name containsString:@"NCNotification"] ||
        [name containsString:@"Notification"]) {

        return LCSColorForMode(
            LCS_NotificationMode
        );
    }


    // 播放器
    if ([name containsString:@"MediaControls"] ||
        [name containsString:@"NowPlaying"] ||
        [name containsString:@"MediaControl"]) {

        return LCSColorForMode(
            LCS_PlayerMode
        );
    }


    // Live Activity
    if ([name containsString:@"LiveActivity"] ||
        [name containsString:@"Activity"]) {

        return LCSColorForMode(
            LCS_LiveActivityMode
        );
    }

    return nil;
}


#pragma mark - UIView Hook

%hook UIView

- (void)didMoveToWindow {

    %orig;

    if (!self.window) {
        return;
    }


    // 每次 View 进入 Window 时重新读取设置
    LCS_LoadPreferences();


    if (!LCS_Enabled) {
        return;
    }


    UIColor *color =
        LCS_ColorForView(self);


    if (!color) {
        return;
    }


    // 放到下一轮主线程，避免在 UIKit 正在
    // attach View 的过程中直接递归修改。
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (!self.window) {
                return;
            }

            LCS_LoadPreferences();

            if (!LCS_Enabled) {
                return;
            }

            UIColor *currentColor =
                LCS_ColorForView(self);

            if (!currentColor) {
                return;
            }

            LCS_ApplyToViewTree(
                self,
                currentColor
            );
        }
    );
}

%end


#pragma mark - Constructor

%ctor {

    @autoreleasepool {

        // 启动时读取一次设置
        LCS_LoadPreferences();

        // 故意不 hook：
        // backgroundColor
        // layer.backgroundColor
        // frame
        // bounds
        // cornerRadius
        // font
        // animation

        // 因此本 Tweak 的目标仅限前景颜色。
    }
}
