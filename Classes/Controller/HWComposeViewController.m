//
//  HWComposeViewController.m
//  黑马微博2期
//
//  Created by apple on 14-10-20.
//  Copyright (c) 2014年 heima. All rights reserved.
//

// 通知
// 表情选中的通知
#define HWEmotionDidSelectNotification @"HWEmotionDidSelectNotification"
#define HWSelectEmotionKey @"HWSelectEmotionKey"
// 删除文字的通知
#define HWEmotionDidDeleteNotification @"HWEmotionDidDeleteNotification"


#import "HWComposeViewController.h"
#import "HWEmotionTextView.h"
#import "HWComposeToolbar.h"
#import "HWComposePhotosView.h"
#import "HWEmotionKeyboard.h"
#import "HWEmotion.h"

#import "UIView+Extension.h"

@interface HWComposeViewController () <UITextViewDelegate, HWComposeToolbarDelegate,UINavigationControllerDelegate, UIImagePickerControllerDelegate>
/** 输入控件 */
@property (nonatomic, weak) HWEmotionTextView *textView;
/** 键盘顶部的工具条 */
@property (nonatomic, weak) HWComposeToolbar *toolbar;
/** 相册（存放拍照或者相册中选择的图片） */
@property (nonatomic, weak) HWComposePhotosView *photosView;
/** 表情键盘 */
@property (nonatomic, strong) HWEmotionKeyboard *emotionKeyboard;
/** 是否正在切换键盘 */
@property (nonatomic, assign) BOOL switchingKeybaord;
@end

@implementation HWComposeViewController
#pragma mark - 懒加载
- (HWEmotionKeyboard *)emotionKeyboard
{
    if (!_emotionKeyboard) {
        self.emotionKeyboard = [[HWEmotionKeyboard alloc] init];
        // 键盘的宽度
        self.emotionKeyboard.width = self.view.width;
        self.emotionKeyboard.height = 216;
    }
    return _emotionKeyboard;
}

#pragma mark - 系统方法
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 设置导航栏内容
    [self setupNav];
    
    // 添加输入控件
    [self setupTextView];
    
    // 添加工具条
    [self setupToolbar];
    
    // 添加相册
    [self setupPhotosView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // 成为第一响应者（能输入文本的控件一旦成为第一响应者，就会叫出相应的键盘）
    [self.textView becomeFirstResponder];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 初始化方法
/**
 * 添加相册
 */
- (void)setupPhotosView
{
    HWComposePhotosView *photosView = [[HWComposePhotosView alloc] init];
    photosView.y = 100;
    photosView.width = self.view.width;
    // 随便写的
    photosView.height = self.view.height;
    [self.textView addSubview:photosView];
    self.photosView = photosView;
}
/**
 * 添加工具条
 */
- (void)setupToolbar
{
    HWComposeToolbar *toolbar = [[HWComposeToolbar alloc] init];
    toolbar.width = self.view.width;
    toolbar.height = 44;
    toolbar.y = self.view.height - toolbar.height;
    toolbar.delegate = self;
    [self.view addSubview:toolbar];
    self.toolbar = toolbar;
}

/**
 * 设置导航栏内容
 */
- (void)setupNav
{
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleDone target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"发送" style:UIBarButtonItemStyleDone target:self action:@selector(finish)];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    

    self.title = @"iCocos";

}


//完成按钮
-(void)finish
{
    
}
/**
 * 添加输入控件
 */
- (void)setupTextView
{
    // 在这个控制器中，textView的contentInset.top默认会等于64
    HWEmotionTextView *textView = [[HWEmotionTextView alloc] init];
    // 垂直方向上永远可以拖拽（有弹簧效果）
    textView.alwaysBounceVertical = YES;
    textView.frame = self.view.bounds;
    textView.font = [UIFont systemFontOfSize:15];
    textView.delegate = self;
    textView.placeholder = @"分享新鲜事...";
    [self.view addSubview:textView];
    self.textView = textView;
    
    // 文字改变的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange) name:UITextViewTextDidChangeNotification object:textView];
    
    // 键盘通知
    // 键盘的frame发生改变时发出的通知（位置和尺寸）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    
    // 表情选中的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emotionDidSelect:) name:HWEmotionDidSelectNotification object:nil];
    
    // 删除文字的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emotionDidDelete) name:HWEmotionDidDeleteNotification object:nil];
}

