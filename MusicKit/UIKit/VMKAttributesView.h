//  Copyright (c) 2014 Venture Media Labs. All rights reserved.

#import <UIKit/UIKit.h>

#include <mxml/geometry/ClefGeometry.h>
#include <mxml/geometry/KeyGeometry.h>
#include <mxml/geometry/PartGeometry.h>
#include <mxml/geometry/TimeSignatureGeometry.h>


@interface VMKAttributesView : UIView

@property(nonatomic) const mxml::PartGeometry* partGeometry;
@property(nonatomic, strong) UIColor* foregroundColor;
@property(nonatomic) CGFloat offset;

- (void)clear;
- (void)addClefGeometry:(const mxml::ClefGeometry*)clef;
- (void)addTimeGeometry:(const mxml::TimeSignatureGeometry*)time;
- (void)addKeyGeometry:(const mxml::KeyGeometry*)key;

@end
