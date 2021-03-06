//
//  PMCollectionViewAdPlacer.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 25/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMCollectionViewAdPlacer.h"
#import "IANTimer.h"
#import "StreamAdPlacer.h"
#import "PMAdRendering.h"
#import <objc/runtime.h>
#import "AdPlacerInvocation.h"
#import "InstanceProvider.h"
#import "Constants.h"
#import "PMNativeAdTrackerDelegate.h"

@interface PMCollectionViewAdPlacer () <UICollectionViewDataSource, UICollectionViewDelegate, StreamAdPlacerDelegate, UICollectionViewDelegateFlowLayout,PMNativeAdTrackerDelegate>

@property (nonatomic, strong) StreamAdPlacer *streamAdPlacer;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, weak) id<UICollectionViewDataSource> originalDataSource;
@property (nonatomic, weak) id<UICollectionViewDelegate> originalDelegate;
@property (nonatomic, assign) Class defaultAdRenderingClass;
@property (nonatomic, strong) IANTimer *insertionTimer;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation PMCollectionViewAdPlacer

+ (instancetype)placerWithCollectionView:(UICollectionView *)collectionView viewController:(UIViewController *)controller defaultAdRenderingClass:(Class)defaultAdRenderingClass
{
    return [[self class] placerWithCollectionView:collectionView viewController:controller adPositions:[PMServerAdPositions positioning] defaultAdRenderingClass:defaultAdRenderingClass];
}

+ (instancetype)placerWithCollectionView:(UICollectionView *)collectionView viewController:(UIViewController *)controller adPositions:(PMAdPositions *)positions defaultAdRenderingClass:(Class)defaultAdRenderingClass
{
    PMCollectionViewAdPlacer *collectionViewAdPlacer = [[PMCollectionViewAdPlacer alloc] initWithCollectionView:collectionView viewController:controller adPositioning:positions defaultAdRenderingClass:defaultAdRenderingClass];
    return collectionViewAdPlacer;
}

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView viewController:(UIViewController *)controller adPositioning:(PMAdPositions *)positioning defaultAdRenderingClass:(Class)defaultAdRenderingClass
{
    NSAssert([defaultAdRenderingClass isSubclassOfClass:[UICollectionViewCell class]], @"A collection view ad placer must be instantiated with a rendering class that is a UICollectionViewCell");
    
    if (self = [super init]) {
        _collectionView = collectionView;
        _streamAdPlacer = [[InstanceProvider sharedProvider] buildStreamAdPlacerWithViewController:controller adPositioning:positioning defaultAdRenderingClass:defaultAdRenderingClass];
        _streamAdPlacer.delegate = self;
        _streamAdPlacer.trackerDelegate = self;
        _insertionTimer = [IANTimer timerWithTimeInterval:kUpdateCellVisibilityInterval target:self selector:@selector(updateVisibleCells) repeats:YES];
        _insertionTimer.runLoopMode = NSRunLoopCommonModes;
        [_insertionTimer scheduleNow];
        
        _originalDataSource = collectionView.dataSource;
        _originalDelegate = collectionView.delegate;
        collectionView.dataSource = self;
        collectionView.delegate = self;
        
        _defaultAdRenderingClass = defaultAdRenderingClass;
        [self registerNibOrClass];
        
        [collectionView pm_setAdPlacer:self];
    }
    
    return self;
}

- (void)dealloc
{
    [_insertionTimer invalidate];
}

- (void)registerNibOrClass
{
    // We're only supporting one rendering class right now so we can pass nil for the index path.
    NSString *adCellReuseIdentifier = [_streamAdPlacer reuseIdentifierForRenderingClassAtIndexPath:nil];
    
    // First, see if the rendering class provides a nib that we should register on the collection view.
    if ([_defaultAdRenderingClass respondsToSelector:@selector(nibForAd)]) {
        UINib *nib = [UINib nibWithNibName:[_defaultAdRenderingClass nibForAd] bundle:nil];
        NSAssert(nib, @"+nibForAd must return a valid UINib object as string.");
        [_collectionView registerNib:nib forCellWithReuseIdentifier:adCellReuseIdentifier];
    } else {
        // If the rendering class doesn't provide a nib, register the class directly.
        [_collectionView registerClass:[_defaultAdRenderingClass class] forCellWithReuseIdentifier:adCellReuseIdentifier];
    }
}

