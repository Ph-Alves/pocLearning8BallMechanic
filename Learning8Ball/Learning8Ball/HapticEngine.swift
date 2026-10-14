//
//  HapticEngine.swift
//  Learning8Ball
//
//  Created by Paulo Henrique Costa Alves on 14/10/26.
//

import Foundation
import CoreHaptics

class HapticEngine {
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var lastMotionDate: Date?
    // Chamado quando o loop contínuo é parado por inatividade (ou seja, a
    // pessoa realmente parou de sacudir) — não dispara em um stop manual.
    var onShakeSessionEnded: (() -> Void)?

    init(engine: CHHapticEngine? = nil) {
        self.engine = engine
    }
    
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Haptic contínuo para shake
    //
    // Mantém um CHHapticAdvancedPatternPlayer "aberto" enquanto o celular
    // estiver sendo sacudido, modulando intensidade/sharpness em tempo real
    // a cada leitura do acelerômetro via sendParameters.
    
    func startShakeLoop() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        guard continuousPlayer == nil else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        // Duração longa: o evento fica "aberto" até chamarmos stop() explicitamente.
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 100)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine?.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to start shake loop: \(error.localizedDescription)")
        }
    }
    
    func updateShakeIntensity(_ magnitude: Double) {
        lastMotionDate = Date()
        guard let continuousPlayer else { return }
        
        let value = Float(min(max(magnitude, 0), 1))
        let intensityParam = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: value, relativeTime: 0)
        let sharpnessParam = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: value, relativeTime: 0)
        
        do {
            try continuousPlayer.sendParameters([intensityParam, sharpnessParam], atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to update shake intensity: \(error.localizedDescription)")
        }
    }
    
    func stopShakeLoopIfIdle(timeout: TimeInterval = 0.25) {
        guard continuousPlayer != nil else { return }
        guard let lastMotionDate, Date().timeIntervalSince(lastMotionDate) > timeout else { return }
        stopShakeLoop()
        onShakeSessionEnded?()
    }
    
    func stopShakeLoop() {
        try? continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        continuousPlayer = nil
        lastMotionDate = nil
    }
}
