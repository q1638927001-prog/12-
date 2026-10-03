// LockColorSwitch
// Target: iOS 16.6.1 / iPhone 14 Pro Max / RootHide
//
// Scope:
// - Lock-screen notification foreground UI/text only
// - Lock-screen media player foreground UI/text only
// - Lock-screen Live Activity foreground UI/text only
// - No backgroundColor changes
// - No Dynamic Island handling
//
// IMPORTANT: Private SpringBoard class names can vary. This first-pass
// implementation deliberately limits itself to views whose accessibility/
// class names strongly indicate foreground content. It does not alter
// backgrounds.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL LCS_Enabled = YES;
static NSInteger LCS_NotificationMode = 0; // 0 default, 1 white, 2 black
static NSInteger LCS_PlayerMode = 0;
static NSInteger LCS_LiveActivityMode = 0;

static UIColor *LCSColorForMode(NSInteger mode) {
    if (mode == 1) return [UIColor whiteColor];
    if (mode == 2) return [UIColor blackColor];
    return nil;
}

static BOOL LCS_IsLockScreenContext(UIView *view) {
    for (UIView *v = view; v; v = v.superview) {
        NSString *n = NSStringFromClass(v.class);
        if ([n containsString:@"LockScreen"] ||
            [n containsString:@"Lockscreen"] ||
            [n containsString:@"NCNotification"] ||
            [n containsString:@"MediaControls"] ||
            [n containsString:@"NowPlaying"] ||
            [n containsString:@"Activity"]) {
            return YES;
        }
    }
    return NO;
}

static BOOL LCS_IsForegroundCandidate(UIView *view) {
    NSString *n = NSStringFromClass(view.class);
    if ([n containsString:@"Background"] ||
        [n containsString:@"Backdrop"] ||
        [n containsString:@"Blur"] ||
        [n containsString:@"Material"]) {
        return NO;
    }
    return ([view isKindOfClass:UILabel.class] ||
            [view isKindOfClass:UIImageView.class] ||
            [view isKindOfClass:UIControl.class]);
}

static void LCS_ApplyToViewTree(UIView *root, UIColor *color) {
    if (!root || !color) return;
    if (!LCS_IsLockScreenContext(root)) return;

    if ([root isKindOfClass:UILabel.class]) {
        ((UILabel *)root).textColor = color;
    } else if ([root isKindOfClass:UIButton.class]) {
        [(UIButton *)root setTitleColor:color forState:UIControlStateNormal];
        [(UIButton *)root setTintColor:color];
    } else if ([root isKindOfClass:UIImageView.class]) {
        UIImageView *iv = (UIImageView *)root;
        if (@available(iOS 13.0, *)) {
            iv.tintColor = color;
        }
    } else if ([root isKindOfClass:UIControl.class]) {
        root.tintColor = color;
    }

    for (UIView *sub in root.subviews) {
        LCS_ApplyToViewTree(sub, color);
    }
}

%hook UIView

- (void)didMoveToWindow {
    %orig;

    if (!LCS_Enabled || !self.window) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;

        NSString *n = NSStringFromClass(self.class);
        UIColor *color = nil;

        // Notification views
        if ([n containsString:@"NCNotification"] ||
            [n containsString:@"Notification"]) {
            color = LCSColorForMode(LCS_NotificationMode);
        }

        // Media player views
        if (!color && ([n containsString:@"MediaControls"] ||
                       [n containsString:@"NowPlaying"])) {
            color = LCSColorForMode(LCS_PlayerMode);
        }

        // Lock-screen Live Activity views only
        if (!color && [n containsString:@"Activity"]) {
            color = LCSColorForMode(LCS_LiveActivityMode);
        }

        if (color) LCS_ApplyToViewTree(self, color);
    });
}

%end

%ctor {
    @autoreleasepool {
        // Intentionally no global background-color hook.
        // Settings integration can be added once the target UI classes
        // are verified on a real iOS 16.6.1 device.
    }
}
