#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol AutoTouchJSExport <JSExport>
- (void)showNotification;
- (void)startAutoTouch;
- (void)stopAutoTouch;
@end

@interface AutoTouch : NSObject <AutoTouchJSExport>
@property UIWindow* myWindow;
@property NSTimer* scanTimer;
@property BOOL isScanning;
@property (nonatomic, assign) CGPoint targetPoint;
@end

@implementation AutoTouch

-(instancetype)init {
    if (self = [super init]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (NSClassFromString(@"UIWindowScene")) {
                UIWindowScene* theScene = nil;
                for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes) {
                    if(!theScene && windowScene.activationState==UISceneActivationStateForegroundInactive)
                        theScene = windowScene;
                    if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                        theScene = windowScene;
                        break;
                    }
                }
                self.myWindow = [[UIWindow alloc] initWithWindowScene:theScene];
            } else {
                self.myWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            }
            
            self.myWindow.windowLevel = UIWindowLevelAlert;
            self.myWindow.rootViewController = [[UIViewController alloc] init];
        });
    }
    return self;
}

-(void)showNotification {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thông báo" 
                                                                     message:@"Auto Touch đã được kích hoạt!" 
                                                              preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" 
                                                style:UIAlertActionStyleDefault 
                                              handler:^(UIAlertAction *action) {
            [self.myWindow setHidden:YES];
        }]];
        
        [self.myWindow setHidden:NO];
        [[self.myWindow rootViewController] presentViewController:alert animated:YES completion:nil];
    });
}

-(void)startAutoTouch {
    if (self.isScanning) return;
    
    self.isScanning = YES;
    NSLog(@"Auto Touch đã bắt đầu");
    
    // Set tap target point (adjust coordinates as needed)
    self.targetPoint = CGPointMake(200, 300);
    
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 
                                                    target:self 
                                                  selector:@selector(performAutoTouch) 
                                                  userInfo:nil 
                                                   repeats:YES];
}

-(void)stopAutoTouch {
    if (!self.isScanning) return;
    
    [self.scanTimer invalidate];
    self.scanTimer = nil;
    self.isScanning = NO;
    NSLog(@"Auto Touch đã dừng");
}

-(void)performAutoTouch {
    if (!self.isScanning) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Get current window
        UIWindow *window = [[UIApplication sharedApplication] windows][0];
        if (!window) {
            NSLog(@"Không tìm thấy window");
            return;
        }
        
        // Find view at target point
        UIView *targetView = [window hitTest:self.targetPoint withEvent:nil];
        if (!targetView) {
            NSLog(@"Không tìm thấy view tại điểm tap");
            return;
        }
        
        // Send touches
        [self sendTouchesToView:targetView atPoint:self.targetPoint inWindow:window];
    });
}

-(void)sendTouchesToView:(UIView *)view atPoint:(CGPoint)point inWindow:(UIWindow *)window {
    // Convert point to view's coordinate space
    CGPoint pointInView = [window convertPoint:point toView:view];
    
    // Create touch
    UITouch *touch = [[UITouch alloc] init];
    
    // Set touch properties using KVC
    [touch setValue:view forKey:@"_view"];
    [touch setValue:window forKey:@"_window"];
    [touch setValue:[NSValue valueWithCGPoint:pointInView] forKey:@"_locationInView"];
    [touch setValue:[NSValue valueWithCGPoint:point] forKey:@"_previousLocationInView"];
    [touch setValue:@(UITouchPhaseBegan) forKey:@"_phase"];
    
    // Create touch set
    NSSet *touches = [NSSet setWithObject:touch];
    
    // Send touch events
    [view touchesBegan:touches withEvent:nil];
    
    // Add delay between touch down and up
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), 
                  dispatch_get_main_queue(), ^{
        [touch setValue:@(UITouchPhaseEnded) forKey:@"_phase"];
        [view touchesEnded:touches withEvent:nil];
    });
}

@end

// Constructor
static AutoTouch *touchInstance;

__attribute__((constructor)) static void initialize() {
    @autoreleasepool {
        touchInstance = [[AutoTouch alloc] init];
    }
}
