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

