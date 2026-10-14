#  Como o codigo atual funciona
E um codigo bem simples, com uma view, o app e um algoritmo de detecçao de sacudida.
vamos começar com o shakeDetection:
-
-
## ShakeDetection
```
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

    var shakeThreshold: Double = 2.5
    var onShake: (() -> Void)?

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }

            let acceleration = data.acceleration
            let delta = abs(acceleration.x - self.lastAcceleration.x)
                + abs(acceleration.y - self.lastAcceleration.y)
                + abs(acceleration.z - self.lastAcceleration.z)

            if delta > self.shakeThreshold {
                self.onShake?()
            }
            self.lastAcceleration = acceleration
        }
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }
}

```
Como pode ver, temos 2 alternativas, uma com UIKit (uma forma mais bem feita que usa o que a apple ja tem pronto, mas obriga a gente a implementar UIKit e outra mais recente usando core motion, mas exige mais controle, e mais linhas.)
Como pode ver, pegamos algumas extensions para que montemos um modificador e tambem usamos para disparar uma notificaçao, mas vamos por partes.
Precisamos do extension de UIWindow por que ela possui u metodo chamado motionEnded que e chamado automaticamente quando o sistema detecta um evento de movimento, e atualmente so existe o .motionShake que e exatamente o que precisamos, e o proprio sistema que decide, e quem melhor pra saber quando o dispositivo ta sacudindo do que o proprio sistema ne?
Assim que o sistema detecta essa sacudida, ele envia um evento, e e so isso que recebemos, diferente do CoreMotion que usamos diversos dados.
A apple nao fornece uma notificaçao pronta de sacudida, por isso a gente cria uma pegando o extension do UIDevice, nao e obrigatorio mas ja deixa o codigo meio documentado por que sabemos que isso e um conceito de UIDevice.
Depois montamos a extension de UIWindow, pegamos o motionEnded que ja existe mas sobrescrevemos com a implementacao que precisamos, caso o dispositivo tenha se sacudido (o UIResponder pregou o movimento) ai sim disparamos a notificaçao necessaria de que um movimento foi feito.
Acho que se eu for explicar cada elemento pedaço a pedaço essa explicacao seria muito longa, mas vamos simplificar:
- O UIKit ja possui um evento pronto de detecçao de movimentos, o motionEnded(), e ja consegue detectar qual o tipo de movimento (so existe shake e e exatamente o que precisamos)
- Pegamos esse metodo, postamos uma notificacao, e como criamos uma nova notificacao  personalizada na primeira extension, podemos publicar nela
- Depois, criamos um modificador de view que usa o .onReceive para receber a notiicacao e assim disparar o metodo de sortear atividade
- A action() e uma closure que pedimos pro modificador como parametro, pois nao e nossa responsabilidade agora definir o que deve ser executado ao usar o modificador, e sim responsabilidade da view. (talvez no projeto definitivo isso mude com a engine do foundations)

Como o UIWindow vem do objective-c, qual funcao vai ser chamada e definida em tempo de execuçao, e por isso podemos redefinir a funçao dessa forma, em classes e structs normais, isso nao seria possivel pois para isso precisariamos criar uma subclasse e fazer uma sobrecarga (todo um role)
Agora indo pra segunda forma, ela usa o CoreMotion, voce monta um manager, pega o acelerometro e vai verificando os valores necessarios, e o trabalho de definir o que e sacudir fica todo pro algoritmo que a gente montar.
De maneira simples, pegamos valor somado de X, Y, Z de aceleraçao e verificamos se isso e maior que 2.5, caso sim, consideramos uma sacudida.
E para entender completamente, vamos para a view

