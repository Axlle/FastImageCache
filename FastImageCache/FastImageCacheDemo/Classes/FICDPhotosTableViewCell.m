//
//  FICDPhotosTableViewCell.m
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICDPhotosTableViewCell.h"
#import "FICDPhoto.h"
#import "FICImageCache.h"
#import "FICDAppDelegate.h"

#pragma mark Class Extension

@interface FICDPhotosTableViewCell () {
    BOOL _usesImageTable;
    NSArray *_photos;
    NSString *_imageFormatName;
    
    NSArray *_imageViews;
}

@end

#pragma mark

@implementation FICDPhotosTableViewCell

@synthesize usesImageTable = _usesImageTable;
@synthesize photos = _photos;
@synthesize imageFormatName = _imageFormatName;

#pragma mark - Property Accessors

- (void)setPhotos:(NSArray *)photos {
    if (photos != _photos) {
        _photos = [photos copy];

        for (NSInteger i = 0; i < [_imageViews count]; i++) {
            UIImageView *imageView = [_imageViews objectAtIndex:i];

            if (i < [_photos count]) {
                FICDPhoto *photo = [_photos objectAtIndex:i];

                if (_usesImageTable) {
                    [imageView setImage:nil];
                    [[FICImageCache sharedImageCache] asynchronouslyRetrieveImageForEntity:photo withFormatName:_imageFormatName completionBlock:^(id<FICEntity> entity, NSString *formatName, UIImage *image) {
                        // This completion block may be called much later. We should check to make sure this cell hasn't been reused for different photos before displaying the image that has loaded.
                        if (photos == [self photos]) {
                            [imageView setImage:image];
                        }
                    }];
                } else {
                    [imageView setImage:[photo thumbnailImage]];
                }
            } else {
                // Last row might not be full
                [imageView setImage:nil];
            }
        }
    }
}

#pragma mark - Class-Level Definitions

+ (NSString *)reuseIdentifier {
    static NSString *__reuseIdentifier = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __reuseIdentifier = NSStringFromClass([FICDPhotosTableViewCell class]);
    });

    return __reuseIdentifier;
}

+ (NSInteger)photosPerRow {
    NSInteger photosPerRow = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 9 : 4;
    
    return photosPerRow;
}

+ (CGFloat)outerPadding {
    CGFloat outerPadding = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 10 : 4;
    
    return outerPadding;
}

+ (CGFloat)rowHeight {
    CGFloat rowHeight = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 84 : 79;
    
    return rowHeight;
}

#pragma mark - Object Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self != nil) {

        NSInteger photosPerRow = [[self class] photosPerRow];
        NSMutableArray *imageViews = [[NSMutableArray alloc] initWithCapacity:photosPerRow];

        for (NSInteger i = 0; i < photosPerRow; i++) {
            UIImageView *imageView = [[UIImageView alloc] init];
            [imageView setContentMode:UIViewContentModeScaleAspectFill];
            [imageViews addObject:imageView];
            [self.contentView addSubview:imageView];
        }

        _imageViews = [imageViews copy];
    }
    
    return self;
}

- (id)init {
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

#pragma mark - Configuring the View Hierarchy

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat innerPadding = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 9 : 4;
    CGFloat outerPadding = [[self class] outerPadding];
    
    CGRect imageViewFrame = CGRectMake(outerPadding, outerPadding, FICDPhotoSquareImageSize.width, FICDPhotoSquareImageSize.height);

    NSInteger count = [_photos count];
    
    for (NSInteger i = 0; i < count; i++) {
        UIImageView *imageView = [_imageViews objectAtIndex:i];
        [imageView setFrame:imageViewFrame];

        imageViewFrame.origin.x += imageViewFrame.size.width + innerPadding;
    }
}

@end
