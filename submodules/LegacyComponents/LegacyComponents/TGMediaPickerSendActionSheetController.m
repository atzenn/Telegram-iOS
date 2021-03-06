#import "TGMediaPickerSendActionSheetController.h"
#import "LegacyComponentsInternal.h"

#import "TGFont.h"
#import "TGImageUtils.h"
#import "TGModernButton.h"
#import "TGMediaAssetsController.h"

@interface TGMediaPickerSendActionSheetItemView : UIView
{
    TGModernButton *_buttonView;
    UILabel *_buttonLabel;
    UIImageView *_buttonIcon;
}

@property (nonatomic, readonly) UILabel *buttonLabel;
@property (nonatomic, copy) void (^pressed)(void);

@end

@implementation TGMediaPickerSendActionSheetItemView

- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon {
    self = [super init];
    if (self != nil) {
        _buttonView = [[TGModernButton alloc] init];
        _buttonView.adjustsImageWhenHighlighted = false;
        
        __weak TGMediaPickerSendActionSheetItemView *weakSelf = self;
        _buttonView.highlitedChanged = ^(bool highlighted) {
            __strong TGMediaPickerSendActionSheetItemView *strongSelf = weakSelf;
            if (strongSelf != nil) {
                if (highlighted) {
                    strongSelf->_buttonView.backgroundColor = UIColorRGB(0x363636);
                } else {
                    strongSelf->_buttonView.backgroundColor = [UIColor clearColor];
                }
            }
        };
        [_buttonView addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_buttonView];
        
        _buttonLabel = [[UILabel alloc] init];
        _buttonLabel.font = TGSystemFontOfSize(17.0f);
        _buttonLabel.text = title;
        _buttonLabel.textColor = [UIColor whiteColor];
        [_buttonLabel sizeToFit];
        _buttonLabel.userInteractionEnabled = false;
        [self addSubview:_buttonLabel];
        
        _buttonIcon = [[UIImageView alloc] init];
        _buttonIcon.image = TGTintedImage(icon, [UIColor whiteColor]);
        [_buttonIcon sizeToFit];
        [self addSubview:_buttonIcon];
    }
    return self;
}

- (void)buttonPressed {
    if (self.pressed != nil)
        self.pressed();
}

- (void)layoutSubviews {
    _buttonLabel.frame = CGRectMake(16.0, 11.0, _buttonLabel.frame.size.width, _buttonLabel.frame.size.height);
    _buttonView.frame = self.bounds;
    _buttonIcon.frame = CGRectMake(self.bounds.size.width - _buttonIcon.frame.size.width - 12.0, 9.0, _buttonIcon.frame.size.width, _buttonIcon.frame.size.height);
}

@end

@interface TGMediaPickerSendActionSheetController ()
{
    id<LegacyComponentsContext> _context;
    
    CGRect _sendButtonFrame;
    bool _canSendSilently;
    bool _canSchedule;
    bool _autorotationWasEnabled;
    bool _dismissed;
    
    UIVisualEffectView *_effectView;
    TGModernButton *_sendButton;
    
    UIView *_containerView;
    UIView *_separatorView;
    TGMediaPickerSendActionSheetItemView *_sendSilentlyButton;
    TGMediaPickerSendActionSheetItemView *_scheduleButton;
}
@end

