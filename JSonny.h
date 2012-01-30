#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "SBJson.h"

@interface JSonny : UITableViewController {
	NSURL *_json_url;
	NSMutableDictionary *_cellImageCache;
	UIImage *_transparent_placeholder;
	NSDictionary *_json_parsed;
	NSArray *_sections; /* shortcut */
	NSLock *_giant;
	BOOL _reloading;
}
@property (retain) UIImage *_transparent_placeholder;
@property (retain) NSMutableDictionary *_cellImageCache;
@property (retain) NSURL *_json_url;
@property (retain) NSDictionary *_json_parsed;
@property (retain) NSLock *_giant;
- (id) initWithString:(NSString *) string;
- (void) loadImageObject:(id)obj into:(UITableViewCell *)cell;
@end
