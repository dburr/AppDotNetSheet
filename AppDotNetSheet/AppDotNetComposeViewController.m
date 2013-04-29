//
//  AppDotNetComposeViewController.m
//  iOS-Example
//
//  Created by Stuart Hall on 18/08/12.
//  Copyright (c) 2012 Stuart Hall. All rights reserved.
//

#import "AppDotNetComposeViewController.h"

#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

#import "AppDotNetClient.h"

@interface AppDotNetComposeViewController ()
{
    BOOL sharingImage;
    IBOutlet UIImageView *imageView;
    CLLocationManager *locationManager;
    IBOutlet UILabel *shareLocationLabel;
    BOOL shareLocation;
    CLLocationCoordinate2D currentLocation;
    CLLocationDistance currentAltitude;
    CLLocationDistance currentHorizontalAccuracy;
    CLLocationDistance currentVerticalAccuracy;
    BOOL validLocation;
}

- (IBAction)cancelImageSharing:(id)sender;

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation;

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error;
@end

@implementation AppDotNetComposeViewController

@synthesize defaultText = _defaultText;
@synthesize defaultImage = _defaultImage;

@synthesize containerView;

@synthesize composeView;
@synthesize textView;
@synthesize characterCountLabel;
@synthesize backgroundView;
@synthesize screenshotView;
@synthesize logoutButton;

@synthesize loginView;
@synthesize webView;
@synthesize activityView;

@synthesize sendingView;

static int const kMaxCharacters = 256;
// XXX update this to the length of typical app.net filestore urls
static int const kImageURLLength = 20;

- (id)init
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        self = [super initWithNibName:@"AppDotNetComposeViewController-ipad" bundle:nil];
    else
        self = [super initWithNibName:@"AppDotNetComposeViewController-iphone" bundle:nil];
    if (self) {
    }
    return self;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    if (CGRectContainsPoint([shareLocationLabel frame], [touch locationInView:self.view]))
    {
        [self toggleShareLocation];
    }
}

- (void) toggleShareLocation
{
    NSString *untickedBoxStr = [[NSString alloc] initWithString:@"\u2610 Share location?"];
    NSString *tickedBoxStr = [[NSString alloc] initWithString:@"\u2611 Share location?"];
    
    if ([shareLocationLabel.text isEqualToString:tickedBoxStr])
    {
        shareLocationLabel.text = untickedBoxStr;
        shareLocation = NO;
        [locationManager stopUpdatingLocation];
    }
    else
    {
        shareLocationLabel.text = tickedBoxStr;
        shareLocation = YES;
        [locationManager startUpdatingLocation];
    }
    
    [tickedBoxStr release];
    [untickedBoxStr release];
}

- (void)setDefaultText:(NSString *)defaultText
{
    [_defaultText release];
    _defaultText = [defaultText retain];
    self.textView.text = self.defaultText;
    [self updateCharacterCount];
}

- (void)setDefaultImage:(UIImage *)defaultImage
{
    DLog(@"SETTING DEFAULT IMAGE");
    _defaultImage = [defaultImage retain];
    if (defaultImage)  {
        sharingImage = YES;
        imageView.image = _defaultImage;
        if (self.isViewLoaded && self.view.window)
            [self showImageView];
    } else {
        sharingImage = NO;
    }
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    NSLog(@"Location: %@", [newLocation description]);
    currentLocation = newLocation.coordinate;
    currentAltitude = newLocation.altitude;
    currentHorizontalAccuracy = newLocation.horizontalAccuracy;
    currentVerticalAccuracy = newLocation.verticalAccuracy;
    validLocation = YES;
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
	NSLog(@"Error: %@", [error description]);
    validLocation = NO;
}

- (void)showImageView
{
    DLog(@"SHOWING IMAGE VIEW");
    [UIView animateWithDuration:0.3 animations:^() {
        imageView.alpha = 1.0;
        CGRect newFrame = textView.frame;
        DLog(@"FRAME OLD = %@", NSStringFromCGRect(newFrame));
        newFrame.size.width -= (imageView.bounds.size.width + 5);
        DLog(@"FRAME NEW = %@", NSStringFromCGRect(newFrame));
        textView.frame = newFrame;
    }];
}

- (void)hideImageView
{
    DLog(@"HIDING IMAGE VIEW");
    [UIView animateWithDuration:0.3 animations:^() {
        imageView.alpha = 0.0;
        CGRect newFrame = textView.frame;
        DLog(@"FRAME OLD = %@", NSStringFromCGRect(newFrame));
        newFrame.size.width += (imageView.bounds.size.width + 5);
        DLog(@"FRAME NEW = %@", NSStringFromCGRect(newFrame));
        textView.frame = newFrame;
    }];
}

