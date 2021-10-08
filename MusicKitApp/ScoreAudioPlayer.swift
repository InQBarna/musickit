//
//  ScoreAudioPlayer.swift
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 6/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFAudio

@objc protocol ScoreAudioPlayerDelegate: AnyObject {
    @objc func updatePlayPosition(measures: TimeInterval)
}

@objc class ScoreAudioPlayer: NSObject {
    
    private var midi: MIDIOldschool?
    private var sampler: Sampler1?
    private var scoreSequence = [ScoreSequenceItem]()
    private var musicTrack: MusicTrack?
    
    @objc weak var delegate: ScoreAudioPlayerDelegate?
    
    @objc var bpm: Double = 90
    
    private var playMetronomeOnly: Bool = false
    
    @objc func load(scoreSequence: [ScoreSequenceItem]) {
        self.scoreSequence = scoreSequence
        makeMIDISequence()
        
//
//        var musicPlayer : MusicPlayer? = nil
//        var player = NewMusicPlayer(&musicPlayer)
//
//        player = MusicPlayerSetSequence(musicPlayer!, sequence)
//        player = MusicPlayerStart(musicPlayer!)
        
//        let sampler = AVAudioUnitSampler(.loadSoundBankInstrument(<#T##self: AVAudioUnitSampler##AVAudioUnitSampler#>)
//        var result: OSStatus
//        var graph: AUGraph?
//        result =  MusicSequenceGetAUGraph (sequence!, &graph);
//        result =  MusicSequenceGetIndTrack (sequence!, 0, &track)
//
//        var myNode = AUNode()
//        result = MusicTrackGetDestNode(track!, &myNode);
//
//        var mySamplerUnit: AudioUnit?
//        result = AUGraphNodeInfo(graph!, myNode, nil, &mySamplerUnit);

//        ScoreAudioInstrumentLoader.loadInstrument(for: sequence!, track: track!)
        
        //
//        self.midi = MIDIOldschool(
//            soundBankURL: URL(fileURLWithPath: Bundle.main.path(forResource: "Violin", ofType: "sf2")!),
//            sequence: sequence!,
//            track: track!)
//        self.midi?.play()
    }
    
    private func makeMIDISequence() {
        var sequence : MusicSequence? = nil
        _ = NewMusicSequence(&sequence)

        var track : MusicTrack? = nil
        _ = MusicSequenceNewTrack(sequence!, &track)

        // Adding notes

        var time = MusicTimeStamp(0.0)
        
        for chord in scoreSequence {
            let duration = (chord.duration / 0.125) * (60 / Float(bpm))
            if duration == 0 {
                print("grace note? \(chord.notes.first)")
            } else {
                for item in chord.notes {
                    var note = MIDINoteMessage(channel: UInt8(item.channel),
                                               note: UInt8(item.note),
                                               velocity: 64,
                                               releaseVelocity: 0,
                                               duration: duration)
                    _ = MusicTrackNewMIDINoteEvent(track!, time, &note)
                    print("duration = \(duration)")
                }
                
                time += Double(duration)
                print("time = \(time)")
            }
        }
        
        if sampler != nil {
            sampler?.sequenceData = sequenceData(musicSequence: sequence!)! as Data
            sampler?.loadSequence()
        } else {
            sampler = Sampler1(data: sequenceData(musicSequence: sequence!)! as Data)
            sampler?.playPositionListening = { interval in
                let measures =  interval * 0.125 * 2 * (self.bpm / 60)
                self.delegate?.updatePlayPosition(measures: measures)
            }
        }
        sampler?.loadSF2PresetIntoSampler(name: "Violin", preset: 0)
        
        self.musicTrack = track
    }
    
    private func makeMetronomeSequence() {
        let musicTimestamp = getTrackLength(musicTrack: musicTrack!)
        var sequence : MusicSequence? = nil
        _ = NewMusicSequence(&sequence)

        var track : MusicTrack? = nil
        _ = MusicSequenceNewTrack(sequence!, &track)

        // Adding notes

        var time = MusicTimeStamp(0.0)
        let beatDuration = (0.250 / 0.125) * (60 / Float(bpm))
        while time < musicTimestamp {
            var note = MIDINoteMessage(channel: 1,
                                       note: UInt8(55),
                                       velocity: 64,
                                       releaseVelocity: 0,
                                       duration: beatDuration)
            _ = MusicTrackNewMIDINoteEvent(track!, time, &note)
            time += Double(beatDuration)
            print("time = \(time)")
        }
        
        if sampler != nil {
            sampler?.sequenceData = sequenceData(musicSequence: sequence!)! as Data
            sampler?.loadSequence()
        } else {
            sampler = Sampler1(data: sequenceData(musicSequence: sequence!)! as Data)
            sampler?.playPositionListening = { interval in
                let measures =  interval * 0.125 * 2 * (self.bpm / 60)
                self.delegate?.updatePlayPosition(measures: measures)
            }
        }
        
        sampler?.loadSF2PresetIntoSampler(name: "HS Acoustic Percussion", preset: 0)
    }
    
