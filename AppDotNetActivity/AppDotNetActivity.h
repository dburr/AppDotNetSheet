//
//  AppDotNetActivity.h
//  SongTweeter
//
//  Created by Donald Burr on 3/23/13.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AppDotNetComposeViewController.h"
#import "ImgurUploader.h"

@interface AppDotNetActivity : UIActivity <AppDotNetComposeViewControllerDelegate, ImgurUploaderDelegate>

@end
