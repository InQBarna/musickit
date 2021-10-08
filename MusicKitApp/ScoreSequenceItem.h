//
//  ScoreSequenceItem.h
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 6/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScoreSequenceNote : NSObject
@property (nonatomic, assign) int note;
@property (nonatomic, assign) int channel;
@property (nonatomic, assign) int velocity;
@end

@interface ScoreSequenceItem : NSObject
@property (nonatomic, assign) float duration;
@property (nonatomic, strong) NSArray<ScoreSequenceNote*> *notes;
@end


NS_ASSUME_NONNULL_END
