//
//  ScoreAudioInstrumentLoader.h
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 7/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScoreAudioInstrumentLoader : NSObject

+(void)loadInstrumentForSequence:(MusicSequence)sequence track:(MusicTrack)track;

@end

NS_ASSUME_NONNULL_END
