//
//  Searcher.m
//  DXUnsedImage
//
//  Created by jin on 16/8/5.
//  Copyright © 2016年 Delson. All rights reserved.
//

#import "Searcher.h"

@interface Searcher () {
    @private
    NSOperationQueue *_queue;
    
    NSDictionary *_objects;
    NSString *_projectDirPath;
}

@property (nonatomic, strong) NSMutableDictionary *unusedImageNames;
@property (nonatomic, strong) NSMutableDictionary *imageNames;
@property (nonatomic, strong) NSMutableArray *fileNames;

@end

@implementation Searcher

- (instancetype)init {
    if (self = [super init]) {
        _queue = [[NSOperationQueue alloc] init];
        
        self.imageNames = [NSMutableDictionary dictionary];
        self.fileNames = [NSMutableArray array];
    }
    
    return self;
}

- (void)start {
    NSInvocationOperation *searchOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(runImageSearch:) object:self.projectPath];
    [_queue addOperation:searchOperation];
}

- (void)runImageSearch:(NSString *)searchPath {
    NSString *projectPath = [searchPath stringByAppendingPathComponent:@"project.pbxproj"];
    NSDictionary *projectDic = [NSDictionary dictionaryWithContentsOfFile:projectPath];
    
    NSString *rootObject = projectDic[@"rootObject"];
    _objects = projectDic[@"objects"];
    NSDictionary *mainInfo = _objects[rootObject];
    NSArray *targets = mainInfo[@"targets"];
    [self extractBuldPhasesContent:targets];
    self.unusedImageNames = [NSMutableDictionary dictionaryWithDictionary:_imageNames];
    
    NSString *mainGroupKey = mainInfo[@"mainGroup"];
    
    NSDictionary *mainGroupDic = _objects[mainGroupKey];
    
    _projectDirPath = [searchPath stringByDeletingLastPathComponent];
    [self checkImageUsed:_projectDirPath PBXGroup:mainGroupDic key:mainGroupKey];
    
    NSArray *imageNames = [self.unusedImageNames.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj1 compare:obj2];
    }];
    
    /*
     // delete directly
    NSString *projectContent = [NSString stringWithContentsOfFile:projectPath encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *projectContentArray = [NSMutableArray arrayWithArray:[projectContent componentsSeparatedByString:@"\n"]];
    
    NSArray *deleteImages = _unusedImageNames.allValues;
    
    for (NSDictionary *imageInfo in deleteImages) {
        
        NSArray *imageKeys = imageInfo[@"keys"];
        for (NSString *key in imageKeys) {
            [projectContentArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                if([obj containsString:key])
                {
                    [projectContentArray removeObjectAtIndex:idx];
                }
            }];
        }
        
        NSArray *imagePaths = imageInfo[@"paths"];
        for (NSString *path in imagePaths) {
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        }
    }
    
    projectContent = [projectContentArray componentsJoinedByString:@"\n"];
    
    NSError *error = nil;
    [projectContent writeToFile:projectPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if(error) {
        dispatch_async(dispatch_get_main_queue(), ^{
        });
    }
     */
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();
    
    [imageNames enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_async(group, queue, ^{
            NSString *fileName = (NSString *)obj;
            NSString *imagePath = nil;
            NSMutableDictionary *imageInfo = [_imageNames objectForKey:fileName];
            if (imageInfo) {
                NSMutableArray *imagePaths = imageInfo[@"paths"];
                imagePath = [imagePaths firstObject];
            }
            
            BOOL isImagePathEmpty = [imagePath isEqualToString:@""];
            if (!isImagePathEmpty) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (self.delegate && [self.delegate respondsToSelector:@selector(searcher:didFindUnusedImage:)]) {
                        [self.delegate searcher:self didFindUnusedImage:imagePath];
                    }
                    
                });
            }
        });
    }];
    
    dispatch_group_notify(group, queue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(searcher:didFinishSearch:)]) {
                [self.delegate searcher:self didFinishSearch:nil];
            }
        });
    });
}

- (void)extractBuldPhasesContent:(NSArray *)targets {
    for (NSString *target in targets) {
        NSDictionary *targetInfo = _objects[target];
        NSArray *buildPhases = targetInfo[@"buildPhases"];
        for (NSString *buildPhaseKey in buildPhases) {
            NSDictionary *phaseInfo = _objects[buildPhaseKey];
            NSString *type = phaseInfo[@"isa"];
            
            if ([type isEqualToString:@"PBXSourcesBuildPhase"] || [type isEqualToString:@"PBXResourcesBuildPhase"]) {
                NSArray *files = phaseInfo[@"files"];
                for (NSString *fileKey in files) {
                    NSDictionary *fileInfo = _objects[fileKey];
                    NSString *fileRef = fileInfo[@"fileRef"];
                    NSDictionary *fileRefDic = _objects[fileRef];
                    NSString *fileName = fileRefDic[@"name"] ? : fileRefDic[@"path"];
                    
                    NSString *pathExtension = [fileName.pathExtension lowercaseString];
                    if ([pathExtension isEqualToString:@"m"] || [pathExtension isEqualToString:@"xib"]) {
                        [_fileNames addObject:fileName];
                    }
                    else if ([pathExtension isEqualToString:@"png"] || [pathExtension isEqualToString:@"gif"] || [pathExtension isEqualToString:@"jpg"] || [pathExtension isEqualToString:@"jpeg"]) {
                        fileName = fileName.stringByDeletingPathExtension;
                        NSInteger location = [fileName rangeOfString:@"@"].location;
                        if (location != NSNotFound) {
                            fileName = [fileName substringToIndex:location];
                        }
                        fileName = [fileName stringByAppendingPathExtension:pathExtension];
                        NSMutableDictionary *imageInfo = [_imageNames objectForKey:fileName];
                        if (imageInfo == nil) {
                            imageInfo = [NSMutableDictionary dictionary];
                            [_imageNames setObject:imageInfo forKey:fileName];
                        }
                        NSMutableArray *imageKeys = imageInfo[@"keys"];
                        if (imageKeys == nil) {
                            imageKeys = [NSMutableArray array];
                            [imageInfo setObject:imageKeys forKey:@"keys"];
                        }
                        if (![imageKeys containsObject:fileKey]) {
                            [imageKeys addObject:fileKey];
                        }
                    }
                }
            }
        }
    }
}

