//
//  FICDPhotosTableViewCell.h
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import <UIKit/UIKit.h>

@class FICDPhoto;

@interface FICDPhotosTableViewCell : UITableViewCell

@property (nonatomic, assign) BOOL usesImageTable;
@property (nonatomic, copy) NSArray *photos;
@property (nonatomic, copy) NSString *imageFormatName;

+ (NSString *)reuseIdentifier;
+ (NSInteger)photosPerRow;
+ (CGFloat)outerPadding;
+ (CGFloat)rowHeight;

@end