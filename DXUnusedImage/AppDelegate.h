//
//  AppDelegate.h
//  DXUnsedImage
//
//  Created by jin on 16/8/5.
//  Copyright © 2016年 Delson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTabViewDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (assign) IBOutlet NSTableView *resultsTableView;

@property (assign) IBOutlet NSProgressIndicator *processIndicator;

@property (assign) IBOutlet NSTextField *statusLabel;

@property (assign) IBOutlet NSButton *browseButton;

@property (assign) IBOutlet NSTextField *pathTextField;

@property (assign) IBOutlet NSButton *searchButton;

@property (assign) IBOutlet NSButton *exportButton;

- (IBAction)browseButtonSelected:(id)sender;

- (IBAction)startSearch:(id)sender;

- (IBAction)exportButtonSelected:(id)sender;

@end

