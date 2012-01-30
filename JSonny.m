#import "JSonny.h"
@implementation JSonny
static NSString *editingStyleDelete = @"editingStyleDelete";
static NSString *didSelectRow = @"didSelectRow";
static NSString *defaultInitString = @"http://127.0.0.1:4567/"; // when init argument is nil */
static CGFloat minRowHeight = 44;
@synthesize _json_url,_json_parsed,_cellImageCache,_transparent_placeholder,_giant;
/*
	there should be more documentation at http://github.com/jackdoe/
	
	NOTICE: 
	1. there is no support for pure int values, all of them must be converted to string
		example: borderWidth => 7 must be borderWidth => '7', 
	2. if the initString contains UITableViewStyleGrouped, then the table style is grouped, otherwise its plain
	3. if no color is given, when color is expected -  [UIColor clearColor] is used
	
root object:
	title => 'table's title'
	minRowHeight => 'minimal row height'
	sections => [array with each section's rows]


row example:
	initWithStyle => ('UITableViewCellStyleValue1','UITableViewCellStyleValue2','UITableViewCellStyleSubtitle', none=UITableViewCellStyleDefault)
	backgroundColor => color-dictionary or color pattern image string
	image => 		
		{ 	
			'url' => 'https://www.google.com/intl/en_com/images/srpr/logo3w.png', 
			'layer' => { 	
						'maskToBounds' => 'YES',
						'cornerRadius' => '6.5',
						'borderWidth' => '7',
						'borderColor' => color-dictionary or color pattern image string
						}
	    } - or simple url string ( image => 'https://www.google.com/intl/en_com/images/srpr/logo3w.png' )
	textLabel|detailTextLabel =>		 
			{ 
				'text' => "label's text", 
				'font' => { 
							'name' => 'Trebuchet MS', 
							'size' => '30'
						  },
				'textColor' => color-dictionary or color pattern image string
			} - or textLabel.text string ( textLabel => 'just print this!' )
			
	heightForRow => '60' # height for current row
	editingStyleDelete => 'http://127.0.0.1:4567/delete/5' - url will be visited when user clicks the delete button
	didSelectRow => #when user clicks on the row
			{
				'name' => 'JSonny', # for security if class's name is not the same as the current clas, it must have prefix RemoteJsonRequestClass_
				'init' => { 
							'method' => 'initWithString:',
							'argument' => @request.url
						  }
			 }

color-dictionary example:
	if the object is dictionary:
	{
		'red' => '255','green' => '255', 'blue' => '255', 'alpha' => '0.90'
	}

*/
#pragma mark - dictionary helpers
- (id) objectForKey:(NSString *) key expect:(Class) must_be inDictionary:(NSDictionary *) row {
	if (key && row) {
		id ret = [row objectForKey:key];
		if ([ret isKindOfClass:must_be])
			return ret;
	}
	return nil;
}
- (NSArray *) sections {
	return [self objectForKey:@"sections" expect:[NSArray class] inDictionary:_json_parsed];
}
- (NSDictionary *) rowAtIndexPath:(NSIndexPath *) path {
	NSArray *section, *sections = [self sections];
	id row;
	if (sections && path.section < [sections count] &&
		(section = [sections objectAtIndex:path.section]) &&
		[section isKindOfClass:[NSArray class]] && 
		path.row < [section count] &&
		(row = [section objectAtIndex:path.row])) {
			if ([row isKindOfClass:[NSDictionary class]]) 
				return row;
	}
	return nil;
}

/* 
 * if object is a string, find a pattern in imageNamed, othwesise create color using rgba 
 * XXX: performance: must cache the color, no need to create new one if they are all the same.
 * example:
	'color' => {:red => '255',:green => '255', :blue => '255', :alpha => '1'}				
	'background-color' => 'item_background.png'
 * if no color is specified, it returns clearColor
 */

- (UIColor *) colorWithObject:(id) obj {
	if ([obj isKindOfClass:[NSString class]]) {		
		return [UIColor colorWithPatternImage:[UIImage imageNamed:obj]];
	} else if ([obj isKindOfClass:[NSDictionary class]]) {
		CGFloat red = [[self objectForKey:@"red" expect:[NSString class] inDictionary:obj] floatValue]/255.0;
		CGFloat green = [[self objectForKey:@"green" expect:[NSString class] inDictionary:obj] floatValue]/255.0;
		CGFloat blue = [[self objectForKey:@"blue" expect:[NSString class] inDictionary:obj] floatValue]/255.0;
		CGFloat alpha = [[self objectForKey:@"alpha" expect:[NSString class] inDictionary:obj] floatValue];
		return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
	} 
	return [UIColor clearColor];
}