- (void)checkImageUsed:(NSString *)dir PBXGroup:(NSDictionary *)PBXGroup key:(NSString *)fromKey {
    NSArray *children = PBXGroup[@"children"];
    NSString *path = PBXGroup[@"path"];
    NSString *sourceTree = PBXGroup[@"sourceTree"];
    if (path.length > 0) {
        if ([sourceTree isEqualToString:@"<group>"]) {
            dir = [dir stringByAppendingPathComponent:path];
        }
        else if ([sourceTree isEqualToString:@"SOURCE_ROOT"]) {
            dir = [_projectDirPath stringByAppendingPathComponent:path];
        }
    }
    if (children.count == 0) {
        NSString *pathExtension = dir.pathExtension;
        if ([pathExtension isEqualToString:@"m"]) {
            [self checkImageWithCodePath:dir isXib:NO];
        }
        else if ([pathExtension isEqualToString:@"xib"]) {
            [self checkImageWithCodePath:dir isXib:YES];
        }
        else if ([pathExtension isEqualToString:@"png"] || [pathExtension isEqualToString:@"gif"] || [pathExtension isEqualToString:@"jpg"] || [pathExtension isEqualToString:@"jpeg"]) {
            [self saveImagePathInfo:dir key:fromKey];
        }
    }
    else {
        for (NSString *key in children) {
            NSDictionary *childrenDic = _objects[key];
            [self checkImageUsed:dir PBXGroup:childrenDic key:key];
        }
    }
}

- (void)checkImageWithCodePath:(NSString *)mPath isXib:(BOOL)isXib {
    NSString *contentFile = [NSString stringWithContentsOfFile:mPath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularStr = @"\"(\\\\\"|[^\"^\\s]|[\\r\\n])+\"";
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regularStr options:0 error:nil];
    if (!contentFile) {
        return;
    }
    
    NSArray *matches = [regex matchesInString:contentFile options:0 range:NSMakeRange(0, contentFile.length)];
    
    for (NSTextCheckingResult *match in matches) {
        NSRange range = [match range];
        range.location += 1;
        range.length -= 2;
        NSString *subStr = [contentFile substringWithRange:range];
        
        NSString *pathExtension = [subStr.pathExtension lowercaseString];
        if (isXib && pathExtension.length == 0) {
            continue;
        }
        if (pathExtension.length == 0) {
            pathExtension = @"png";
        }
        else if ([pathExtension isEqualToString:@"png"] || [pathExtension isEqualToString:@"gif"] || [pathExtension isEqualToString:@"jpg"] || [pathExtension isEqualToString:@"jpeg"]) {
            
        }
        else {
            continue;
        }
        
        NSString *fileName = subStr.stringByDeletingPathExtension;
        NSInteger location = [fileName rangeOfString:@"@"].location;
        if (location != NSNotFound) {
            fileName = [fileName substringToIndex:location];
        }
        fileName = [fileName stringByAppendingPathExtension:pathExtension];
        
        if (fileName.length == 0) {
            continue;
        }
        
        [_unusedImageNames removeObjectForKey:fileName];
        [_unusedImageNames removeObjectForKey:[fileName stringByAppendingString:@"_up.png"]];
        [_unusedImageNames removeObjectForKey:[fileName stringByAppendingString:@"_han.png"]];
        for (int i = 0; i < 10; i++) {
            [_unusedImageNames removeObjectForKey:[fileName stringByAppendingFormat:@"_%d.png",i]];
            [_unusedImageNames removeObjectForKey:[fileName stringByAppendingFormat:@"%d.png",i]];
        }
    }
}

- (void)saveImagePathInfo:(NSString *)imagePath key:(NSString *)key {
    NSString *fileName = imagePath.lastPathComponent;
    NSString *pathExtension = fileName.pathExtension;
    
    fileName = fileName.stringByDeletingPathExtension;
    NSInteger location = [fileName rangeOfString:@"@"].location;
    if (location != NSNotFound) {
        fileName = [fileName substringToIndex:location];
    }
    fileName = [fileName stringByAppendingPathExtension:pathExtension];
    
    NSMutableDictionary *imageInfo = [_imageNames objectForKey:fileName];
    if (imageInfo) {
        NSMutableArray *imagePaths = imageInfo[@"paths"];
        if (imagePaths == nil) {
            imagePaths = [NSMutableArray array];
            [imageInfo setObject:imagePaths forKey:@"paths"];
        }
        if (![imagePaths containsObject:imagePath]) {
            [imagePaths addObject:imagePath];
        }
        
        NSMutableArray *imageKeys = imageInfo[@"keys"];
        if (imageKeys) {
            imageKeys = [NSMutableArray array];
            [imageInfo setObject:imageKeys forKey:@"keys"];
        }
        if (![imageKeys containsObject:key]) {
            [imageKeys addObject:key];
        }
    }
}

@end
