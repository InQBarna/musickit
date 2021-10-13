//
//  PitchEstimation.swift
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 8/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

import Foundation
import Beethoven
import Pitchy

class PitchEstimation: PitchEstimationInterface {
    lazy var pitchEngine: PitchEngine = { [weak self] in
      let config = Config(bufferSize: 1024, estimationStrategy: .yin)
      let pitchEngine = PitchEngine(config: config, delegate: self)
      pitchEngine.levelThreshold = -30.0
      return pitchEngine
    }()
    
    var onPitchEstimated: ((Double, String, Int) -> Void)?

    public func start() {
        pitchEngine.start()
    }
    
    public func stop() {
        pitchEngine.stop()
    }
}

extension PitchEstimation: PitchEngineDelegate   {
    func pitchEngine(_ pitchEngine: PitchEngine, didReceivePitch pitch: Pitch) {
        print("[PITCH]: pitch = \(pitch.frequency) --> estimNote : \(pitch.note.letter)\(pitch.note.octave)")
        onPitchEstimated?(pitch.frequency, pitch.note.letter.rawValue, pitch.note.octave + 1)
    }
    
    func pitchEngine(_ pitchEngine: PitchEngine, didReceiveError error: Error) {
        print("[PITCH]: error = \(error)")
    }
    
    func pitchEngineWentBelowLevelThreshold(_ pitchEngine: PitchEngine) {
        print("[PITCH]: below level threshold")
    }
}