#pragma mark -

- (void) _mainThreadPostReload {
	if (_json_parsed) {
		self.title = [self objectForKey:@"title" expect:[NSString class] inDictionary:_json_parsed];
		NSString *minRowHeightString =  [self objectForKey:@"minRowHeight" expect:[NSString class] inDictionary:_json_parsed];
		minRowHeight = (minRowHeightString ? [minRowHeightString floatValue] : minRowHeight);
		_sections = [self sections];
		[self.tableView	reloadData];
	} else {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"failed to load table's data" message:@"please try again later {or keep spamming the reload button :)}" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];	
	}
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;	
}

- (void) async_reload {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		SBJsonParser *p = [[SBJsonParser alloc] init];
		NSError *err;
		id obj = [p objectWithData:[NSData dataWithContentsOfURL:_json_url options:NSDataReadingMappedAlways error:&err]];
		if ([obj isKindOfClass:[NSDictionary class]]){
			self._json_parsed = [NSDictionary dictionaryWithDictionary:obj];
		} else {
			NSLog(@"%@",err);
		}
		[self performSelectorOnMainThread:@selector(_mainThreadPostReload) withObject:nil waitUntilDone:YES];
	});
}
- (id) initWithString:(NSString *) string {
	if (!string) 
		string = defaultInitString;
	/* XXX:
	 * we cant modify the table style afterwards
	 * and we have to do a trade here, async load or static table style
	 * or maybe we can do something like
	 * style = [[NSString stringWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@?give_me_table_style_only=1",string] encoding:NSUTF8StringEncoding error:nil]] integerValue];
	 * still undecided which path to take.
	 * ------------------------------
	 * currently if the string contains UITableViewStyleGrouped somewhere the table style is grouped, otherwise its plain
	 */
	self = [super initWithStyle:([string rangeOfString:@"UITableViewStyleGrouped"].location == NSNotFound) ? UITableViewStylePlain : UITableViewStyleGrouped]; 
	if (self) {
		self._giant = [[NSLock alloc] init];
		self._cellImageCache = [NSMutableDictionary dictionary];
		self._json_url = [NSURL URLWithString:string];
		self._transparent_placeholder = [UIImage imageNamed:@"trans"];
		self._json_parsed = nil;
		[self async_reload];
	}
	return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [_cellImageCache removeAllObjects];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(async_reload)];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [[self sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [[[self sections] objectAtIndex:section] count];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	CGFloat ret = [[self objectForKey:@"heightForRow" expect:[NSString class] inDictionary:row] floatValue];
//	CGSize s = [@"a" sizeWithFont:[UIFont fontWithName: size:FONT_SIZE] constrainedToSize:CGSizeMake([tableView frame].size.width-40,1500)];
	return MAX(ret,minRowHeight);
}

/* 
 * if object is string, use it as the label's.text
 * otherwise find font, font size, font color, text in a dictionary
	 example:
 	'textLabel' => 	{ 	
				'text' => 'label text', 
				'font' => {'name' => 'Trebuchet MS'},
				'text-color'=> {:red => '255',:green => '255', :blue => '255', :alpha => '1'}
				}
 	'detailTextLabel' => 'its that simple :)'
 */
- (void) updateTextAndFontInLabel:(UILabel *) label with:(id) obj {
	if (!obj) 
		return;
	
	if ([obj isKindOfClass:[NSString class]]) {
		label.text = obj;
		return;
	}
	if ([obj isKindOfClass:[NSDictionary class]]) {
		label.text = [self objectForKey:@"text" expect:[NSString class] inDictionary:obj];
		NSDictionary *font = [self objectForKey:@"font" expect:[NSDictionary class] inDictionary:obj];
		if (font) {
			NSString *fontName =  [self objectForKey:@"name" expect:[NSString class] inDictionary:font];
			CGFloat fontSize = [[self objectForKey:@"size" expect:[NSString class] inDictionary:font] floatValue];
			fontSize = (fontSize ? fontSize : [UIFont systemFontSize]);
			fontName = (fontName ? fontName : [UIFont systemFontOfSize:[UIFont systemFontSize]].fontName);
			label.font = [UIFont fontWithName:fontName size:fontSize];
		}
		NSDictionary *color = [self objectForKey:@"textColor" expect:[NSObject class] inDictionary:obj];
		if (color) 
			label.textColor = [self colorWithObject:color];
		
		return;
	}
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	NSDictionary *background = [self objectForKey:@"backgroundColor" expect:[NSObject class] inDictionary:row];
	if (background)
		cell.backgroundColor = [self colorWithObject:background];
	NSDictionary *html = [self objectForKey:@"html" expect:[NSDictionary class] inDictionary:row];
	if (html) {
		UIWebView *web = [[UIWebView alloc] initWithFrame:cell.frame];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSURL *baseURL = [NSURL URLWithString:[self objectForKey:@"baseURL" expect:[NSString class] inDictionary:html]];
			NSString *HTMLString = [self objectForKey:@"string" expect:[NSString class]  inDictionary:html];
			[web loadHTMLString:HTMLString baseURL:baseURL];
			[cell performSelectorOnMainThread:@selector(setNeedsLayout) withObject:cell waitUntilDone:YES];
		});
		[cell.contentView addSubview:web];
	}
	id textLabel = [self objectForKey:@"textLabel" expect:[NSObject class] inDictionary:row];
	id detailTextLabel = [self objectForKey:@"detailTextLabel" expect:[NSObject class] inDictionary:row];
	[self updateTextAndFontInLabel:cell.textLabel with:textLabel];
	[self updateTextAndFontInLabel:cell.detailTextLabel with:detailTextLabel];
	[self loadImageObject:[self objectForKey:@"image" expect:[NSObject class] inDictionary:row] into:cell];	
	cell.selectionStyle = ([self objectForKey:didSelectRow expect:[NSDictionary class] inDictionary:row] ? UITableViewCellSelectionStyleGray : UITableViewCellSelectionStyleNone);
}
/* 
	example:
		'initWithStyle' => 'UITableViewCellStyleValue1',
	here we only define cell's style, and nothing more
	the other stuff is updated into the cell after its height is detemined
*/
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"Cell";

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	if (cell == nil) {
		NSString *style = cell.textLabel.text = [self objectForKey:@"initWithStyle" expect:[NSString class] inDictionary:row];
		UITableViewCellStyle e = UITableViewCellStyleDefault;
		if (style) {
			if ([style isEqualToString:@"UITableViewCellStyleValue1"])
				e = UITableViewCellStyleValue1;
			else if ([style isEqualToString:@"UITableViewCellStyleValue2"])
				e = UITableViewCellStyleValue2;
			else if ([style isEqualToString:@"UITableViewCellStyleSubtitle"])
				e = UITableViewCellStyleSubtitle;
			else
				e = UITableViewCellStyleDefault;
		}
		cell = [[UITableViewCell alloc] initWithStyle:e reuseIdentifier:CellIdentifier];
	}
	return cell;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return ([self objectForKey:editingStyleDelete expect:[NSString class] inDictionary:[self rowAtIndexPath:indexPath]] ? YES : NO);
}
/* 
	example:
			'editingStyleDelete' => 'http://127.0.0.1:9393/delete/5',
	this will be the url(http://127.0.0.1:9393/delete/5) visited after user clicks delete
*/
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSString *action = [self objectForKey:editingStyleDelete expect:[NSString class] inDictionary:[self rowAtIndexPath:indexPath]];
		if (action) {
			[NSData dataWithContentsOfURL:[NSURL URLWithString:action]];
			[self async_reload];
		}
	}   
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {	
	NSDictionary *d = [self objectForKey:didSelectRow expect:[NSDictionary class] inDictionary:[self rowAtIndexPath:indexPath]];
	if (d) {
		NSDictionary *initDictionary = [self objectForKey:@"init" expect:[NSDictionary class] inDictionary:d];
		NSString *c = [self objectForKey:@"name" expect:[NSString class] inDictionary:d];
		NSString *initMethod  = [self objectForKey:@"method" expect:[NSString class] inDictionary:initDictionary];		
		if (c && initDictionary && initMethod) {
			if (![c isEqualToString:NSStringFromClass([self class])]) {
				c = [NSString stringWithFormat:@"RemoteJsonRequestClass_%@",c]; // security thingie
			}
			id obj = [NSClassFromString(c) alloc];
			if (initMethod && [obj respondsToSelector:NSSelectorFromString(initMethod)]) {
				id initArgument = [self objectForKey:@"argument" expect:[NSObject class] inDictionary:initDictionary]; /* can be anything */			
				if (initArgument) {
					obj = [obj performSelector:NSSelectorFromString(initMethod) withObject:initArgument];
				} else {
					obj = [obj performSelector:NSSelectorFromString(initMethod)];
				}
			}
//			NSLog(@"called %@ %@ %@",obj,c,initMethod);
			if ([obj isKindOfClass:[UIViewController class]]) {
				[self.navigationController pushViewController:obj animated:YES];
			}
		}
	}
}