-
-
## ContentView
``` 
import SwiftUI
import Playgrounds

/*
 Objetivo
 Validar uma mecânica de sorteio de atividades inspirada na 8 Ball, utilizando diferentes formas de interação e adaptando sua aparência ao tema selecionado pelo usuário.

 Escopo

 Criar 4 tipos de 8 Ball, com aparência adaptada a cada um dos temas do app.

 Permitir sortear uma atividade por meio de:

 Sacudir o celular;

 Interagir com a 8 Ball com o dedo.

 Sortear uma atividade a partir da interação realizada.

 Exibir a atividade sorteada dentro da 8 Ball.

 Implementar réplicas/hápticos na interação para reforçar a sensação de resposta física.

 Criar uma animação de revelação, utilizando efeito de zoom para apresentar a atividade sorteada.

 Garantir que a animação, interação e aparência sejam adaptadas ao tema selecionado.

 Critério de aceite
 POC funcional em que o usuário consiga interagir com a 8 Ball por meio de movimento do celular ou toque, recebendo uma atividade sorteada que é apresentada dentro da 8 Ball com animação de zoom e feedback háptico, utilizando uma versão visual correspondente ao tema selecionado.
 */

enum theme: String, CaseIterable, Identifiable {
    var id: Self { self }
    
    case one
    case two
    case three
    
    var color: Color {
        switch self {
        case .one:
            return .white
        case .two:
            return .blue
        case .three:
            return .red
        }
    }
}

// Duas formas de detectar a sacudida, lado a lado, para comparar.
enum ShakeDetectionMethod: String, CaseIterable, Identifiable {
    case uiKitMotion = "UIKit (motionEnded)"
    case coreMotion = "CoreMotion"
    
    var id: Self { self }
}

struct ContentView: View {
    
    @State var currentTheme: theme = .one
    @State private var currentText = "Pode me sacudir :)"
    @State private var detectionMethod: ShakeDetectionMethod = .uiKitMotion
    @State private var coreMotionDetector = CoreMotionShakeDetector()
    @State private var ballScale: CGFloat = 1.0
    
    private let activities = [
        "Estudar SwiftUI",
        "Fazer uma caminhada",
        "Ler um livro",
        "Descansar um pouco",
        "Organizar as tarefas",
        "Tomar um café"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Picker("Selecione o tema", selection: $currentTheme) {
                ForEach(theme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            
            Picker("Método de detecção de shake", selection: $detectionMethod) {
                ForEach(ShakeDetectionMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            ZStack {
                Circle()
                    .strokeBorder(currentTheme.color, lineWidth: 2)
                    .frame(width: 220, height: 220)
                
                Text(currentText)
                    .id(currentText)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
            .scaleEffect(ballScale)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let isHorizontalSwipe = abs(value.translation.width) > abs(value.translation.height)
                        if isHorizontalSwipe {
                            sortearAtividade()
                        }
                    }
            )
            
            Text("Sacuda o celular (método \(detectionMethod.rawValue)) ou arraste a bola para os lados")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        // Método 1: UIKit motionEnded
        .onShakeUIKit {
            if detectionMethod == .uiKitMotion {
                sortearAtividade()
            }
        }
        // Método 2: CoreMotion
        .onAppear {
            coreMotionDetector.onShake = {
                if detectionMethod == .coreMotion {
                    sortearAtividade()
                }
            }
            coreMotionDetector.startMonitoring()
        }
        .onDisappear {
            coreMotionDetector.stopMonitoring()
        }
    }
    
    private func sortearAtividade() {
        // 1) zoom in na bola
        withAnimation(.easeOut(duration: 0.75)) {
            ballScale = 2.0
        } completion: {
            // 2) troca o texto (revela a atividade) e, ao mesmo tempo, o zoom volta ao normal
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                currentText = activities.randomElement() ?? currentText
                ballScale = 1.0
            }
        }
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}

```

E um codigo grandinho, mas de maneira simples, temos um picker de como queremos rastrear o movimento, um picker de temas, por que temos que mudar o valor da borda do circulo com base no tema (podemos mudar a imagem da mesma forma, se for um asset) e depois e so nossas manipulaçoes dos processos de registrar um movimento de sacudir.
Com o de UIKit, usamos o modificador, simples e direto, e defnimos aqui que a closure dele roda o sorteio quando o seletor de sacudida ta no de UIKit.
O mesmo pro coreMotion, mas ele exige que usemos o onAppear e onDisappear, onde começamos a monitorar e paramos de monitorar respectivamente.
E bem simples, e algo legal aqui tambem, e que temos um scale definido do circulo, e temos uma animaçao na funçao de sortear atividade, que aumenta o scale do circulo e usa a animaçao de spring para trocar o texto, voltando o circulo ao normal.
Podemos mexer nessa animaçao de outras maneiras, mas dessa forma ja cumpre o processo do ZoomIn da task.
Outro detalhe, mas sobre o CoreMotion, e que temos um cooldown de sacudida, que pega um segundo de intervalo, e simples de implementar e age tal qual o do UIKit.