- (IBAction)cancelImageSharing:(id)sender
{
    DLog(@"TAP GESTURE FIRING");
    UITapGestureRecognizer *tgr = sender;
    if (tgr.state == UIGestureRecognizerStateEnded) {
        DLog("image sharing canceled");
        self.defaultImage = nil;
        [self hideImageView];
        DLog(@"self.defaultImage = %@", self.defaultImage);
    }
    // strip out imgur urls if present
    NSRange rangeOfSubstring = [self.textView.text rangeOfString:@"http://"];
    
    if(rangeOfSubstring.location != NSNotFound)
    {
        self.textView.text = [self.textView.text substringToIndex:rangeOfSubstring.location-1];
        [self updateCharacterCount];
    }
}

- (void)viewDidLoad
{
    DLog("APPDOTNET VIEW DID LOAD");
    [super viewDidLoad];
    
    [textView becomeFirstResponder];
    
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    locationManager.purpose = @"Location is required if you wish to share your location, duh";
    
    [self updateCharacterCount];
    
    // Load the login in the background
    webView.layer.masksToBounds = YES;
    webView.backgroundColor = [UIColor clearColor];
    
    // Hide the shadows
    for (UIView* shadowView in [webView.scrollView subviews]) {
        if ([shadowView isKindOfClass:[UIImageView class]]) {
            [shadowView setHidden:YES];
        }
    }
    
    // Logout button status
    logoutButton.hidden = ![AppDotNetClient hasToken];
    
    // set up tapgr
    UITapGestureRecognizer *tgr = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancelImageSharing:)] autorelease];
    tgr.numberOfTouchesRequired = 1;
    tgr.numberOfTapsRequired = 1;
    [imageView addGestureRecognizer:tgr];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