#pragma mark - 监听方法
/**
 *  删除文字
 */
- (void)emotionDidDelete
{
    [self.textView deleteBackward];
}

/**
 *  表情被选中了
 */
- (void)emotionDidSelect:(NSNotification *)notification
{
    HWEmotion *emotion = notification.userInfo[HWSelectEmotionKey];
    [self.textView insertEmotion:emotion];
}

/**
 * 键盘的frame发生改变时调用（显示、隐藏等）
 */
- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    // 如果正在切换键盘，就不要执行后面的代码
    if (self.switchingKeybaord) return;
    
    NSDictionary *userInfo = notification.userInfo;
    // 动画的持续时间
    double duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    // 键盘的frame
    CGRect keyboardF = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    // 执行动画
    [UIView animateWithDuration:duration animations:^{
        // 工具条的Y值 == 键盘的Y值 - 工具条的高度
        if (keyboardF.origin.y > self.view.height) { // 键盘的Y值已经远远超过了控制器view的高度
            self.toolbar.y = self.view.height - self.toolbar.height;
        } else {
            self.toolbar.y = keyboardF.origin.y - self.toolbar.height;
        }
    }];
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}



/**
 * 监听文字改变
 */
- (void)textDidChange
{
    self.navigationItem.rightBarButtonItem.enabled = self.textView.hasText;
}

#pragma mark - UITextViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
}

#pragma mark - HWComposeToolbarDelegate
- (void)composeToolbar:(HWComposeToolbar *)toolbar didClickButton:(HWComposeToolbarButtonType)buttonType
{
    switch (buttonType) {
        case HWComposeToolbarButtonTypeCamera: // 拍照
            [self openCamera];
            break;
            
        case HWComposeToolbarButtonTypePicture: // 相册
            [self openAlbum];
            break;
            
        case HWComposeToolbarButtonTypeMention: // @
            break;
            
        case HWComposeToolbarButtonTypeTrend: // #
            break;
            
        case HWComposeToolbarButtonTypeEmotion: // 表情\键盘
            [self switchKeyboard];
            break;
    }
}

#pragma mark - 其他方法
/**
 *  切换键盘
 */
- (void)switchKeyboard
{
    // self.textView.inputView == nil : 使用的是系统自带的键盘
    if (self.textView.inputView == nil) { // 切换为自定义的表情键盘
        self.textView.inputView = self.emotionKeyboard;
        
        // 显示键盘按钮
        self.toolbar.showKeyboardButton = YES;
    } else { // 切换为系统自带的键盘
        self.textView.inputView = nil;
        
        // 显示表情按钮
        self.toolbar.showKeyboardButton = NO;
    }
    
    // 开始切换键盘
    self.switchingKeybaord = YES;
    
    // 退出键盘
    [self.textView endEditing:YES];
    
    // 结束切换键盘
    self.switchingKeybaord = NO;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 弹出键盘
        [self.textView becomeFirstResponder];
    });
}

- (void)openCamera
{
    [self openImagePickerController:UIImagePickerControllerSourceTypeCamera];
}

- (void)openAlbum
{
    // 如果想自己写一个图片选择控制器，得利用AssetsLibrary.framework，利用这个框架可以获得手机上的所有相册图片
    // UIImagePickerControllerSourceTypePhotoLibrary > UIImagePickerControllerSourceTypeSavedPhotosAlbum
    [self openImagePickerController:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (void)openImagePickerController:(UIImagePickerControllerSourceType)type
{
    if (![UIImagePickerController isSourceTypeAvailable:type]) return;
    
    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
    ipc.sourceType = type;
    ipc.delegate = self;
    [self presentViewController:ipc animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate
/**
 * 从UIImagePickerController选择完图片后就调用（拍照完毕或者选择相册图片完毕）
 */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    // info中就包含了选择的图片
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    
    // 添加图片到photosView中
    [self.photosView addPhoto:image];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    
}

@end