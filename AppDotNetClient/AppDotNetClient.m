//
//  AppDotNetClient.m
//  iOS-Example
//
//  Created by Stuart Hall on 19/08/12.
//  Copyright (c) 2012 Stuart Hall. All rights reserved.
//

#import "AppDotNetClient.h"

#import "AFJSONRequestOperation.h"

@interface AppDotNetClient()
@property (nonatomic, copy) NSString* token;

@property (nonatomic, copy) NSString* clientId;
@property (nonatomic, copy) NSString* callbackURL;
@property (nonatomic, strong) NSArray* scopes;

+ (NSString *)GetUUID;
@end

@implementation AppDotNetClient

static NSString* const kBaseURLString = @"https://alpha-api.app.net";
static NSString* const kTokenKey = @"!kAppDotNetTokenKey";

@synthesize token=_token;

@synthesize clientId;
@synthesize callbackURL;
@synthesize scopes;

+ (NSString *)GetUUID;
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return [(NSString *)string autorelease];
}

+ (AppDotNetClient *)sharedClient
{
    static AppDotNetClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[AppDotNetClient alloc] initWithBaseURL:[NSURL URLWithString:kBaseURLString]];
    });
    
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    
    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    
    // Accept HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
	[self setDefaultHeader:@"Accept" value:@"application/json"];
    [self setParameterEncoding:AFFormURLParameterEncoding];
    [self setParameterEncoding:AFJSONParameterEncoding];
    
    // Load the token
    self.token = [[NSUserDefaults standardUserDefaults] objectForKey:kTokenKey];
    
    return self;
}

+ (void)initWithClientId:(NSString*)clientId
          andCallbackURL:(NSString*)callbackURL
               andScopes:(NSArray*)scopes
{
    // All values are required
    assert(clientId);
    assert(callbackURL);
    assert(scopes);
    
    // Store the params, calling sharedClient will
    // ensure we are initialised
    self.sharedClient.clientId = clientId;
    self.sharedClient.callbackURL = callbackURL;
    self.sharedClient.scopes = scopes;
}

+ (BOOL)hasToken
{
    return self.sharedClient.token.length > 0;
}

- (void)setToken:(NSString *)token
{
    // Store the token and persist for next time
    _token = token;
    [[NSUserDefaults standardUserDefaults] setValue:token
                                             forKey:kTokenKey];
    
    // Use a header for auth
    if (token) {
        [self setDefaultHeader:@"Authorization"
                         value:[@"Bearer " stringByAppendingString:token]];
    }
}

+ (NSURL*)authenticationURL
{
    // Initialisation must of occured
    assert(self.sharedClient.clientId);
    assert(self.sharedClient.callbackURL);
    assert(self.sharedClient.scopes);
    
    // Format the oauth URL
    NSString* url = [NSString stringWithFormat:@"https://alpha.app.net/oauth/authenticate"
                     "?client_id=%@"
                     "&response_type=token"
                     "&redirect_uri=%@"
                     "&scope=%@"
                     "&adnview=appstore",
                     self.sharedClient.clientId,
                     self.sharedClient.callbackURL,
                     [self.sharedClient.scopes componentsJoinedByString:@"%20"]];
    return [NSURL URLWithString:url];
}

+ (BOOL)parseURLForToken:(NSURL*)url
{
    // Check if it's our required URL
    NSString* cleanUrl = [[url absoluteString] lowercaseString];
    NSString* expectedUrl = [[self.sharedClient.callbackURL lowercaseString] stringByAppendingString:@"#access_token="];
    
    if ([cleanUrl hasPrefix:expectedUrl]) {
        NSString* token = [[url absoluteString] substringFromIndex:expectedUrl.length];
        if (token.length > 0) {
            self.sharedClient.token = token;
            return YES;
        }
    }
    
    return NO;
}

+ (void)forgetToken
{
    self.sharedClient.token = nil;
}

#pragma mark - Error Handling

+ (void)handleError:(NSError*)error
     responseObject:(id)responseObject
            failure:(AppDotNetClientFailure)failure
{
    NSNumber* errorCode = nil;
    NSString* message = nil;
    if (responseObject) {
        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableLeaves error:&jsonError];
        if (json && [json isKindOfClass:[NSDictionary class]]) {
            errorCode = [json valueForKeyPath:@"error.code"];
            message = [json valueForKeyPath:@"error.message"];
        }
    }
    failure(error, errorCode, message);
}

#pragma mark - Endpoint

