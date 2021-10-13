//
//  PitchEstimationFake.swift
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 11/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

import Foundation

class PitchEstimationFake: PitchEstimationInterface {

    var onPitchEstimated: ((Double, String, Int) -> Void)?
    
    private var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.05,
            repeats: true,
            block: { _ in
                self.onPitchEstimated?(329.63, "A", 4)
            })
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
}
