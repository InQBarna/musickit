//
//  SwiftMIDI.swift
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 7/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

import Foundation
import CoreMIDI
import CoreAudio
import AudioToolbox
import AVFoundation

fileprivate func createGraph() -> AUGraph {
    var masterGraphOpt: AUGraph?
    let status = NewAUGraph(&masterGraphOpt)
    guard let graph = masterGraphOpt, status == OSStatus(noErr) else {
        fatalError("Error: \(status)")
    }
    return graph
}

fileprivate func createSequence() -> MusicSequence {
    var sequenceOpt: MusicSequence?
    let status = NewMusicSequence(&sequenceOpt)
    guard let sequence = sequenceOpt, status == OSStatus(noErr) else {
        fatalError("Error: \(status)")
    }
    return sequence
}

fileprivate func createPlayer(with sequence: MusicSequence) -> MusicPlayer {
    var playerOpt: MusicPlayer?
    let status = NewMusicPlayer(&playerOpt)
    guard let player = playerOpt, status == OSStatus(noErr) else {
        fatalError("Error: \(status)")
    }
    MusicPlayerSetSequence(player, sequence)
    return player
}

fileprivate func createNode(from desc: inout AudioComponentDescription, in graph: AUGraph) -> AUNode {
    var samplerNode: AUNode = 0
    let status = AUGraphAddNode(graph, &desc, &samplerNode)
    guard status == OSStatus(noErr) else {
        fatalError("Error \(status)")
    }
    return samplerNode
}

fileprivate func getUnit(for node: AUNode, from graph: AUGraph) -> AUGraph {
    var unitOpt: AudioUnit?
    let status = AUGraphNodeInfo(graph, node, nil, &unitOpt)
    guard let unit = unitOpt, status == OSStatus(noErr) else {
        fatalError("Error \(status)")
    }
    return unit
}

class MIDIOldschool {
    let soundBankURL: URL
    var musicPlayer: MusicPlayer
    var musicSequence: MusicSequence
    var musicTrack: MusicTrack
    var masterGraph: AUGraph
    var outputNode: AUNode
    var mixerNode: AUNode
    
    
    var samplerNodes: [AUNode] = []
    
