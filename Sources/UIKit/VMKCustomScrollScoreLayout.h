//
//  VMKCustomScrollScoreLayout.h
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 5/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VMKScrollScoreLayout.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMKCustomScrollScoreLayout : VMKScrollScoreLayout

@property (nonatomic, assign) CGFloat width;

-(id)initWithWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
