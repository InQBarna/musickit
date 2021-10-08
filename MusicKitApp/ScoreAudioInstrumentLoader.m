//
//  ScoreAudioInstrumentLoader.m
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 7/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

#import "ScoreAudioInstrumentLoader.h"

@implementation ScoreAudioInstrumentLoader

+(void)loadInstrumentForSequence:(MusicSequence)sequence track:(MusicTrack)track {
    AUGraph graph;
    MusicSequenceGetAUGraph (sequence, &graph);
    
    AUNode myNode;
    OSStatus result = MusicTrackGetDestNode(track, &myNode);
    
    AudioUnit mySamplerUnit;
    AUGraphNodeInfo(graph, myNode, 0, &mySamplerUnit);
    
    NSString *instrumentPath = [[NSBundle mainBundle] pathForResource:@"Violin" ofType:@"sf2"];
    NSURL *url = [NSURL fileURLWithPath:instrumentPath];
    
    const char* instrumentPathC = [instrumentPath cStringUsingEncoding:NSUTF8StringEncoding];
    CFURLRef presetURL = CFURLCreateFromFileSystemRepresentation(
                                                                 kCFAllocatorDefault,
                                                                 instrumentPathC,
                                                                 [instrumentPath length],
                                                                 NO);
    
    AUSamplerInstrumentData instdata;
    instdata.fileURL  = presetURL;
    instdata.instrumentType = kInstrumentType_DLSPreset;
    instdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;
    instdata.bankLSB  = kAUSampler_DefaultBankLSB;
    instdata.presetID = (UInt8) 0;

         // set the kAUSamplerProperty_LoadPresetFromBank property
//    AudioUnitSetProperty(_midiPlayer.instrumentUnit,
//                         kAUSamplerProperty_LoadInstrument,
//                         kAudioUnitScope_Global,
//                         0,
//                         &instdata,
//                         sizeof(instdata));

    /*
     

         // check for errors
         NSCAssert (result == noErr,
                    @"Unable to set the preset property on the Sampler. Error code:%d '%.4s'",
                    (int) result,
                    (const char *)&result);
         //===============

         CheckError (AUGraphStart(_midiPlayer.graph), "couldn't start graph");
     */
    
//    // Initialise the sound font
//      AUSamplerInstrumentData all
//        fileURL: umURL,
//        instrumentType: UInt8(kInstrumentType_SF2Preset),
//        bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
//        bankLSB: UInt8(kAUSampler_DefaultBankLSB),
//        presetID: 1)

//        // set the kAUSamplerProperty_LoadPresetFromBank property
//        AudioUnitSetProperty(musicPlayer.instrument,
//                             kAUSamplerProperty_LoadInstrument,
//                             kAudioUnitScope_Global,
//                             0,
//                             &instrumentData,
//                             sizeof(instrumentData))

}

@end
