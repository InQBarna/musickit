//
//  PitchEstimationInterface.swift
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 11/10/21.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

import Foundation

protocol PitchEstimationInterface {
    func start()
    func stop()
    
    var onPitchEstimated: ((Double, String, Int) -> Void)? { get set }
}
