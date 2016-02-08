//
//  FICDViewController.m
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICDViewController.h"
#import "FICImageCache.h"
#import "FICDTableView.h"
#import "FICDAppDelegate.h"
#import "FICDPhoto.h"
#import "FICDPhotosTableViewCell.h"

#pragma mark Class Extension

@interface FICDViewController () <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate> {
    FICDTableView *_tableView;
    NSArray *_photos;
    
    NSString *_imageFormatName;
    NSArray *_imageFormatStyleToolbarItems;
    
    BOOL _usesImageTable;
    BOOL _shouldReloadTableViewAfterScrollingAnimationEnds;
    BOOL _shouldResetData;
    NSInteger _selectedMethodSegmentControlIndex;
    NSInteger _callbackCount;
    UIAlertView *_noImagesAlertView;
    UILabel *_averageFPSLabel;
}

@end

#pragma mark

@implementation FICDViewController

#pragma mark - Object Lifecycle

- (id)init {
    self = [super init];
    
    if (self != nil) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSArray *imageURLs = [mainBundle URLsForResourcesWithExtension:@"jpg" subdirectory:@"Demo Images"];
        
        if ([imageURLs count] > 0) {
            NSMutableArray *photos = [[NSMutableArray alloc] init];

            // Create lots of photos to scroll through
            for (int i = 0; i < 5000; i++) {
                FICDPhoto *photo = [[FICDPhoto alloc] init];
                [photo setSourceImageURL:imageURLs[i % imageURLs.count]];
                [photos addObject:photo];
            }

            _photos = photos;
        } else {
            NSString *title = @"No Source Images";
            NSString *message = @"There are no JPEG images in the Demo Images folder. Please run the fetch_demo_images.sh script, or add your own JPEG images to this folder before running the demo app.";
            _noImagesAlertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [_noImagesAlertView show];
        }
    }
    
    return self;
}

- (void)dealloc {
    [_tableView setDelegate:nil];
    [_tableView setDataSource:nil];
    
    [_noImagesAlertView setDelegate:nil];
}

#pragma mark - View Controller Lifecycle