    func setSessionPlayback(isActive active: Bool) {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSession.Category.playback)
        } catch {
            print("could not set session category")
            print(error)
        }
        
        do {
            try session.setActive(active)
        } catch {
            print("could not make session active")
            print(error)
        }
    }
    
    init(soundBankURL: URL, sequence: MusicSequence, track: MusicTrack) {
        self.soundBankURL = soundBankURL
        
        musicSequence = sequence
        musicTrack = track
        musicPlayer = createPlayer(with: musicSequence)
        masterGraph = createGraph()
        MusicSequenceSetAUGraph(musicSequence, masterGraph)

        var ioDesc = AudioComponentDescription(componentType: OSType(kAudioUnitType_Output),
                                               componentSubType: OSType(kAudioUnitSubType_RemoteIO),
                                               componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
                                               componentFlags: 0, componentFlagsMask: 0)
        outputNode = createNode(from: &ioDesc, in: masterGraph)
        
        var mixerDesc = AudioComponentDescription(componentType: OSType(kAudioUnitType_Mixer),
                                                  componentSubType: OSType(kAudioUnitSubType_MultiChannelMixer),
                                                  componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
                                                  componentFlags: 0, componentFlagsMask: 0)
        mixerNode = createNode(from: &mixerDesc, in: masterGraph)
        
        
//        AUGraph graph;
//        result =  MusicSequenceGetAUGraph (sequence, &graph);
//
//        MusicTrack firstTrack;
//        result =  MusicSequenceGetIndTrack (sequence, 0, &firstTrack);
//
//        AUNode myNode;
//        result = MusicTrackGetDestNode(firstTrack,&myNode);
//
//        AudioUnit mySamplerUnit;
//        result = AUGraphNodeInfo(graph, myNode, 0, &mySamplerUnit);
    }
    
    func wireGraph() {
        var status = OSStatus(noErr)
        
        // Interconnect the mixer node to the output node.
        status = AUGraphConnectNodeInput(masterGraph, mixerNode, 0, outputNode, 0)
        guard status == OSStatus(noErr) else {
            fatalError("Error \(status)")
        }
        
        status = AUGraphOpen(masterGraph)
        guard status == OSStatus(noErr) else {
            fatalError("Error \(status)")
        }
        
        let mixerUnit = getUnit(for: mixerNode, from: masterGraph)
        var graphSampleRate = Float64(44100.0);
        status = AudioUnitSetProperty(mixerUnit,
                                      kAudioUnitProperty_SampleRate,
                                      kAudioUnitScope_Output,
                                      0,
                                      &graphSampleRate,
                                      UInt32(MemoryLayout<Float64>.stride))
        guard status == OSStatus(noErr) else {
            fatalError("Error \(status)")
        }
        
        var busCount = UInt32(samplerNodes.count)
        print(busCount)
        status = AudioUnitSetProperty(mixerUnit,
                                      kAudioUnitProperty_ElementCount,
                                      kAudioUnitScope_Input,
                                      0,
                                      &busCount,
                                      UInt32(MemoryLayout<UInt32>.stride))
        guard status == OSStatus(noErr) else {
            fatalError("Error \(status)")
        }
        
        for (index, samplerNode) in samplerNodes.enumerated() {
            // Interconnect the sampler node to the mixer node.
            print(index)
            status = AUGraphConnectNodeInput(masterGraph, samplerNode, 0, mixerNode, UInt32(index))
            guard status == OSStatus(noErr) else {
                fatalError("Error \(status)")
            }
            #if !((arch(i386) || arch(x86_64)) && os(iOS))
                loadInstrumentIntoNode(samplerNode, withPreset: 0)
            #endif
        }
        
        var outIsInitialized: DarwinBoolean = false
        status = AUGraphIsInitialized(masterGraph, &outIsInitialized)
        if outIsInitialized == false {
            status = AUGraphInitialize(masterGraph)
            guard status == OSStatus(noErr) else {
                fatalError("Error \(status)")
            }
            
        }
        
        var isRunning: DarwinBoolean = false
        AUGraphIsRunning(masterGraph, &isRunning)
        if isRunning == false {
            status = AUGraphStart(masterGraph)
            guard status == OSStatus(noErr) else {
                fatalError("Error \(status)")
            }
        }
    }

    
    private func loadInstrumentIntoNode(_ node: AUNode, withPreset preset: UInt8) {
        var status = OSStatus(noErr)
        let unit = getUnit(for: node, from: masterGraph)
        
        var url = soundBankURL
        status = AudioUnitSetProperty(unit,
                                      UInt32(kMusicDeviceProperty_SoundBankURL),
                                      UInt32(kAudioUnitScope_Global),
                                      0,
                                      &url,
                                      UInt32(MemoryLayout<CFURL>.stride))
        guard status == OSStatus(noErr) else {
            print("Error \(status)")
            return
        }
    }
    
    /// Loads a MIDI file into the sequence and sets up a new sampler for its tracks.
    func loadMIDISequence(from url: URL) {
        var status = OSStatus(noErr)
        
        var startingTracks: UInt32 = 0
        MusicSequenceGetTrackCount(musicSequence, &startingTracks);
        
        status = MusicSequenceFileLoad(musicSequence, url as NSURL, .midiType, MusicSequenceLoadFlags())
        guard status == OSStatus(noErr) else {
            print("Error \(status)")
            return
        }
        
        var endingTracks: UInt32 = 0
        MusicSequenceGetTrackCount(musicSequence, &endingTracks);
        
        // --- Load the instruments
        
        var samplerDesc = AudioComponentDescription(componentType: OSType(kAudioUnitType_MusicDevice),
                                                    componentSubType: OSType(kAudioUnitSubType_MIDISynth),
                                                    componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
                                                    componentFlags: 0, componentFlagsMask: 0)
        let samplerNode = createNode(from: &samplerDesc, in: masterGraph)
        
        for i in (startingTracks...endingTracks-1) {
            var trackOpt: MusicTrack?
            status = MusicSequenceGetIndTrack(musicSequence, UInt32(i), &trackOpt)
            guard let track = trackOpt, status == OSStatus(noErr) else {
                print("Error, skipping track \(i): \(status)")
                continue
            }
            
            status = MusicTrackSetDestNode(track, samplerNode)
            if status != OSStatus(noErr) {
                print("Error \(status)")
                continue
            }
        }
        
        
        samplerNodes.append(samplerNode)
    }
    
    public func play() {
        wireGraph()
        
//        CAShow(UnsafeMutablePointer<MusicSequence>(masterGraph))
        
        var isPlaying: DarwinBoolean = false
        MusicPlayerIsPlaying(musicPlayer, &isPlaying)
        if isPlaying == true {
            MusicPlayerStop(musicPlayer)
        }
        
        MusicPlayerSetTime(musicPlayer, 0);
        MusicPlayerStart(musicPlayer);
    }
    
    public func emphesizeTrack(at trackIndex: Int) {
        setVolume(1.0, forTrack: trackIndex)
    }
    
    public func unemphesizeTrack(at trackIndex: Int) {
        setVolume(0.0, forTrack: trackIndex)
    }
    
    public func setVolume(_ volume: Float, forTrack trackIndex: Int) {
        var status = OSStatus(noErr)
        
        print("Setting volume of bus \(trackIndex)")
        
        let mixerUnit = getUnit(for: mixerNode, from: masterGraph)
        CAShow(UnsafeMutablePointer<MusicSequence>(masterGraph))

        status = AudioUnitSetParameter(mixerUnit,
                                       kMultiChannelMixerParam_Volume,
                                       kAudioUnitScope_Input,
                                       UInt32(trackIndex),
                                       volume,
                                       0)
        guard status == OSStatus(noErr) else {
            print("Error setting volume: \(status)")
            return
        }
    }
}