#pragma mark - Public

- (void)loadAdsForAdUnitID:(NSString *)adUnitID
{
    [self.streamAdPlacer loadAdsForAdUnitID:adUnitID];
}

- (void)loadAdsForAdUnitID:(NSString *)adUnitID targeting:(PMAdRequestTargeting *)targeting
{
    [self.streamAdPlacer loadAdsForAdUnitID:adUnitID targeting:targeting];
}

#pragma mark - Ad Insertion

- (void)updateVisibleCells
{
    NSArray *visiblePaths = self.collectionView.pm_indexPathsForVisibleItems;
    
    if ([visiblePaths count]) {
        [self.streamAdPlacer setVisibleIndexPaths:visiblePaths];
    }
}

#pragma mark - <StreamAdPlacerDelegate>

- (void)adPlacer:(StreamAdPlacer *)adPlacer didLoadAdAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL animationsWereEnabled = [UIView areAnimationsEnabled];
    //We only want to enable animations if the index path is before or within our visible cells
    BOOL animationsEnabled = ([(NSIndexPath *)[self.collectionView.indexPathsForVisibleItems lastObject] compare:indexPath] != NSOrderedAscending) && animationsWereEnabled;
    
    [UIView setAnimationsEnabled:animationsEnabled];
    
    [self.collectionView insertItemsAtIndexPaths:@[indexPath]];
    
    [UIView setAnimationsEnabled:animationsWereEnabled];
}

- (void)adPlacer:(StreamAdPlacer *)adPlacer didRemoveAdsAtIndexPaths:(NSArray *)indexPaths
{
    BOOL animationsWereEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    
    [self.collectionView performBatchUpdates:^{
        [self.collectionView deleteItemsAtIndexPaths:indexPaths];
    } completion:^(BOOL finished) {
        [UIView setAnimationsEnabled:animationsWereEnabled];
    }];
}

#pragma mark - <UICollectionViewDataSource>

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSUInteger numberOfItems = [self.originalDataSource collectionView:collectionView numberOfItemsInSection:section];
    [self.streamAdPlacer setItemCount:numberOfItems forSection:section];
    return [self.streamAdPlacer adjustedNumberOfItems:numberOfItems inSection:section];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.streamAdPlacer isAdAtIndexPath:indexPath]) {
        
        //This is to modify the default rendering class value after fetching from sdk configs
        _defaultAdRenderingClass = self.streamAdPlacer.defaultAdRenderingClass;
        [self registerNibOrClass];
        
        NSString *identifier = [self.streamAdPlacer reuseIdentifierForRenderingClassAtIndexPath:indexPath];
        UICollectionViewCell<PMAdRendering> *cell = (UICollectionViewCell<PMAdRendering> *)[collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
        cell.clipsToBounds = YES;
        
        [self.streamAdPlacer renderAdAtIndexPath:indexPath inView:cell];
        return cell;
    }
    
    NSIndexPath *originalIndexPath = [self.streamAdPlacer originalIndexPathForAdjustedIndexPath:indexPath];
    return [self.originalDataSource collectionView:collectionView cellForItemAtIndexPath:originalIndexPath];
}