## Implementaçao de haptics
Quando precisamos implementar haptics, ainda mais um que trabalha em cima dessa ideia de chacoalhar precisamos montar uma certa estrutura que vai andar em harmonia com o core motion.
```
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

```
Começando pela engine, temos um metodo que prepara ela (roda no onAppear) e montar a engine que precisamos que vincula ao servidor de haptics do dispositivo.
Depois, temos um start, um update, um end when idle e um end normal, cada um com seu intuito
O start roda um haptics de duraçao 100 por que ele precisa continuar executando e aberto enquanto ele nao e parado, ja que ele vai rodar quando o movimento for detectado.
pra isso ele precisa de um evento e um pattern, um evento e um haptic individual e um pattern e um conjunto de eventos que vai ser executado.
usamos o advancedPlayer e rodamos o start usando o CHHapticTimeImmediate para rodar na hora.
O update pega um valor, pega o maior entre ele e 0, depois o menor entre ele e 1, pois nao podemos definir menor que 0 e nem maior que 1 para os parametros de sharpness e intensity do haptics.
Agora temos 2 stops, um responsavel por executar o stop principal quando nao receber nenhum aviso de movimento, e outro que termina tudo tanto para o onDisappear finalizar o processo.
Como pode ver, temos uma closure que e executada no stop, mas vamos entrar nas closures depois, precisamos entender as alteraçoes do ShakeDetection:
```
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
```
A principal (e praticamente unica alteraçao, e que ele tem uma closure que executa metodos de haptics conforme for detectado um delta, e agora sim a gente pode ir pra view para ligar os pontos.
nao vou mostrar toda a view, so as alteraçoes que tiveram por que elas que sao realmente impactantes, peço que consulte o arquivo se for necessario lembrar da estrutura do circulo e tudo mais.
```
/// Novas variaveis
    @State private var hapticEngine = HapticEngine()
    @State private var shakeIdleTimer: Timer?
    @State private var shakeWasStrongEnough = false
    @State private var ballScale: CGFloat = 1.0
    
    // Abaixo deste valor de variação do acelerômetro, consideramos que não há
    // sacudida em andamento (ruído natural de segurar o celular na mão).
    private let motionFeedbackThreshold: Double = 0.3
    

/// Novo onAppear e onDisappear
.onAppear {
            hapticEngine.prepareHaptics()

            // O sorteio só acontece quando o haptic contínuo para por inatividade
            // (pessoa parou de sacudir) e, durante o movimento, a intensidade
            // chegou a cruzar o shakeThreshold — evita sortear com tremores leves.
            hapticEngine.onShakeSessionEnded = {
                guard detectionMethod == .coreMotion, shakeWasStrongEnough else { return }
                shakeWasStrongEnough = false
                sortearAtividade()
            }
            // Haptic contínuo: toca enquanto a variação do acelerômetro estiver
            // acima do threshold, com intensidade proporcional à força do movimento.
            coreMotionDetector.onMotionUpdate = { delta in
                guard detectionMethod == .coreMotion else { return }
                guard delta > motionFeedbackThreshold else { return }
                hapticEngine.startShakeLoop()
                let normalized = min(delta / coreMotionDetector.shakeThreshold, 1.0)
                hapticEngine.updateShakeIntensity(normalized)
                if delta > coreMotionDetector.shakeThreshold {
                    shakeWasStrongEnough = true
                }
            }
            coreMotionDetector.startMonitoring()
            
            // Como não há um evento de "parou de sacudir", verificamos periodicamente
            // se faz tempo que não chega leitura acima do threshold e paramos o haptic.
            shakeIdleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                hapticEngine.stopShakeLoopIfIdle()
            }
        }
        .onDisappear {
            coreMotionDetector.stopMonitoring()
            shakeIdleTimer?.invalidate()
            shakeIdleTimer = nil
            hapticEngine.stopShakeLoop()
        }
    
```

De maneira simples, a tela aparece, prepara o Haptics (engine setada), prepara a closure que e executada quando um haptics termina (para de receber update) que basicamente verifica se o movimento foi forte o suficiente e ai sim pode rodar a atividade caso seja.
Precisamos que essa seja uma closure, por que o ideal e ela rodar ao final de um haptics, para que a tarefa so seja sorteada quando terminar de sacudir.
A segunda closure e o update do coreMotion, ele vai pegar o delta que eu ja expliquei previamente e ver se pelo menos teve algum movimento (o motionFeedbackThreshold e menor que o do core motion por que ele ja dispara haptics mesmo com pouco movimento) e depois começa o haptics, e vai atualizando conforme o shake for sendo detectado com o novo valor gerado em normalized.
Outro ponto dessa closure, e que ela executa o updateShakeIntensity e isso atualiza o lastMotionDate, pois essa linha que usamos para definir se passamos o tempo do timer para cancelar o hapticEngine
Normalized pega delta / pelo threshold por que se delta for igual, da 1, que e nosso valor maximo dos parametros de um haptic
e caso o delta for maior que o threshold do coreMotion (pra detectar um shake de verdade) marcamos o shakeWasStrong como true.
E agora vem outro valor legal, que e o idle timer, um time automatico da view, que roda de tempo em tempo e verifica se nao teve nenhum update do coreMotion, e caso nao, ele para o engine de haptics.
O onDisappear so para o monitoramento, para o timer e para o loop de haptics.