+ (void)postUpdate:(NSString*)text
         withImage:(UIImage *)image
          latitude:(double)latitude
         longitude:(double)longitude
          altitude:(double)altitude
horizontalAccuracy:(double)horizontalAccuracy
  verticalAccuracy:(double)verticalAccuracy
         replyToId:(NSString*)replyToId
       annotations:(NSArray*)annotations
             links:(NSString*)links
           success:(void (^)(NSString* identifier))success
           failure:(AppDotNetClientFailure)failure
{
    // Text is required
    assert(text);
    assert(self.sharedClient.token);
    
    // Assemble the parameters
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:text, @"text", nil];
    if (replyToId) [params setObject:replyToId forKey:@"reply_to"];
    
    NSMutableArray *tAnnotations = [[[NSMutableArray alloc] init] autorelease];
    if (annotations)
        [tAnnotations addObjectsFromArray:annotations];
    
    if (latitude != 0 || longitude != 0 || altitude != 0)  {
        NSDictionary *geoAnnotation =
        @{
          @"type" : @"net.app.core.geolocation",
          @"value" : @{
                  @"latitude": @(latitude),
                  @"longitude": @(longitude),
                  @"altitude": @(altitude),
                  @"horizontal_accuracy": @(horizontalAccuracy),
                  @"vertical_accuracy": @(verticalAccuracy)
                  }
          };
        [tAnnotations addObject:geoAnnotation];
    }
    
    if (tAnnotations) [params setObject:tAnnotations forKey:@"annotations"];
    if (links) [params setObject:links forKey:@"links"];
    //     image_resp = r.post(base_url + '/files', files={'content': fp}, data={'type': 'com.mthurman.sample_code'})
    
    
    // XXX post file object here?
    if (image)  {
        NSData *foo = UIImagePNGRepresentation(image);
        NSMutableURLRequest *request = [self.sharedClient multipartFormRequestWithMethod:@"POST" path:@"stream/0/files" parameters:@{@"type" : [NSString stringWithFormat:@"%@.upload", [[NSBundle mainBundle] bundleIdentifier]], @"public" : @1   } constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
            //[formData appendPartWithFormData:foo name:[NSString stringWithFormat:@"%@.png", [self GetUUID]]];
            [formData appendPartWithFileData:foo name:@"content" fileName:[NSString stringWithFormat:@"%@.png", [self GetUUID]] mimeType:@"image/png"];
        }];
        
        //AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
        AFJSONRequestOperation *operation = [[AFJSONRequestOperation alloc] initWithRequest:request];
        DLog(@"Operation: %@", operation);
        [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            DLog(@"IMAGE UPLOAD: Sent %lld of %lld bytes", totalBytesWritten, totalBytesExpectedToWrite);
        }];
        [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            // Operation ended successfully
            DLog(@"OPERATION SUCCESSFUL: %@", responseObject);
            // now grab what we need to post
            NSString *fileToken = responseObject[@"data"][@"file_token"];
            id fileId = responseObject[@"data"][@"id"];
            DLog(@"id = %@ type = %@", fileId, NSStringFromClass([fileId class]));
            DLog(@"got file token: %@", fileToken);
            /*
             NSArray *imageAnnotation = @[
             @{@"type" : @"net.app.core.attachments",
             @"value" : @{
             @"+net.app.core.file_list": @[
             @{
             @"file_id": @"1",
             @"file_token" : fileToken,
             @"format" : @"metadata"
             }
             ]
             }
             }
             ];
             */
            
            /*
            // WORKS: using annotation
            NSArray *imageAnnotation = @[
                                         @{
                                             @"type" : @"net.app.core.oembed",
                                             @"value" : @{
                                                     @"+net.app.core.file":
                                                         @{
                                                             @"file_id": fileId,
                                                             @"file_token" : fileToken,
                                                             @"format" : @"oembed"
                                                             }
                                                     }
                                             }
                                         ];
             */
            
            NSMutableArray *tempAnnotations = [[[NSMutableArray alloc] init] autorelease];
            if (annotations)
                [tempAnnotations addObjectsFromArray:annotations];
            
            // Attachment via url
            NSDictionary *imageAnnotation =
                                         @{
                                             @"type" : @"net.app.core.oembed",
                                             @"value" : @{
                                                     @"+net.app.core.file":
                                                         @{
                                                             @"file_id": fileId,
                                                             @"file_token" : fileToken,
                                                             @"format" : @"oembed"
                                                             }
                                                     }
                                             };

            [tempAnnotations addObject:imageAnnotation];
            
            if (latitude != 0 || longitude != 0 || altitude != 0)  {
                NSDictionary *geoAnnotation =
                                             @{
                                                 @"type" : @"net.app.core.geolocation",
                                                 @"value" : @{
                                                         @"latitude": @(latitude),
                                                         @"longitude": @(longitude),
                                                         @"altitude": @(altitude),
                                                         @"horizontal_accuracy": @(horizontalAccuracy),
                                                         @"vertical_accuracy": @(verticalAccuracy)
                                                         }
                                                 };
                [tempAnnotations addObject:geoAnnotation];
            }
            
            /*
             NSArray *imageAnnotation = @[
             @{
             @"type" : @"com.DonaldBurr.TestAnnotation",
             @"value" : @{
             @"HEY" : @"HO"
             }
             },
             @{
             @"type" : [NSString stringWithFormat:@"%@.upload", [[NSBundle mainBundle] bundleIdentifier]],
             @"value" : @{
             @"+net.app.core.file": @{
             @"file_id": @"1",
             @"file_token" : fileToken,
             @"format" : @"url"
             }
             }
             }
             ];
             */
            
            /*
             // FAKE ANNOTATION FOR TESTING:
             NSArray *imageAnnotation = @[
             @{
             @"type" : @"com.DonaldBurr.TestAnnotation",
             @"value" : @{
             @"HEY" : @"HO"
             }
             }
             ];
             */

            /*
            // Geolocation annotation for testing purposes (should resolve to 1 Infinite Loop, i.e. Apple HQ)
            // test using: http://dabr.eu/adn/
            NSArray *imageAnnotation = @[
                                         @{
                                             @"type" : @"net.app.core.geolocation",
                                             @"value" : @{
                                                     @"latitude": @37.331741,
                                                     @"longitude": @-122.030333,
                                                     @"altitude": @72,
                                                     @"horizontal_accuracy": @100,
                                                     @"vertical_accuracy": @100
                                                     }
                                             }
                                         ];
             */
            
            /*
             NSError *error;
             NSData *jsonData = [NSJSONSerialization dataWithJSONObject:imageAnnotation
             options:8 // NSJSONWritingPrettyPrinted  Pass 0 if you don't care about the readability of the generated string
             error:&error];
             
             if (! jsonData) {
             DLog(@"Error creating json representation: %@", error);
             } else {
             NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
             DLog(@"Successfully created json string: %@", jsonString);
             [params setObject:jsonString forKey:@"annotations"];
             }
             */
            [params setObject:tempAnnotations forKey:@"annotations"];
            DLog(@"ABOUT TO POST IMAGE WITH PARAMS: %@", params);
            // Post away
            [self.sharedClient jsonPostPath:@"stream/0/posts?include_post_annotations=1"
                                 parameters:params
                                    success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                        DLog(@"IMAGE POST SUCCEEDED, response object = %@", responseObject);
                                        if ([responseObject isKindOfClass:[NSData class]])  {
                                            NSString *rep = [[[NSString alloc] initWithData:responseObject
                                                                                   encoding:NSUTF8StringEncoding] autorelease];
                                            DLog(@"as string = %@", rep);
                                        }
                                        success([responseObject objectForKey:@"id"]);
                                    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                        [self handleError:failure
                                           responseObject:operation.responseData
                                                  failure:failure];
                                    }];
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            // Something happened!
            DLog(@"ERROR: %@, %@", operation, error);
            [self handleError:failure
               responseObject:operation.responseData
                      failure:failure];
        }];
        [operation start];
    } else {
        // Post away
        [self.sharedClient postPath:@"stream/0/posts?include_post_annotations=1"
                         parameters:params
                            success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                success([responseObject objectForKey:@"id"]);
                            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                [self handleError:failure
                                   responseObject:operation.responseData
                                          failure:failure];
                            }];
    }
}

- (void)jsonPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
             success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
             failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    NSURLRequest *request = [self requestWithMethod:@"POST" path:path parameters:parameters];
    AFJSONRequestOperation *operation = [[AFJSONRequestOperation alloc] initWithRequest:request];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        // Operation ended successfully
        DLog(@"OPERATION SUCCESSFUL: %@", responseObject);
        success(operation, responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        // Something happened!
        DLog(@"ERROR: %@, %@", operation, error);
        // Here you can catch operation.responseString to see the response of your server
        failure(operation, error);
    }];
    self.parameterEncoding = AFJSONParameterEncoding;
    [self enqueueHTTPRequestOperation:operation];
}

@end