#pragma mark - <UICollectionViewDelegate>

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if ([self.streamAdPlacer isAdAtIndexPath:indexPath]) {
        return NO;
    }
    
    id<UICollectionViewDelegate> delegate = self.originalDelegate;
    if ([delegate respondsToSelector:@selector(collectionView:canPerformAction:forItemAtIndexPath:withSender:)]) {
        NSIndexPath *originalPath = [self.streamAdPlacer originalIndexPathForAdjustedIndexPath:indexPath];
        return [delegate collectionView:collectionView canPerformAction:action forItemAtIndexPath:originalPath withSender:sender];
    }
    
    return NO;
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [AdPlacerInvocation invokeForTarget:self.originalDelegate with2ArgSelector:@selector(collectionView:didDeselectItemAtIndexPath:) firstArg:collectionView secondArg:indexPath streamAdPlacer:self.streamAdPlacer];
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    [AdPlacerInvocation invokeForTarget:self.originalDelegate with3ArgSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:) firstArg:collectionView secondArg:cell thirdArg:indexPath streamAdPlacer:self.streamAdPlacer];
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    [AdPlacerInvocation invokeForTarget:self.originalDelegate with2ArgSelector:@selector(collectionView:didHighlightItemAtIndexPath:) firstArg:collectionView secondArg:indexPath streamAdPlacer:self.streamAdPlacer];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.streamAdPlacer isAdAtIndexPath:indexPath]) {
        [self.streamAdPlacer displayContentForAdAtAdjustedIndexPath:indexPath];
        [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
        return;
    }
    
    id<UICollectionViewDelegate> delegate = self.originalDelegate;
    if ([delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        NSIndexPath *originalPath = [self.streamAdPlacer originalIndexPathForAdjustedIndexPath:indexPath];
        [delegate collectionView:collectionView didSelectItemAtIndexPath:originalPath];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    [AdPlacerInvocation invokeForTarget:self.originalDelegate with2ArgSelector:@selector(collectionView:didUnhighlightItemAtIndexPath:) firstArg:collectionView secondArg:indexPath streamAdPlacer:self.streamAdPlacer];
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if ([self.streamAdPlacer isAdAtIndexPath:indexPath]) {
        return;
    }
    
    id<UICollectionViewDelegate> delegate = self.originalDelegate;
    if ([delegate respondsToSelector:@selector(collectionView:performAction:forItemAtIndexPath:withSender:)]) {
        NSIndexPath *originalPath = [self.streamAdPlacer originalIndexPathForAdjustedIndexPath:indexPath];
        [delegate collectionView:collectionView performAction:action forItemAtIndexPath:originalPath withSender:sender];
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInvocation *invocation = [AdPlacerInvocation invokeForTarget:self.originalDelegate with2ArgSelector:@selector(collectionView:shouldDeselectItemAtIndexPath:) firstArg:collectionView secondArg:indexPath streamAdPlacer:self.streamAdPlacer];
    
    return [AdPlacerInvocation boolResultForInvocation:invocation defaultValue:YES];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInvocation *invocation = [AdPlacerInvocation invokeForTarget:self.originalDelegate with2ArgSelector:@selector(collectionView:shouldHighlightItemAtIndexPath:) firstArg:collectionView secondArg:indexPath streamAdPlacer:self.streamAdPlacer];
    
    return [AdPlacerInvocation boolResultForInvocation:invocation defaultValue:YES];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInvocation *invocation = [AdPlacerInvocation invokeForTarget:self.originalDelegate with2ArgSelector:@selector(collectionView:shouldSelectItemAtIndexPath:) firstArg:collectionView secondArg:indexPath streamAdPlacer:self.streamAdPlacer];
    
    return [AdPlacerInvocation boolResultForInvocation:invocation defaultValue:collectionView.allowsSelection];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInvocation *invocation = [AdPlacerInvocation invokeForTarget:self.originalDelegate with2ArgSelector:@selector(collectionView:shouldShowMenuForItemAtIndexPath:) firstArg:collectionView secondArg:indexPath streamAdPlacer:self.streamAdPlacer];
    
    return [AdPlacerInvocation boolResultForInvocation:invocation defaultValue:NO];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.streamAdPlacer isAdAtIndexPath:indexPath]) {
        return [self.streamAdPlacer sizeForAdAtIndexPath:indexPath withMaximumWidth:CGRectGetWidth(self.collectionView.bounds)];
    }
    
    if ([self.originalDelegate respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)]) {
        NSIndexPath *originalPath = [self.streamAdPlacer originalIndexPathForAdjustedIndexPath:indexPath];
        id<UICollectionViewDelegateFlowLayout> flowLayout = (id<UICollectionViewDelegateFlowLayout>)[self originalDelegate];
        return [flowLayout collectionView:collectionView layout:collectionViewLayout sizeForItemAtIndexPath:originalPath];
    }
    return ((UICollectionViewFlowLayout *)collectionViewLayout).itemSize;
}

