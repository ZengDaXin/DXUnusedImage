//
//  Searcher.h
//  DXUnsedImage
//
//  Created by jin on 16/8/5.
//  Copyright © 2016年 Delson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Searcher;

@protocol SearcherDelegate <NSObject>

@optional

- (void)searcherDidStartSearch:(Searcher *)searcher;

- (void)searcher:(Searcher *)searcher didFindUnusedImage:(NSString *)imagePath;

- (void)searcher:(Searcher *)searcher didFinishSearch:(NSArray *)results;

@end

@interface Searcher : NSObject

@property (assign) id <SearcherDelegate> delegate;

@property (copy) NSString *projectPath;

- (void)start;

@end