- (void)loadView {
    CGRect viewFrame = [[UIScreen mainScreen] bounds];
    UIView *view = [[UIView alloc] initWithFrame:viewFrame];
    [view setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
    [view setBackgroundColor:[UIColor whiteColor]];
    
    [self setView:view];
    
    // Configure the table view
    if (_tableView == nil) {
        _tableView = [[FICDTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        [_tableView setDataSource:self];
        [_tableView setDelegate:self];
        [_tableView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
        [_tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        [_tableView registerClass:[FICDPhotosTableViewCell class] forCellReuseIdentifier:[FICDPhotosTableViewCell reuseIdentifier]];
        
        CGFloat tableViewCellOuterPadding = [FICDPhotosTableViewCell outerPadding];
        [_tableView setContentInset:UIEdgeInsetsMake(0, 0, tableViewCellOuterPadding, 0)];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            [_tableView setScrollIndicatorInsets:UIEdgeInsetsMake(7, 0, 7, 1)];
        }
    }
    
    [_tableView setFrame:[view bounds]];
    [view addSubview:_tableView];
    
    // Configure the navigation item
    UINavigationItem *navigationItem = [self navigationItem];
    
    UIBarButtonItem *resetBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Reset" style:UIBarButtonItemStylePlain target:self action:@selector(_reset)];
    [navigationItem setLeftBarButtonItem:resetBarButtonItem];
    
    UISegmentedControl *methodSegmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Conventional", @"Image Table", nil]];
    [methodSegmentedControl setSelectedSegmentIndex:0];
    [methodSegmentedControl addTarget:self action:@selector(_methodSegmentedControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    [methodSegmentedControl sizeToFit];
    [navigationItem setTitleView:methodSegmentedControl];
    
    // Configure the average FPS label
    if (_averageFPSLabel == nil) {
        _averageFPSLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 54, 22)];
        [_averageFPSLabel setBackgroundColor:[UIColor clearColor]];
        [_averageFPSLabel setFont:[UIFont boldSystemFontOfSize:16]];
        [_averageFPSLabel setTextAlignment:NSTextAlignmentRight];
        
        [_tableView addObserver:self forKeyPath:@"averageFPS" options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    UIBarButtonItem *averageFPSLabelBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_averageFPSLabel];
    [navigationItem setRightBarButtonItem:averageFPSLabelBarButtonItem];
    
    // Configure the image format styles toolbar
    if (_imageFormatStyleToolbarItems == nil) {
        NSMutableArray *mutableImageFormatStyleToolbarItems = [NSMutableArray array];
        
        UIBarButtonItem *flexibleSpaceToolbarItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
        [mutableImageFormatStyleToolbarItems addObject:flexibleSpaceToolbarItem];
        
        NSArray *imageFormatStyleSegmentedControlTitles = nil;
        BOOL userInterfaceIdiomIsPhone = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
        
        if (userInterfaceIdiomIsPhone) {
            imageFormatStyleSegmentedControlTitles = [NSArray arrayWithObjects:@"32BGRA", @"32BGR", @"16BGR", @"8Grayscale", nil];
        } else {
            imageFormatStyleSegmentedControlTitles = [NSArray arrayWithObjects:@"32-bit BGRA", @"32-bit BGR", @"16-bit BGR", @"8-bit Grayscale", nil];
        }
        
        UISegmentedControl *imageFormatStyleSegmentedControl = [[UISegmentedControl alloc] initWithItems:imageFormatStyleSegmentedControlTitles];
        [imageFormatStyleSegmentedControl setSelectedSegmentIndex:0];
        [imageFormatStyleSegmentedControl addTarget:self action:@selector(_imageFormatStyleSegmentedControlValueChanged:) forControlEvents:UIControlEventValueChanged];
        [imageFormatStyleSegmentedControl setApportionsSegmentWidthsByContent:userInterfaceIdiomIsPhone];
        [imageFormatStyleSegmentedControl sizeToFit];
        
        UIBarButtonItem *imageFormatStyleSegmentedControlToolbarItem = [[UIBarButtonItem alloc] initWithCustomView:imageFormatStyleSegmentedControl];
        [mutableImageFormatStyleToolbarItems addObject:imageFormatStyleSegmentedControlToolbarItem];
        
        [mutableImageFormatStyleToolbarItems addObject:flexibleSpaceToolbarItem];
        
        _imageFormatStyleToolbarItems = [mutableImageFormatStyleToolbarItems copy];
    }
    
    [self setToolbarItems:_imageFormatStyleToolbarItems];
    
    _imageFormatName = FICDPhotoSquareImage32BitBGRAFormatName;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self reloadTableViewAndScrollToTop:YES];
}

#pragma mark - Reloading Data

- (void)reloadTableViewAndScrollToTop:(BOOL)scrollToTop {

    if (scrollToTop) {
        // If the table view isn't already scrolled to top, we do that now, deferring the actual table view reloading logic until the animation finishes.
        CGFloat tableViewTopmostContentOffsetY = 0;
        CGFloat tableViewCurrentContentOffsetY = [_tableView contentOffset].y;
        
        if ([self respondsToSelector:@selector(topLayoutGuide)]) {
            id <UILayoutSupport> topLayoutGuide = [self topLayoutGuide];
            tableViewTopmostContentOffsetY = -[topLayoutGuide length];
        }
        
        if (tableViewCurrentContentOffsetY > tableViewTopmostContentOffsetY) {
            [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
            
            _shouldReloadTableViewAfterScrollingAnimationEnds = YES;
        }
    }
    
    if (_shouldReloadTableViewAfterScrollingAnimationEnds == NO) {
        // Reset the data now
        if (_shouldResetData) {
            _shouldResetData = NO;
            [[FICImageCache sharedImageCache] reset];
            
            // Delete all cached thumbnail images as well
            for (FICDPhoto *photo in _photos) {
                [photo deleteThumbnail];
            }
        }
        
        _usesImageTable = _selectedMethodSegmentControlIndex == 1;
        
        [[self navigationController] setToolbarHidden:(_usesImageTable == NO) animated:YES];

        [_tableView reloadData];
        [_tableView resetScrollingPerformanceCounters];
    }
}

- (void)_reset {
    _shouldResetData = YES;
    
    [self reloadTableViewAndScrollToTop:YES];
}

- (void)_methodSegmentedControlValueChanged:(UISegmentedControl *)segmentedControl {
    _selectedMethodSegmentControlIndex = [segmentedControl selectedSegmentIndex];
    
    // If there's any scrolling momentum, we want to stop it now
    CGPoint tableViewContentOffset = [_tableView contentOffset];
    [_tableView setContentOffset:tableViewContentOffset animated:NO];
    
    [self reloadTableViewAndScrollToTop:NO];
}

- (void)_imageFormatStyleSegmentedControlValueChanged:(UISegmentedControl *)segmentedControl {
    NSInteger selectedSegmentedControlIndex = [segmentedControl selectedSegmentIndex];
    
    if (selectedSegmentedControlIndex == 0) {
        _imageFormatName = FICDPhotoSquareImage32BitBGRAFormatName;
    } else if (selectedSegmentedControlIndex == 1) {
        _imageFormatName = FICDPhotoSquareImage32BitBGRFormatName;
    } else if (selectedSegmentedControlIndex == 2) {
        _imageFormatName = FICDPhotoSquareImage16BitBGRFormatName;
    } else if (selectedSegmentedControlIndex == 3) {
        _imageFormatName = FICDPhotoSquareImage8BitGrayscaleFormatName;
    }
    
    [self reloadTableViewAndScrollToTop:NO];
}

#pragma mark - Displaying the Average Framerate

- (void)_displayAverageFPS:(CGFloat)averageFPS {
    if ([_averageFPSLabel attributedText] == nil) {
        CATransition *fadeTransition = [CATransition animation];
        [[_averageFPSLabel layer] addAnimation:fadeTransition forKey:kCATransition];
    }
    
    NSString *averageFPSString = [NSString stringWithFormat:@"%.0f", averageFPS];
    NSUInteger averageFPSStringLength = [averageFPSString length];
    NSString *displayString = [NSString stringWithFormat:@"%@ FPS", averageFPSString];
    
    UIColor *averageFPSColor = [UIColor blackColor];
    
    if (averageFPS > 45) {
        averageFPSColor = [UIColor colorWithHue:(114 / 359.0) saturation:0.99 brightness:0.89 alpha:1]; // Green
    } else if (averageFPS <= 45 && averageFPS > 30) {
        averageFPSColor = [UIColor colorWithHue:(38 / 359.0) saturation:0.99 brightness:0.89 alpha:1];  // Orange
    } else if (averageFPS < 30) {
        averageFPSColor = [UIColor colorWithHue:(6 / 359.0) saturation:0.99 brightness:0.89 alpha:1];   // Red
    }
    
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:displayString];
    [mutableAttributedString addAttribute:NSForegroundColorAttributeName value:averageFPSColor range:NSMakeRange(0, averageFPSStringLength)];
    
    [_averageFPSLabel setAttributedText:mutableAttributedString];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideAverageFPSLabel) object:nil];
    [self performSelector:@selector(_hideAverageFPSLabel) withObject:nil afterDelay:1.5];
}

- (void)_hideAverageFPSLabel {
    CATransition *fadeTransition = [CATransition animation];
    
    [_averageFPSLabel setAttributedText:nil];
    [[_averageFPSLabel layer] addAnimation:fadeTransition forKey:kCATransition];
}

#pragma mark - Protocol Implementations

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = ceilf((CGFloat)[_photos count] / (CGFloat)[FICDPhotosTableViewCell photosPerRow]);
    
    return numberOfRows;
}

- (UITableViewCell*)tableView:(UITableView*)table cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    NSString *reuseIdentifier = [FICDPhotosTableViewCell reuseIdentifier];
    
    FICDPhotosTableViewCell *tableViewCell = (FICDPhotosTableViewCell *)[table dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    tableViewCell.selectionStyle = UITableViewCellSeparatorStyleNone;

    [tableViewCell setImageFormatName:_imageFormatName];
    
    NSInteger photosPerRow = [FICDPhotosTableViewCell photosPerRow];
    NSInteger startIndex = [indexPath row] * photosPerRow;
    NSInteger count = MIN(photosPerRow, [_photos count] - startIndex);
    NSArray *photos = [_photos subarrayWithRange:NSMakeRange(startIndex, count)];
    
    [tableViewCell setUsesImageTable:_usesImageTable];
    [tableViewCell setPhotos:photos];
    
    return tableViewCell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [FICDPhotosTableViewCell rowHeight];
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate {
    if (willDecelerate == NO) {
        [_tableView resetScrollingPerformanceCounters];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [_tableView resetScrollingPerformanceCounters];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [_tableView resetScrollingPerformanceCounters];

    if (_shouldReloadTableViewAfterScrollingAnimationEnds) {
        _shouldReloadTableViewAfterScrollingAnimationEnds = NO;
        
        // Add a slight delay before reloading the data
        double delayInSeconds = 0.1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self reloadTableViewAndScrollToTop:NO];
        });
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView == _noImagesAlertView) {
        [NSThread exit];
    }
}

#pragma mark - NSObject (NSKeyValueObserving)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _tableView && [keyPath isEqualToString:@"averageFPS"]) {
        CGFloat averageFPS = [[change valueForKey:NSKeyValueChangeNewKey] floatValue];
        averageFPS = MIN(MAX(0, averageFPS), 60);
        [self _displayAverageFPS:averageFPS];
    }
}

@end