#pragma mark - Method Forwarding

- (BOOL)isKindOfClass:(Class)aClass {
    return [super isKindOfClass:aClass] ||
    [self.originalDataSource isKindOfClass:aClass] ||
    [self.originalDelegate isKindOfClass:aClass];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
    return [super conformsToProtocol:aProtocol] ||
    [self.originalDelegate conformsToProtocol:aProtocol] ||
    [self.originalDataSource conformsToProtocol:aProtocol];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [super respondsToSelector:aSelector] ||
    [self.originalDataSource respondsToSelector:aSelector] ||
    [self.originalDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if ([self.originalDataSource respondsToSelector:aSelector]) {
        return self.originalDataSource;
    } else if ([self.originalDelegate respondsToSelector:aSelector]) {
        return self.originalDelegate;
    } else {
        return [super forwardingTargetForSelector:aSelector];
    }
}

#pragma mark - PMNativeAdTrackerDelegate
- (void)anNativeAdDidRecordImpression
{
    if ([self.delegate respondsToSelector:@selector(anNativeAdDidRecordImpression)]) {
        [self.delegate anNativeAdDidRecordImpression];
    }
}

- (BOOL)anNativeAdDidClick:(PMNativeAd *)nativeAd
{
    if ([self.delegate respondsToSelector:@selector(anNativeAdDidClick:)]) {
        return [self.delegate anNativeAdDidClick:nativeAd];
    }
    return NO;
}

- (void)anNativeAdWillLeaveApplication
{
    if ([self.delegate respondsToSelector:@selector(anNativeAdWillLeaveApplication)]) {
        [self.delegate anNativeAdWillLeaveApplication];
    }
}
@end

@implementation UICollectionView (PMCollectionViewAdPlacer)

static char kAdPlacerKey;

- (void)pm_setAdPlacer:(PMCollectionViewAdPlacer *)placer
{
    objc_setAssociatedObject(self, &kAdPlacerKey, placer, OBJC_ASSOCIATION_ASSIGN);
}

- (PMCollectionViewAdPlacer *)pm_adPlacer
{
    return objc_getAssociatedObject(self, &kAdPlacerKey);
}

- (void)pm_setDelegate:(id<UICollectionViewDelegate>)delegate
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    
    if (adPlacer) {
        adPlacer.originalDelegate = delegate;
    } else {
        self.delegate = delegate;
    }
}

- (id<UICollectionViewDelegate>)pm_delegate
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    
    if (adPlacer) {
        return adPlacer.originalDelegate;
    } else {
        return self.delegate;
    }
}

- (void)pm_setDataSource:(id<UICollectionViewDataSource>)dataSource
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    
    if (adPlacer) {
        adPlacer.originalDataSource = dataSource;
    } else {
        self.dataSource = dataSource;
    }
}

- (id<UICollectionViewDataSource>)pm_dataSource
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    
    if (adPlacer) {
        return adPlacer.originalDataSource;
    } else {
        return self.dataSource;
    }
}

