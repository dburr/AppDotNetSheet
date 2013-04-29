//
//  ThoughtSender.m
//  ThoughtBackDesktop
//
//  Created by Randall Brown on 11/6/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ImgurUploader.h"
#import "NSString+URLEncoding.h"
#import "NSData+Base64.h"
#import <dispatch/dispatch.h>
#import <JSON.h>

@implementation ImgurUploader

@synthesize delegate;

-(void)uploadImage:(UIImage*)image
{
	dispatch_queue_t queue = dispatch_queue_create("com.Blocks.task",NULL);
	dispatch_queue_t main = dispatch_get_main_queue();
	
	dispatch_async(queue,^{
		NSData   *imageData  = UIImageJPEGRepresentation(image, 0.3); // High compression due to 3G.
		
		NSString *imageB64   = [imageData base64EncodingWithLineLength:0];
		imageB64 = [imageB64 encodedURLString];
		
		dispatch_async(main,^{
			
			NSString *uploadCall = [NSString stringWithFormat:@"image=%@&type=base64",imageB64];
			
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.imgur.com/3/upload"]];
			[request setHTTPMethod:@"POST"];
            [request setValue:@"Client-ID 79c11f414559fdb" forHTTPHeaderField:@"Authorization"];
			[request setValue:[NSString stringWithFormat:@"%d",[uploadCall length]] forHTTPHeaderField:@"Content-length"];
			[request setHTTPBody:[uploadCall dataUsingEncoding:NSUTF8StringEncoding]];
			
			NSURLConnection *theConnection=[[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
			if (theConnection) 
			{
				// Create the NSMutableData that will hold
				// the received data
				// receivedData is declared as a method instance elsewhere
				//receivedData=[[NSMutableData data] retain];
				receivedData=[[NSMutableData data] retain];
			} 
			else 
			{
				
			}
			
		});
	});  		
}


-(void)dealloc
{
	[super dealloc];
	[imageURL release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[delegate uploadFailedWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[receivedData appendData:data];
    DLog(@"got data %@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
	[delegate uploadProgressedToPercentage:(CGFloat)totalBytesWritten/(CGFloat)totalBytesExpectedToWrite];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	//	NSString *dataString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
	//	DLog( @"%@", dataString );
	
    // {"data":{"id":"MpSoxfv","deletehash":"2Zx3RqQ5oELdYSh","link":"http:\/\/i.imgur.com\/MpSoxfv.jpg"},"success":true,"status":200}

    NSString *jsonData = [[NSString alloc] initWithData:receivedData encoding:NSASCIIStringEncoding];
    SBJSON *jParser = [[SBJSON alloc] init];
    NSDictionary *ret = [jParser objectWithString:jsonData];
    NSString *url = ret[@"data"][@"link"];
    DLog(@"uploaded, url=%@", url);
	[delegate imageUploadedWithURLString:url];
}

-(void)parserDidEndDocument:(NSXMLParser*)parser
{
	//DLog(@"Parse Finished");
	//	DLog(@"%@", thought);
	[delegate imageUploadedWithURLString:imageURL];
}


-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	currentNode = elementName;
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if( [currentNode isEqualToString:elementName] )
	{
		currentNode = @"";
	}
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if( [currentNode isEqualToString:@"original"] )
	{
		imageURL = [string retain];
	}
}

@end
