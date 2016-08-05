//
//  AppDelegate.m
//  DXUnsedImage
//
//  Created by jin on 16/8/5.
//  Copyright © 2016年 Delson. All rights reserved.
//

#import "AppDelegate.h"
#import "Searcher.h"

@interface AppDelegate () <SearcherDelegate>

@property (nonatomic, strong) NSMutableArray *results;
@property (nonatomic, strong) Searcher *searcher;

@end

static NSString *const kTableColumnImageIcon = @"ImageIcon";
static NSString *const kTableColumnImageShortName = @"ImageShortName";

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _results = [[NSMutableArray alloc] init];
    
    [_resultsTableView setDoubleAction:@selector(tableViewDoubleClicked)];
    
    [_statusLabel setTextColor:[NSColor lightGrayColor]];
    
    [_searchButton setBezelStyle:NSRoundedBezelStyle];
    [_searchButton setKeyEquivalent:@"\r"];
    
    _searcher = [[Searcher alloc] init];
    _searcher.delegate = self;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (IBAction)browseButtonSelected:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    
    BOOL okButtonPressed = ([openPanel runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        NSString *path = [[openPanel URL] path];
        [self.pathTextField setStringValue:path];
    }
}

- (IBAction)startSearch:(id)sender {
    NSString *projectPath = [self.pathTextField stringValue];
    BOOL isPathEmpty = [projectPath isEqualToString:@""];
    if (isPathEmpty) {
        [self showAlertWithStyle:NSWarningAlertStyle title:@"No .xcodeproj File Selected" subtitle:@"Please select a valid .xcodeproj file"];
        return;
    }
    
    BOOL pathExists = [[NSFileManager defaultManager] fileExistsAtPath:projectPath];
    if (![projectPath hasSuffix:@".xcodeproj"] || !pathExists) {
        [self showAlertWithStyle:NSWarningAlertStyle title:@"Invalid .xcodeproj File" subtitle:@"Please select a valid .xcodeproj file"];
        
        return;
    }
    
    [self.results removeAllObjects];
    [self.resultsTableView reloadData];
    
    self.searcher.projectPath = projectPath;
    [self setUIEnabled:NO];
    [self.searcher start];
}

- (IBAction)exportButtonSelected:(id)sender {
    NSSavePanel *save = [NSSavePanel savePanel];
    [save setAllowedFileTypes:[NSArray arrayWithObject:@"txt"]];
    
    BOOL okButtonPressed = ([save runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        NSString *selectedFile = [[save URL] path];
        
        NSMutableString *outputResults = [[NSMutableString alloc] init];
        NSString *projectPath = [self.pathTextField stringValue];
        [outputResults appendFormat:@"Unused Files in project %@\n\n", projectPath];
        
        for (NSString *path in _results) {
            [outputResults appendFormat:@"%@\n",path];
        }
        
        NSError *writeError = nil;
        [outputResults writeToFile:selectedFile atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        
        if (writeError == nil) {
            [self showAlertWithStyle:NSInformationalAlertStyle title:@"Export Complete" subtitle:@"The results have been exported successfully"];
        } else {
            NSLog(@"Unused write error:: %@", writeError);
            [self showAlertWithStyle:NSCriticalAlertStyle title:@"Export Error" subtitle:@"There was an error exporting the results"];
        }
    }
}

- (void)tableViewDoubleClicked {
    NSString *path = [self.results objectAtIndex:[self.resultsTableView clickedRow]];
    [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
}

- (void)setUIEnabled:(BOOL)state {
    if (state) {
        [_searchButton setTitle:@"Search"];
        [_searchButton setKeyEquivalent:@"\r"];
        [_processIndicator stopAnimation:self];
    }
    else {
        [_searchButton setKeyEquivalent:@""];
        [_processIndicator startAnimation:self];
        [_statusLabel setStringValue:@"Searching"];
    }
    
    [_searchButton setEnabled:state];
    [_processIndicator setHidden:state];
    [_browseButton setEnabled:state];
    [_pathTextField setEnabled:state];
    [_exportButton setHidden:!state];
}

- (void)showAlertWithStyle:(NSAlertStyle)style title:(NSString *)title subtitle:(NSString *)subtitle {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = style;
    [alert setMessageText:title];
    [alert setInformativeText:subtitle];
    [alert runModal];
}

- (void)scrollTableView:(NSTableView *)tableView toBottom:(BOOL)bottom {
    if (bottom) {
        NSInteger numberOfRows = [tableView numberOfRows];
        if (numberOfRows > 0) {
            [tableView scrollRowToVisible:numberOfRows - 1];
        }
    } else {
        [tableView scrollRowToVisible:0];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.results count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    NSString *pngPath = [self.results objectAtIndex:rowIndex];
    NSString *columnIdentifier = [tableColumn identifier];
    if ([columnIdentifier isEqualToString:kTableColumnImageIcon]) {
        return [[NSImage alloc] initByReferencingFile:pngPath];
    } else if ([columnIdentifier isEqualToString:kTableColumnImageShortName]) {
        return [pngPath lastPathComponent];
    }
    
    return pngPath;
}

- (void)searcher:(Searcher *)searcher didFindUnusedImage:(NSString *)imagePath {
    [self.results addObject:imagePath];
    [self.resultsTableView reloadData];
    [self scrollTableView:self.resultsTableView toBottom:YES];
}

- (void)searcher:(Searcher *)searcher didFinishSearch:(NSArray *)results {
    [self.resultsTableView reloadData];
    int fileSize = 0;
    for (NSString *path in _results) {
        fileSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
    }
    [self.statusLabel setStringValue:[NSString stringWithFormat:@"Completed - Found %ld - Size %@", (unsigned long)[_results count], [self stringFromFileSize:fileSize]]];
    [self setUIEnabled:YES];
}

- (NSString *)stringFromFileSize:(int)fileSize {
    if (fileSize < 1023) {
        return([NSString stringWithFormat:@"%i bytes", fileSize]);
    }
    
    float floatSize = fileSize / 1024;
    if (floatSize < 1023) {
        return([NSString stringWithFormat:@"%1.1f KB", floatSize]);
    }
    
    floatSize = floatSize / 1024;
    if (floatSize < 1023) {
        return([NSString stringWithFormat:@"%1.1f MB", floatSize]);
    }
    
    floatSize = floatSize / 1024;
    return([NSString stringWithFormat:@"%1.1f GB",floatSize]);
}

@end