#pragma mark Sneaky Background Image
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)  {
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        self.view.center = CGPointMake(screenWidth/2.0, screenHeight/2.0);

        DLog(@"FRAMES/BOUNDS:");
        DLog(@"view: FRAME = %@ BOUNDS = %@", NSStringFromCGRect(self.view.frame), NSStringFromCGRect(self.view.bounds));
        DLog(@"containerView: FRAME = %@ BOUNDS = %@", NSStringFromCGRect(self.containerView.frame), NSStringFromCGRect(self.containerView.bounds));
        DLog(@"composeView: FRAME = %@ BOUNDS = %@", NSStringFromCGRect(self.composeView.frame), NSStringFromCGRect(self.composeView.bounds));
        DLog(@"backgroundView: FRAME = %@ BOUNDS = %@", NSStringFromCGRect(self.backgroundView.frame), NSStringFromCGRect(self.backgroundView.bounds));
        DLog(@"loginView: FRAME = %@ BOUNDS = %@", NSStringFromCGRect(self.loginView.frame), NSStringFromCGRect(self.loginView.bounds));
        DLog(@"sendingView: FRAME = %@ BOUNDS = %@", NSStringFromCGRect(self.sendingView.frame), NSStringFromCGRect(self.sendingView.bounds));
        
        //self.view.center = self.presentingViewController.view.center;
    }

    // XXX backgroundView alpha was 0.699999988079071
    
    if (self.defaultText)  {
        self.textView.text = self.defaultText;
        //self.defaultText = nil;
        [self updateCharacterCount];
    }
    
    /*
    // Grab a screenshot to put underneath
    UIView *parentView = self.presentingViewController.view;
    UIGraphicsBeginImageContext(parentView.bounds.size);
    [parentView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *parentViewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    screenshotView.image = parentViewImage;
     */
    
    // if there is a sharing image, show it
    if (self.defaultImage && imageView.alpha == 0.0)  {
        DLog(@"Image detected, showing view");
        imageView.image = self.defaultImage;
        [self showImageView];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    DLog(@"ADN controller disappearing");
    if (shareLocation)
        [locationManager stopUpdatingLocation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)closeWithSuccess:(BOOL)success
{
    DLog(@"CLOSING");
    // Hide the lightbox
    self.backgroundView.alpha = 0;
    
     /*
    // Slide the image with the animation
    [UIView animateWithDuration:0.4
                     animations:^{
                         CGRect r = self.screenshotView.frame;
                         r.origin.y = -r.size.height;
                         self.screenshotView.frame = r;
                     }];
     */
    //[self dismissModalViewControllerAnimated:YES];
    if ([self.delegate respondsToSelector:@selector(didDismissAppDotNetComposeViewController:withSuccess:)])  {
        DLog(@"sending dismissal message");
        [self.delegate didDismissAppDotNetComposeViewController:self withSuccess:success];
    }
}

#pragma mark - Buttons

- (IBAction)onSend:(id)sender
{
    if ([AppDotNetClient hasToken]) {
        // Authenticated, send away
        [self send];
    }
    else {
        // Flip to authentication view
        self.loginView.frame = self.composeView.frame;
        [UIView transitionWithView:self.containerView
                          duration:1
                           options:UIViewAnimationOptionTransitionFlipFromRight
                        animations:^{
                            [self.composeView removeFromSuperview];
                            [self.containerView addSubview:loginView];
                        }
                        completion:NULL];
        
        // Start the request
        [webView loadRequest:[NSURLRequest requestWithURL:[AppDotNetClient authenticationURL]]];
    }
}

- (IBAction)onCancel:(UIButton*)sender
{
    // Disable the down state before the animation
    sender.adjustsImageWhenHighlighted = NO;
    [self closeWithSuccess:NO];
    /*
    if ([self.delegate respondsToSelector:@selector(didDismissAppDotNetComposeViewController:withSuccess:)])  {
        [self.delegate didDismissAppDotNetComposeViewController:self withSuccess:NO];
    }
     */
}

- (IBAction)onCancelLogin:(id)sender
{
    // Flip back to the compose view
    [UIView transitionWithView:self.containerView
                      duration:1
                       options:UIViewAnimationOptionTransitionFlipFromLeft
                    animations:^{
                        [self.loginView removeFromSuperview];
                        [self.containerView addSubview:composeView];
                    }
                    completion:^(BOOL finished) {
                        // Start editing again
                        if (!sendingView.superview)
                            [textView becomeFirstResponder];
                    }];
}

- (IBAction)onLogout:(id)sender
{
    [AppDotNetClient forgetToken];
    logoutButton.hidden = YES;
}

#pragma mark - Sending

- (void)send
{
    // Ensure there is some text to send
    if (self.textView.text.length == 0) {
        [[[UIAlertView alloc] initWithTitle:nil
                                    message:@"Please enter a message"
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
        return;
    }
    
    // Show some progress
    [self.composeView addSubview:sendingView];
    sendingView.frame = CGRectMake(composeView.frame.size.width/2 - sendingView.frame.size.width/2,
                                   composeView.frame.size.height/2 - sendingView.frame.size.height/2,
                                   sendingView.frame.size.width,
                                   sendingView.frame.size.height);
    textView.hidden = YES;
    if (imageView.hidden == NO || imageView.alpha == 1.0)
        imageView.hidden = YES;
    
    // Post
    UIImage *theImage = nil;
    NSString *adnUploader = [[NSUserDefaults standardUserDefaults] stringForKey:@"adn_uploader_preference"];
    if ([adnUploader isEqualToString:@"appdotnet"])
        theImage = self.defaultImage;
    DLog(@"SHARING, image=%@", theImage);

    double latitude = 0, longitude = 0, altitude = 0, horizontalAccuracy = 0, verticalAccuracy = 0;
    if (shareLocation && validLocation)  {
        latitude = currentLocation.latitude;
        longitude = currentLocation.longitude;
        altitude = currentAltitude;
        horizontalAccuracy = currentHorizontalAccuracy;
        verticalAccuracy = currentVerticalAccuracy;
    }

    [AppDotNetClient postUpdate:self.textView.text
                      withImage:theImage
                       latitude:latitude
                      longitude:longitude
                       altitude:altitude
             horizontalAccuracy:horizontalAccuracy
               verticalAccuracy:verticalAccuracy
                      replyToId:nil
                    annotations:nil
                          links:nil
                        success:^(NSString *identifier) {
                            // Success!
                            self.sendingView.hidden = YES;
                            [self closeWithSuccess:YES];
                            /*
                            if ([self.delegate respondsToSelector:@selector(didDismissAppDotNetComposeViewController:withSuccess:)])  {
                                [self.delegate didDismissAppDotNetComposeViewController:self withSuccess:YES];
                            }
                             */
                        } failure:^(NSError *error, NSNumber *errorCode, NSString *message) {
                            // http://sadtrombone.com/
                            self.sendingView.hidden = YES;
                            self.textView.hidden = NO;
                            if (self.defaultImage)
                                imageView.hidden = NO;
                            
                            [[[UIAlertView alloc] initWithTitle:nil
                                                        message:message ?: @"Sorry, an error occured trying to post the update."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] show];
                        }];
}

#pragma mark - Character Count

- (void)updateCharacterCount
{
    int charactersRemaining = kMaxCharacters - self.textView.text.length;
    if (sharingImage)
        charactersRemaining -= kImageURLLength;
    characterCountLabel.text = [NSString stringWithFormat:@"%d", charactersRemaining];
    characterCountLabel.textColor = charactersRemaining < 0 ? [UIColor colorWithRed:0.7 green:0 blue:0 alpha:1] : [UIColor colorWithWhite:0.48 alpha:1];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    [self updateCharacterCount];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)wv
{
    if ([AppDotNetClient parseURLForToken:wv.request.URL]) {
        // We have the token!
        logoutButton.hidden = NO;
        [webView stopLoading];
        [self onCancelLogin:wv];
        [self send];
    }
    else {
        // Scroll down to the login
        [webView stringByEvaluatingJavaScriptFromString:@"$('.navbar').hide();"];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)  {
          [webView stringByEvaluatingJavaScriptFromString:@"window.scrollBy(220,185);"];
        } else {
          [webView stringByEvaluatingJavaScriptFromString:@"window.scrollBy(5,157);"];
        }

        
        [activityView stopAnimating];
        webView.hidden = NO;
    }
}

- (void)webViewDidStartLoad:(UIWebView *)wv
{
    [activityView startAnimating];
    webView.hidden = YES;
}

@end
