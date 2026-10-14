import SwiftUI

// Sacudir o aparelho só existe em iOS (UIKit/CoreMotion não têm equivalente em macOS).
import UIKit
import CoreMotion

// MARK: - Método 1: UIKit (motionEnded) + NotificationCenter
//
// Abordagem simples, usa o evento de movimento nativo do UIKit.
// O sistema decide o que conta como "sacudida", sem parâmetros ajustáveis.

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name("deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

private struct ShakeViewModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

extension View {
    /// Detecta sacudidas via UIKit motionEnded. Só funciona em dispositivo físico.
    func onShakeUIKit(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeViewModifier(action: action))
    }
}

// MARK: - Método 2: CoreMotion (CMMotionManager)
//
// Lê o acelerômetro continuamente e compara a variação entre leituras.
// Dá controle total sobre a sensibilidade (shakeThreshold) e a frequência
// de amostragem (updateInterval), ao custo de mais código e consumo de bateria.
// Observação: o simulador não reporta dados reais de acelerômetro, então
// isAccelerometerAvailable normalmente retorna false nele.

@Observable
final class CoreMotionShakeDetector {
    private let motionManager = CMMotionManager()
    private var lastAcceleration: CMAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    private var lastShakeDate: Date?

    var shakeThreshold: Double = 2.5
    // Tempo mínimo entre dois disparos, para que uma única sacudida (que gera
    // várias leituras acima do threshold em sequência) conte como um só evento.
    var shakeCooldown: TimeInterval = 1.0
    var onShake: (() -> Void)?
    // Chamado a cada leitura do acelerômetro (10x por segundo), com a magnitude
    // bruta da variação. Usado para alimentar um haptic contínuo em tempo real,
    // diferente do onShake, que só dispara uma vez por sacudida (com cooldown).
    var onMotionUpdate: ((Double) -> Void)?

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }

            let acceleration = data.acceleration
            let delta = abs(acceleration.x - self.lastAcceleration.x)
                + abs(acceleration.y - self.lastAcceleration.y)
                + abs(acceleration.z - self.lastAcceleration.z)
            self.lastAcceleration = acceleration

            self.onMotionUpdate?(delta)

            guard delta > self.shakeThreshold else { return }

            let now = Date()
            if let lastShakeDate, now.timeIntervalSince(lastShakeDate) < self.shakeCooldown {
                return
            }
            self.lastShakeDate = now
            self.onShake?()
        }
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }
}