- (id)pm_dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedIndexPath = indexPath;
    
    if (adPlacer) {
        adjustedIndexPath = [adPlacer.streamAdPlacer adjustedIndexPathForOriginalIndexPath:indexPath];
    }
    
    // Only pass nil through if developer passed it through
    if (!indexPath || adjustedIndexPath) {
        return [self dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:adjustedIndexPath];
    } else {
        return nil;
    }
}

- (NSArray <NSIndexPath *> *)pm_indexPathsForSelectedItems
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSArray *adjustedIndexPaths = [self indexPathsForSelectedItems];
    
    if (adPlacer) {
        adjustedIndexPaths = [adPlacer.streamAdPlacer originalIndexPathsForAdjustedIndexPaths:adjustedIndexPaths];
    }
    
    return adjustedIndexPaths;
}

- (void)pm_selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedIndexPath = indexPath;
    
    if (adPlacer) {
        adjustedIndexPath = [adPlacer.streamAdPlacer adjustedIndexPathForOriginalIndexPath:indexPath];
    }
    
    // Only pass nil through if developer passed it through
    if (!indexPath || adjustedIndexPath) {
        [self selectItemAtIndexPath:adjustedIndexPath animated:animated scrollPosition:scrollPosition];
    }
}

- (void)pm_deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedIndexPath = indexPath;
    
    if (adPlacer) {
        adjustedIndexPath = [adPlacer.streamAdPlacer adjustedIndexPathForOriginalIndexPath:indexPath];
    }
    
    [self deselectItemAtIndexPath:adjustedIndexPath animated:animated];
}

- (void)pm_reloadData
{
    [self reloadData];
}

- (UICollectionViewLayoutAttributes *)pm_layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedIndexPath = indexPath;
    
    if (adPlacer) {
        adjustedIndexPath = [adPlacer.streamAdPlacer adjustedIndexPathForOriginalIndexPath:indexPath];
    }
    
    return [self layoutAttributesForItemAtIndexPath:adjustedIndexPath];
}

- (NSIndexPath *)pm_indexPathForItemAtPoint:(CGPoint)point
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedIndexPath = [self indexPathForItemAtPoint:point];
    
    if (adPlacer) {
        adjustedIndexPath = [adPlacer.streamAdPlacer originalIndexPathForAdjustedIndexPath:adjustedIndexPath];
    }
    
    return adjustedIndexPath;
}

- (NSIndexPath *)pm_indexPathForCell:(UICollectionViewCell *)cell
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedIndexPath = [self indexPathForCell:cell];
    
    if (adPlacer) {
        adjustedIndexPath = [adPlacer.streamAdPlacer originalIndexPathForAdjustedIndexPath:adjustedIndexPath];
    }
    
    return adjustedIndexPath;
}

- (UICollectionViewCell *)pm_cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedIndexPath = indexPath;
    
    if (adPlacer) {
        adjustedIndexPath = [adPlacer.streamAdPlacer adjustedIndexPathForOriginalIndexPath:adjustedIndexPath];
    }
    
    return [self cellForItemAtIndexPath:adjustedIndexPath];
}

- (NSArray *)pm_visibleCells
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    
    if (adPlacer) {
        NSArray *indexPaths = [self pm_indexPathsForVisibleItems];
        NSMutableArray *visibleCells = [NSMutableArray array];
        for (NSIndexPath *indexPath in indexPaths) {
            [visibleCells addObject:[self pm_cellForItemAtIndexPath:indexPath]];
        }
        return visibleCells;
    } else {
        return [self visibleCells];
    }
}

- (NSArray <NSIndexPath *> *)pm_indexPathsForVisibleItems
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSArray *adjustedIndexPaths = [self indexPathsForVisibleItems];
    
    if (adPlacer) {
        adjustedIndexPaths = [adPlacer.streamAdPlacer originalIndexPathsForAdjustedIndexPaths:adjustedIndexPaths];
    }
    
    return adjustedIndexPaths;
}

