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