@implementation TGMediaPickerSendActionSheetController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context sendButtonFrame:(CGRect)sendButtonFrame canSendSilently:(bool)canSendSilently canSchedule:(bool)canSchedule {
    self = [super initWithContext:context];
    if (self != nil) {
        _context = context;
        _sendButtonFrame = sendButtonFrame;
        _canSendSilently = canSendSilently;
        _canSchedule = canSchedule;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    _effectView = [[UIVisualEffectView alloc] initWithEffect:nil];
    if (iosMajorVersion() >= 9) {
        _effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }
    [self.view addSubview:_effectView];
    
    _containerView = [[UIView alloc] init];
    _containerView.backgroundColor = UIColorRGB(0x1f1f1f);
    _containerView.clipsToBounds = true;
    _containerView.layer.cornerRadius = 12.0;
    [self.view addSubview:_containerView];
    
    __weak TGMediaPickerSendActionSheetController *weakSelf = self;
    if (_canSendSilently) {
        _sendSilentlyButton = [[TGMediaPickerSendActionSheetItemView alloc] initWithTitle:TGLocalized(@"Conversation.SendMessage.SendSilently") icon:TGComponentsImageNamed(@"MediaMute")];
        _sendSilentlyButton.pressed = ^{
            __strong TGMediaPickerSendActionSheetController *strongSelf = weakSelf;
            [strongSelf sendSilentlyPressed];
        };
        [_containerView addSubview:_sendSilentlyButton];
    }
    
    if (_canSchedule) {
        _scheduleButton = [[TGMediaPickerSendActionSheetItemView alloc] initWithTitle:TGLocalized(@"Conversation.SendMessage.ScheduleMessage") icon:TGComponentsImageNamed(@"MediaSchedule")];
        _scheduleButton.pressed = ^{
            __strong TGMediaPickerSendActionSheetController *strongSelf = weakSelf;
            [strongSelf schedulePressed];
        };
        [_containerView addSubview:_scheduleButton];
    }
    
    TGMediaAssetsPallete *pallete = nil;
    if ([[LegacyComponentsGlobals provider] respondsToSelector:@selector(mediaAssetsPallete)])
        pallete = [[LegacyComponentsGlobals provider] mediaAssetsPallete];
    
    UIImage *doneImage = pallete != nil ? pallete.sendIconImage : TGComponentsImageNamed(@"PhotoPickerSendIcon");
    
    _sendButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0, 0.0, 33.0, 33.0)];
    _sendButton.adjustsImageWhenDisabled = false;
    _sendButton.adjustsImageWhenHighlighted = false;
    [_sendButton setImage:doneImage forState:UIControlStateNormal];
    [_sendButton addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_sendButton];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _autorotationWasEnabled = [TGViewController autorotationAllowed];
    [TGViewController disableAutorotation];
    
    [self animateIn];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] init];
    [tapRecognizer addTarget:self action:@selector(dimTapGesture)];
    [_effectView addGestureRecognizer:tapRecognizer];
}

- (void)dimTapGesture {
    [self animateOut:true];
}

- (BOOL)prefersStatusBarHidden {
    return true;
}

- (bool)statusBarShouldBeHidden {
    return true;
}

- (void)animateIn {
    if (_effectView.effect != nil) {
        _effectView.alpha = 0.0f;
    }
    [UIView animateWithDuration:0.3 animations:^{
        if (_effectView.effect == nil) {
            _effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        } else {
            _effectView.alpha = 1.0f;
        }
    }];
    
    CGPoint targetPosition = _containerView.center;
    _containerView.center = CGPointMake(targetPosition.x + 160.0, targetPosition.y + 44.0);
    _containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    [UIView animateWithDuration:0.42 delay:0.0 usingSpringWithDamping:104.0 initialSpringVelocity:0.0 options:kNilOptions animations:^{
        _containerView.transform = CGAffineTransformIdentity;
        _containerView.center = targetPosition;
    } completion:nil];
    
    _containerView.alpha = 0.0f;
    [UIView animateWithDuration:0.2 animations:^{
        _containerView.alpha = 1.0f;
    }];
}

- (void)animateOut:(bool)cancel {
    [UIView animateWithDuration:0.2 animations:^{
        if (iosMajorVersion() >= 9) {
            _effectView.effect = nil;
        } else {
            _effectView.alpha = 0.0f;
        }
        
        _containerView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (!cancel) {
            [self dismiss];
        }
    }];
    
    if (cancel) {
        _dismissed = true;
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
            _containerView.center = CGPointMake(_containerView.center.x + 160.0, _containerView.center.y + 44.0);
            _containerView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        } completion:^(BOOL finished) {
            [self dismiss];
        }];
    }
    
    if (_autorotationWasEnabled) {
         [TGViewController enableAutorotation];
    }
}

- (void)viewDidLayoutSubviews {
    _effectView.frame = self.view.bounds;
    _sendButton.frame = _sendButtonFrame;
    
    CGFloat itemHeight = 44.0;
    CGFloat containerWidth = 240.0;
    CGFloat containerHeight = _canSendSilently && _canSchedule ? itemHeight * 2.0 : itemHeight;
    containerWidth = MAX(containerWidth, MAX(_sendSilentlyButton.buttonLabel.frame.size.width, _scheduleButton.buttonLabel.frame.size.width) + 84.0);
    if (!_dismissed) {
        _containerView.frame = CGRectMake(CGRectGetMaxX(_sendButtonFrame) - containerWidth - 8.0, _sendButtonFrame.origin.y - containerHeight - 4.0, containerWidth, containerHeight);
    }
    
    _sendSilentlyButton.frame = CGRectMake(0.0, 0.0, containerWidth, itemHeight);
    _scheduleButton.frame = CGRectMake(0.0, containerHeight - itemHeight, containerWidth, itemHeight);
}

- (void)sendPressed {
    [self animateOut:false];
    
    if (self.send != nil)
        self.send();
}

- (void)sendSilentlyPressed {
    [self animateOut:false];
    
    if (self.sendSilently != nil)
        self.sendSilently();
}

- (void)schedulePressed {
    [self animateOut:false];
    
    if (self.schedule != nil)
        self.schedule();
}

@end