- (void)pm_scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedIndexPath = indexPath;
    
    if (adPlacer) {
        adjustedIndexPath = [adPlacer.streamAdPlacer adjustedIndexPathForOriginalIndexPath:adjustedIndexPath];
    }
    
    // Only pass nil through if developer passed it through
    if (!indexPath || adjustedIndexPath) {
        [self scrollToItemAtIndexPath:adjustedIndexPath atScrollPosition:scrollPosition animated:animated];
    }
}

- (void)pm_insertSections:(NSIndexSet *)sections
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    
    if (adPlacer) {
        [adPlacer.streamAdPlacer insertSections:sections];
    }
    
    [self insertSections:sections];
}

- (void)pm_deleteSections:(NSIndexSet *)sections
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    
    if (adPlacer) {
        [adPlacer.streamAdPlacer deleteSections:sections];
    }
    
    [self deleteSections:sections];
}

- (void)pm_reloadSections:(NSIndexSet *)sections
{
    [self reloadSections:sections];
}

- (void)pm_moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    
    if (adPlacer) {
        [adPlacer.streamAdPlacer moveSection:section toSection:newSection];
    }
    
    [self moveSection:section toSection:newSection];
}

- (void)pm_insertItemsAtIndexPaths:(NSArray *)indexPaths
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSArray *adjustedIndexPaths = indexPaths;
    
    if (adPlacer) {
        [adPlacer.streamAdPlacer insertItemsAtIndexPaths:indexPaths];
        adjustedIndexPaths = [adPlacer.streamAdPlacer adjustedIndexPathsForOriginalIndexPaths:indexPaths];
    }
    
    // We perform the actual UI insertion AFTER updating the stream ad placer's
    // data, because the insertion can trigger queries to the data source, which
    // needs to reflect the post-insertion state.
    [self insertItemsAtIndexPaths:adjustedIndexPaths];
}

- (void)pm_deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    [self performBatchUpdates:^{
        NSArray *adjustedIndexPaths = indexPaths;
        
        if (adPlacer) {
            // We need to obtain the adjusted index paths to delete BEFORE we
            // update the stream ad placer's data.
            adjustedIndexPaths = [adPlacer.streamAdPlacer adjustedIndexPathsForOriginalIndexPaths:indexPaths];
            
            [adPlacer.streamAdPlacer deleteItemsAtIndexPaths:indexPaths];
        }
        
        // We perform the actual UI deletion AFTER updating the stream ad placer's
        // data, because the deletion can trigger queries to the data source, which
        // needs to reflect the post-deletion state.
        [self deleteItemsAtIndexPaths:adjustedIndexPaths];
    } completion:nil];
}

- (void)pm_reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSArray *adjustedIndexPaths = indexPaths;
    
    if (adPlacer) {
        adjustedIndexPaths = [adPlacer.streamAdPlacer adjustedIndexPathsForOriginalIndexPaths:indexPaths];
    }
    
    [self reloadItemsAtIndexPaths:adjustedIndexPaths];
}

- (void)pm_moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    PMCollectionViewAdPlacer *adPlacer = [self pm_adPlacer];
    NSIndexPath *adjustedFrom = indexPath;
    NSIndexPath *adjustedTo = newIndexPath;
    
    if (adPlacer) {
        // We need to obtain the adjusted index paths to move BEFORE we
        // update the stream ad placer's data.
        adjustedFrom = [adPlacer.streamAdPlacer adjustedIndexPathForOriginalIndexPath:indexPath];
        adjustedTo = [adPlacer.streamAdPlacer adjustedIndexPathForOriginalIndexPath:newIndexPath];
        
        [adPlacer.streamAdPlacer moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
    }
    
    // We perform the actual UI operation AFTER updating the stream ad placer's
    // data, because the operation can trigger queries to the data source, which
    // needs to reflect the post-operation state.
    [self moveItemAtIndexPath:adjustedFrom toIndexPath:adjustedTo];
}

@end
