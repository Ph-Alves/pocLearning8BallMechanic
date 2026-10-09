# pocLearning8BallMechanic

POC para validar uma mecânica de sorteio de atividades inspirada na 8 Ball, com múltiplos temas visuais e formas de interação.

## Objetivo

Explorar e validar os seguintes aspectos técnicos antes de integrar ao app principal:

- Implementação da mecânica de sorteio via 8 Ball com adaptação visual por tema
- Interação por toque e por acelerômetro (shake)
- Animação de revelação com efeito de zoom
- Feedback háptico sincronizado com a interação

## Escopo

- **4 variantes visuais** da 8 Ball, uma para cada tema do app
- **Sorteio por sacudida** — leitura do acelerômetro para detectar o gesto de shake
- **Sorteio por toque** — interação direta com a bola na tela
- **Revelação animada** — atividade sorteada exibida dentro da 8 Ball com zoom
- **Hápticos** — resposta tátil reforçando a sensação de interação física

## Critério de aceite

POC funcional em que o usuário consiga:

1. Interagir com a 8 Ball via toque ou movimento do celular
2. Receber uma atividade sorteada exibida dentro da bola
3. Ver a animação de zoom na revelação
4. Sentir o feedback háptico
5. Ter toda a experiência adaptada ao tema selecionado

## Stack

- SwiftUI
- CoreMotion (shake / acelerômetro)
- UIFeedbackGenerator (hápticos)
- Xcode Playgrounds (protótipo rápido)

## Estrutura

```
Learning8Ball/
└── Learning8Ball/
    ├── MyApp.swift
    ├── ContentView.swift
    └── Assets.xcassets/
```