    @objc func configureBPM(_ value: Double) {
        self.bpm = value
        
        makeMIDISequence()
    }
    
    @objc func configureMetronome(active: Bool) {
        if active != self.playMetronomeOnly {
            self.playMetronomeOnly = active
            
            if active {
                makeMetronomeSequence()
            } else {
                makeMIDISequence()
            }
        }
    }
    
    @objc func play() {
        sampler?.play()
    }
    
    @objc func stop() {
        sampler?.stop()
    }
    
    func getTrackLength(musicTrack:MusicTrack) -> MusicTimeStamp {
        //The time of the last music event in a music track, plus time required for note fade-outs and so on.
        var trackLength:MusicTimeStamp = 0
        var tracklengthSize:UInt32 = 0
        var status = MusicTrackGetProperty(musicTrack,
                                           UInt32(kSequenceTrackProperty_TrackLength),
                                           &trackLength,
                                           &tracklengthSize)
        if status != OSStatus(noErr) {
            print("Error getting track length \(status)")
            return 0
        }
        print("track length is \(trackLength)")
        return trackLength
    }
    
    func sequenceData(musicSequence: MusicSequence) -> NSData? {
        var status = OSStatus(noErr)
            
        var data:Unmanaged<CFData>?
        status = MusicSequenceFileCreateData(
            musicSequence,
            MusicSequenceFileTypeID.midiType,
            MusicSequenceFileFlags.eraseFile,
            480,
            &data)
        if status != noErr {
            print("error turning MusicSequence into NSData")
            return nil
        }
            
        let ns:NSData = data!.takeUnretainedValue()
        data?.release()
        return ns
    }
}

@objc class Sampler1 : NSObject {
    var engine: AVAudioEngine!
    var sampler: AVAudioUnitSampler!
    var sequencer: AVAudioSequencer!
    
    var sequenceData: Data
    var timer: Timer?
    
    var playPositionListening: ((TimeInterval) -> Void)?
    
    init(data: Data) {
        self.sequenceData = data
        
        super.init()
 
        engine = AVAudioEngine()
        
        sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        
        loadSF2PresetIntoSampler(name: "Violin", preset: 0)
        
        setupSequencer()
        
        addObservers()
        
        startEngine()
        
        setSessionPlayback()
    }
    
    func setSessionPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try
            audioSession.setCategory(.playback, options: .mixWithOthers)
            } catch {
                print("couldn't set category \(error)")
                return
            }
            
        do {
            try audioSession.setActive(true)
        } catch {
            print("couldn't set category active \(error)")
            return
        }
    }
    
    func startEngine() {
        if engine.isRunning {
            print("audio engine already started")
            return
        }
            
        do {
            try engine.start()
            print("audio engine started")
        } catch {
            print("oops \(error)")
            print("could not start audio engine")
        }
    }
    
    func loadSF2PresetIntoSampler(name: String, preset:UInt8)  {
        guard let bankURL = Bundle.main.url(forResource: name, withExtension: "sf2") else {
            print("could not load sound font")
            return
        }
            
        do {
            try self.sampler.loadSoundBankInstrument(at: bankURL,
                program: preset,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        } catch {
            print("error loading sound bank instrument")
        }
    }
    
    func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(engineConfigurationChange(notification:)),
            name: Notification.Name.AVAudioEngineConfigurationChange,
            object:engine)
        
        NotificationCenter.default.addObserver(
            self,
            selector:#selector(sessionInterrupted(notification:)),
            name: AVAudioSession.interruptionNotification,
            object:engine)
        
        NotificationCenter.default.addObserver(
            self,
            selector:#selector(sessionRouteChange(notification:)),
            name:AVAudioSession.routeChangeNotification,
            object:engine)
    }
        
    func removeObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name.AVAudioEngineConfigurationChange,
            object: nil)
        
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil)
            
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil)
    }
     
    @objc func engineConfigurationChange(notification:NSNotification) {
        print("engineConfig change: \(notification)")
    }
    
    @objc func sessionInterrupted(notification:NSNotification) {
        print("session Interrupted: \(notification)")
    }
    
    @objc func sessionRouteChange(notification:NSNotification) {
        print("session route change: \(notification)")
    }
     
    func setupSequencer() {
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        loadSequence()
    }
    
    func loadSequence() {
        let options = AVMusicSequenceLoadOptions.smf_ChannelsToTracks
        do {
            try sequencer.load(from: sequenceData, options: options)
            print("loaded sequence data")
        } catch {
            print("something screwed up \(error)")
            return
        }
        sequencer.prepareToPlay()
    }
        
    func play() {
        if sequencer.isPlaying {
            stop()
        }
            
        sequencer.currentPositionInBeats = TimeInterval(0)
            
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { _ in
            print("currentPos: \(self.sequencer.currentPositionInSeconds) secs")
            self.playPositionListening?(self.sequencer.currentPositionInSeconds)
        })
        
        do {
            try sequencer.start()
        } catch {
            print("cannot start \(error)")
        }
    }
        
    func stop() {
        sequencer.stop()
        
        timer?.invalidate()
        timer = nil
    }
}
