//
//  CDMMainWindow.m
//  Cheddar for Mac
//
//  Created by Sam Soffes on 8/5/12.
//  Copyright (c) 2012 Nothing Magical. All rights reserved.
//

#import "CDMMainWindow.h"
#import "CDMTrafficLightsView.h"

static NSString* const kCDMUserDefaultsKeyWindowAlwaysOnTop = @"windowAlwaysOnTop";

@interface INAppStoreWindow (INAppStoreWindowInternal)
- (void)_layoutTrafficLightsAndContent;
- (void)_doInitialWindowSetup;
@end

// Copied from INAppStoreWindow
static inline CGImageRef _createNoiseImageRef(NSUInteger width, NSUInteger height, CGFloat factor) {
    NSUInteger size = width * height;
    char *rgba = (char *)malloc(size);
	srand(124);
    for (NSUInteger i=0; i < size; ++i) {
		rgba[i] = rand() % 256 * factor;
	}
	
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapContext = CGBitmapContextCreate(rgba, width, height, 8, width, colorSpace, kCGImageAlphaNone);
    CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
    CFRelease(bitmapContext);
    CGColorSpaceRelease(colorSpace);
    free(rgba);
    return image;
}


@implementation CDMMainWindow {
    CDMTrafficLightsView *_trafficLightsContainer;
}


#pragma mark - NSObject