#pragma mark -
#pragma mark - Image Loading and Cache
- (NSData *) cachedImage:(NSString *) image onComplete:(void (^) (void)) done {
	NSData *d = [_cellImageCache objectForKey:image];
	if (d) 
		return d;

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSData *d = [NSData dataWithContentsOfURL:[NSURL URLWithString:image] options:NSDataReadingMappedAlways error:nil];
		[_cellImageCache setValue:d forKey:image];
		done();
	});
	return nil;
}

- (void) loadRemoteImage:(NSString *)image into:(UITableViewCell *)cell {
	UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	[cell.imageView addSubview:activity];
	[activity startAnimating];		
	cell.imageView.image = _transparent_placeholder;
#define setImage(_data)	do {											\
				[activity removeFromSuperview];							\
				cell.imageView.image = [UIImage imageWithData:_data];	\
			} while(0);
			
	
	NSData *d = [self cachedImage:image onComplete:^{
			setImage([_cellImageCache objectForKey:image])
			[cell.imageView performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:YES];
			[cell performSelectorOnMainThread:@selector(setNeedsLayout) withObject:nil waitUntilDone:YES];					
	}];
	if (d)
		setImage(d);
#undef setImage
}
/* 
	example:
		'image' => 'http://chachatelier.fr/programmation/images/mozodojo-mosaic-image.jpg'
		'image' => { 'imageNamed' => "cool_image.jpg" }
		'image' => { 
					'url' => 'http://chachatelier.fr/programmation/images/mozodojo-mosaic-image.jpg', 
					'layer' =>  
						{ 
							'maskToBounds' => 'YES',
							'cornerRadius' => '6.0',
							'borderWidth' => '7.0',
							'borderColor' => {:red => '255',:green => '255', :blue => '255', :alpha => '1'},
					    }
			        },
*/
- (void) loadImageObject:(id)obj into:(UITableViewCell *)cell {
	if (!obj || !cell)
		return;
		
	NSString *key;	
	if ([obj isKindOfClass:[NSString class]]) {
		[self loadRemoteImage:obj into:cell];
	} else if ([obj isKindOfClass:[NSDictionary class]]) {
		Class s = [NSString class];
		key = [self objectForKey:@"imageNamed" expect:s inDictionary:obj];
		if (key) {
			cell.imageView.image = [UIImage imageNamed:key];
		} else {
			[self loadRemoteImage:[self objectForKey:@"url" expect:s inDictionary:obj] into:cell];
		}
		NSDictionary *layer = [self objectForKey:@"layer" expect:[NSDictionary class] inDictionary:obj];
		if (layer) {
			CALayer *l = cell.imageView.layer;
			key = [self objectForKey:@"masksToBounds" expect:s inDictionary:layer];
			if (key)
				l.masksToBounds = [key boolValue];
			key = [self objectForKey:@"cornerRadius" expect:s inDictionary:layer];
			if (key)
				l.cornerRadius = [key floatValue];
			key = [self objectForKey:@"borderWidth" expect:s inDictionary:layer];
			if (key)
				l.borderWidth = [key floatValue];
			l.borderColor = [[self colorWithObject:[self objectForKey:@"borderColor" expect:[NSObject class] inDictionary:layer]] CGColor];
			l.backgroundColor = [[self colorWithObject:[self objectForKey:@"backgroundColor" expect:[NSObject class] inDictionary:layer]] CGColor];
			/* XXX: more! */
		}	
	}
}

@end
