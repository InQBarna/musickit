//
//  VMKCustomScrollScoreLayout.m
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 5/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

#import "VMKCustomScrollScoreLayout.h"
#import "VMKGeometry.h"

@interface VMKCustomScrollScoreLayout ()
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath*,UICollectionViewLayoutAttributes*> *cachedAttributes;
@end

@implementation VMKCustomScrollScoreLayout

-(id)initWithWidth:(CGFloat)width {
    self = [super init];
    if (self) {
        self.width = width;
        self.cachedAttributes = @{}.mutableCopy;
    }
    
    return self;
}

-(void)setWidth:(CGFloat)width {
    if (width != _width) {
        _width = width;
        [self invalidateLayout];
    }
}

-(void)invalidateLayout {
    self.cachedAttributes = @{}.mutableCopy;
    [super invalidateLayout];
}

-(UICollectionViewLayoutAttributes *)layoutAttributesForGeometry:(const mxml::Geometry *)geometry atIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewLayoutAttributes *superAttrs = [super layoutAttributesForGeometry:geometry atIndexPath:indexPath];
    UICollectionViewLayoutAttributes* attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    
    NSLog(@"indexPath : %@", indexPath);
    
    CGRect frame = CGRectFromRect(self.scoreGeometry->convertFromGeometry(geometry->frame(), geometry->parentGeometry()));
    if (frame.origin.x + frame.size.width < self.width) {
        frame.origin.y += self.topOffset;
        frame = VMKRoundRect(frame);
        attributes.frame = frame;
    } else {
        NSIndexPath *prevPath = [NSIndexPath indexPathForItem:indexPath.item - 1 inSection:indexPath.section];
        UICollectionViewLayoutAttributes *previous = self.cachedAttributes[prevPath];
        
        if (previous) {
            CGFloat prevEnd = previous.frame.origin.x + previous.frame.size.width;
            if (prevEnd + frame.size.width < self.width) {
                frame.origin.x = prevEnd;
                frame.origin.y = previous.frame.origin.y;
                frame.size.height = previous.frame.size.height;
                //+ previous.frame.size.height - frame.size.height;
            } else {
                frame.origin.x = 0;
                frame.origin.y = previous.frame.origin.y + geometry->parentGeometry()->size().height + 20;
            }
        } else {
            frame.origin.x = 0;
            frame.origin.y += self.topOffset + geometry->parentGeometry()->size().height + 20;
        }
        
        frame = VMKRoundRect(frame);
        attributes.frame = frame;
    }
    
    self.cachedAttributes[indexPath] = attributes;
    
    return  attributes;
}

-(CGSize)collectionViewContentSize {
    CGSize superSize = [super collectionViewContentSize];
    NSLog(@"super = %@", NSStringFromCGSize(superSize));
    NSLog(@"fit in %f", self.width);
    
    NSInteger lines = ceil(superSize.width / self.width);
    CGSize size = CGSizeMake(self.width, lines * superSize.height + (lines - 1)*20);
    return  size;
}

@end