- (void)awakeFromNib {
	[super awakeFromNib];
	NSColorList *colorList = [[NSColorList alloc] initWithName:NSStringFromClass([self class])];

	[colorList setColor:[NSColor colorWithCalibratedRed:0.914 green:0.545 blue:0.448 alpha:1.000] forKey:@"topInset"];
	[colorList setColor:[NSColor colorWithCalibratedRed:0.961 green:0.457 blue:0.324 alpha:1.000] forKey:@"gradientTop"];
	[colorList setColor:[NSColor colorWithCalibratedRed:0.988 green:0.347 blue:0.192 alpha:1.000] forKey:@"gradientBottom"];
	[colorList setColor:[NSColor colorWithCalibratedRed:0.990 green:0.448 blue:0.306 alpha:1.000] forKey:@"bottomInset"];
	[colorList setColor:[NSColor colorWithCalibratedWhite:0.333 alpha:1.000] forKey:@"bottomBorder"];

	[colorList setColor:[NSColor whiteColor] forKey:@"topInsetUnemphasized"];
	[colorList setColor:[NSColor colorWithCalibratedWhite:0.970 alpha:1.000] forKey:@"gradientTopUnemphasized"];
	[colorList setColor:[NSColor colorWithCalibratedWhite:0.845 alpha:1.000] forKey:@"gradientBottomUnemphasized"];
	[colorList setColor:[NSColor colorWithCalibratedWhite:0.878 alpha:1.000] forKey:@"bottomInsetUnemphasized"];
	[colorList setColor:[NSColor colorWithCalibratedWhite:0.590 alpha:1.000] forKey:@"bottomBorderUnemphasized"];
	
	self.titleBarHeight = 36.0f;
	self.centerFullScreenButton = YES;
	self.fullScreenButtonRightMargin = 10.0f;
    __block __unsafe_unretained NSWindow *blockSelf = self;
	[self setTitleBarDrawingBlock:^(BOOL drawsAsMainWindow, CGRect drawingRect, CGPathRef clippingPath){
		CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
        if (([blockSelf styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask) {
            CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            CGContextFillRect(context, drawingRect);
        }
		CGContextSaveGState(context);
		CGContextAddPath(context, clippingPath);
		CGContextClip(context);
		
		NSColor *topInset = nil;
		NSColor *bottomInset = nil;
		NSColor *bottomBorder = nil;
		NSColor *gradientTop = nil;
		NSColor *gradientBottom = nil;
		
		if (drawsAsMainWindow) {
			topInset = [colorList colorWithKey:@"topInset"];
			bottomInset = [colorList colorWithKey:@"bottomInset"];
			bottomBorder = [colorList colorWithKey:@"bottomBorder"];
			gradientTop = [colorList colorWithKey:@"gradientTop"];
			gradientBottom = [colorList colorWithKey:@"gradientBottom"];
		} else {
			topInset = [colorList colorWithKey:@"topInsetUnemphasized"];
			bottomInset = [colorList colorWithKey:@"bottomInsetUnemphasized"];
			bottomBorder = [colorList colorWithKey:@"bottomBorderUnemphasized"];
			gradientTop = [colorList colorWithKey:@"gradientTopUnemphasized"];
			gradientBottom = [colorList colorWithKey:@"gradientBottomUnemphasized"];
		}
		
		// Top inset
		[topInset setFill];
		CGRect rect = drawingRect;
		rect.origin.y = rect.size.height - 1.0f;
		rect.size.height = 1.0f;
		CGContextFillRect(context, rect);
		
		// Bottom inset
		[bottomInset setFill];
		rect.origin.y = 1.0f;
		CGContextFillRect(context, rect);
		
		// Bottom border
		[bottomBorder setFill];
		rect.origin.y = 0.0f;
		CGContextFillRect(context, rect);
		
		// Gradient
		rect = drawingRect;
		rect.origin.y += 2.0f;
		rect.size.height -= 3.0f;
		NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:gradientTop endingColor:gradientBottom];
		[gradient drawInRect:rect angle:-90.0f];
		
		// Noise
		static CGImageRef noisePattern = nil;
		if (noisePattern == nil) {
			noisePattern = _createNoiseImageRef(128, 128, 0.015);
		}
			  
		CGContextSetBlendMode(context, kCGBlendModePlusLighter);
		CGRect noisePatternRect = CGRectZero;
		noisePatternRect.size = CGSizeMake(CGImageGetWidth(noisePattern), CGImageGetHeight(noisePattern));
		CGContextDrawTiledImage(context, noisePatternRect, noisePattern);

		// Title
		NSImage *image = [NSImage imageNamed:@"title"];
		CGSize imageSize = image.size;
		rect = CGRectMake(roundf((drawingRect.size.width - imageSize.width) / 2.0f), roundf((drawingRect.size.height - imageSize.height) / 2.0f), imageSize.width, imageSize.height);
		[image drawInRect:rect fromRect:CGRectZero operation:NSCompositeSourceOver fraction:1.0f];

		CGContextRestoreGState(context);
	}];
}


#pragma mark - NSWindow

- (void)toggleFullScreen:(id)sender {
	BOOL isFullScreen = (self.styleMask & NSFullScreenWindowMask) != NSFullScreenWindowMask;
	_trafficLightsContainer.alphaValue = isFullScreen ? 0.0f : 1.0f;
	
	[super toggleFullScreen:sender];
}


#pragma mark - Private

- (void)_doInitialWindowSetup {
    [super _doInitialWindowSetup];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kCDMUserDefaultsKeyWindowAlwaysOnTop]) {
        [self setLevel:NSFloatingWindowLevel];
	}
    [self _createAndPositionTrafficLights];
}


- (void)_layoutTrafficLightsAndContent {
    [super _layoutTrafficLightsAndContent];
    NSButton *close = [self standardWindowButton:NSWindowCloseButton];
    NSButton *minimize = [self standardWindowButton:NSWindowMiniaturizeButton];
    NSButton *zoom = [self standardWindowButton:NSWindowZoomButton];
    [close setHidden:YES];
    [minimize setHidden:YES];
    [zoom setHidden:YES];
}


- (void)_createAndPositionTrafficLights {
    NSSize imageSize = [[NSImage imageNamed:@"traffic-normal"] size];
    NSRect trafficLightContainerRect = NSMakeRect(kCDMWindowTrafficLightsSpacing,  floor(NSMidY([self.titleBarView bounds]) - (imageSize.height / 2.f)), (imageSize.width * 3.f) + (kCDMWindowTrafficLightsSpacing * 2.f), imageSize.height);
    _trafficLightsContainer = [[CDMTrafficLightsView alloc] initWithFrame:trafficLightContainerRect];
    [_trafficLightsContainer setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin | NSViewMinYMargin];
    [self.titleBarView addSubview:_trafficLightsContainer];
}

@end
