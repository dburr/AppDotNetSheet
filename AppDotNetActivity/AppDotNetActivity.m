//
//  AppDotNetActivity.m
//  SongTweeter
//
//  Created by Donald Burr on 3/23/13.
//
//

#import <AudioToolbox/AudioToolbox.h>

#import "AppDotNetActivity.h"

#import "AppDotNetClient.h"
#import "AppDotNetComposeViewController.h"
#import "AppDotNetCredentials.h"
#import "ImgurUploader.h"

@interface AppDotNetActivity ()
{
    SystemSoundID postSound;
}
@property (nonatomic, strong) AppDotNetComposeViewController *vc;
@property (nonatomic, strong) NSString *shareString;
@property (nonatomic, strong) UIImage *shareImage;
@property (nonatomic, strong) ImgurUploader *uploader;
@end

@implementation AppDotNetActivity
@synthesize vc = _vc;

- (id)init
{
    self = [super init];
    if (self)  {
        // INIT SOUND
        //Get the filename of the sound file:
		NSString *path = [NSString stringWithFormat:@"%@%@",
						  [[NSBundle mainBundle] resourcePath],
						  @"/post.aif"];
		//		NSString *path = [[NSBundle mainBundle] pathForResource:@"Over9000" ofType:@"mp3"];
		NSLog(@"got path %@", path);
		//Get a URL for the sound file
		NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
		NSLog(@"after nsurl got %@", filePath);
		//Use audio sevices to create the sound
		AudioServicesCreateSystemSoundID((CFURLRef)filePath, &postSound);
    }
    return self;
}

- (void)dealloc
{
    AudioServicesDisposeSystemSoundID(postSound);
    [super dealloc];
}

- (ImgurUploader *)uploader
{
    if (!_uploader)  {
        _uploader = [[ImgurUploader alloc] init];
    }
    return _uploader;
}

// REQUIRED:
// A reverse DNS style identifier to identify this activity (should include your app's identifier in it)
- (NSString *)activityType
{
    return @"com.DonaldBurr.SongTweeter.AppDotNet";
}

// REQUIRED:
// The title of the custom activity.  Show under its icon in the Activity VC.
- (NSString *)activityTitle
{
    return @"App.net";
}

// REQUIRED:
// The image used for the activity's icon in the Activity VC
- (UIImage *)activityImage
{
    // Note: These images need to have a transparent background and I recommend these sizes:
    // iPadShare@2x should be 126 px, iPadShare should be 53 px, iPhoneShare@2x should be 100
    // px, and iPhoneShare should be 50 px. I found these sizes to work for what I was making.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        return [UIImage imageNamed:@"appdotnet-ipad.png"];
    }
    
    return [UIImage imageNamed:@"appdotnet-iphone.png"];
}

// REQUIRED:
// Can this activity use the type of activity items being provided?
- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    DLog(@"%s", __FUNCTION__);
    return YES;
}

// REQUIRED:
// Called just before activityViewController (main method).  Do any prep work here.
- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    DLog(@"%s",__FUNCTION__);

    [AppDotNetClient initWithClientId:kAppDotNetClientId
                       andCallbackURL:kAppDotNetCallbackURL
                            andScopes:[kAppDotNetScopes componentsSeparatedByString:@" "]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        self.vc = [[AppDotNetComposeViewController alloc] initWithNibName:@"AppDotNetComposeViewController-ipad" bundle:nil];
    else
        self.vc = [[AppDotNetComposeViewController alloc] initWithNibName:@"AppDotNetComposeViewController-iphone" bundle:nil];
    self.vc.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)  {
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        self.vc.view.center = CGPointMake(screenWidth/2.0, screenHeight/2.0);
        DLog(@"FRAME = %@ BOUNDS = %@", NSStringFromCGRect(self.vc.view.frame), NSStringFromCGRect(self.vc.view.bounds));
    }

    self.shareString = [[NSString alloc] init];
    
    for (id item in activityItems)  {
        DLog(@"looking at item: %@", item);
        if ([item isKindOfClass:[NSString class]])  {
            self.shareString = [self.shareString stringByAppendingString:item];
        } else if ([item isKindOfClass:[UIImage class]])  {
            self.shareImage = item;
        }
    }
    
    DLog(@"share string = %@", self.shareString);
    if (self.shareImage)  {
        DLog(@"found an image to share");
        self.uploader.delegate = self;
        NSString *adnUploader = [[NSUserDefaults standardUserDefaults] stringForKey:@"adn_uploader_preference"];
        if ([adnUploader isEqualToString:@"imgur"])
            [self.uploader uploadImage:self.shareImage];
    }
}

// *** YOU NEED TO OVERRIDE ONE OF THE FOLLOWING **

// Override this if your activity requires some UI to be presented (e.g. a "tweet this" box that lets you edit a tweet
// before posting it to Twitter).  You should return your UI's view controller here.
- (UIViewController *)activityViewController
{
    DLog(@"%s",__FUNCTION__);
    //[self.vc.textView performSelectorOnMainThread:@selector(setText:) withObject:self.shareString waitUntilDone:YES];
    self.vc.defaultText = self.shareString;
    if (self.shareImage)
        self.vc.defaultImage = self.shareImage;
    //[self.vc.textView performSelector:@selector(setText:) withObject:self.shareString afterDelay:5.0];
    //self.vc.textView.text = @"It's you!";
    return self.vc;
}

- (void)didDismissAppDotNetComposeViewController:(AppDotNetComposeViewController *)controller withSuccess:(BOOL)success
{
    DLog(@"*** ADN controller indicated finished state ***");
    if (success)  {
        AudioServicesPlaySystemSound(postSound);
    }
    [self activityDidFinish:YES];
}

/*
// Override this if this activity requires no user input
- (void)performActivity
{
    // This is where you can do anything you want, and is the whole reason for creating a custom
    // UIActivity and UIActivityProvider
    
    DLog(@"Do it!");
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=yourappid"]];
    [self activityDidFinish:YES];
}
*/

- (void)imageUploadedWithURLString:(NSString*)urlString
{
    DLog(@"IMAGE UPLOADED WITH URL STRING: %@", urlString);
    self.shareString = [self.shareString stringByAppendingString:[NSString stringWithFormat:@" %@", urlString]];
    self.vc.defaultText = self.shareString;    
}

- (void)uploadProgressedToPercentage:(CGFloat)percentage
{
    DLog(@"UPLOAD PROGRESS: %.1f", percentage*100);
}

- (void)uploadFailedWithError:(NSError*)error
{
    DLog(@"AILED WITH ERROR: %@", [error localizedDescription]);
}

@end
