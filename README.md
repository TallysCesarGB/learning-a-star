# Caçador Estelar

Simulação 3D para macOS de um caça interceptador perseguindo uma nave mensageira pelo setor, de **A** até **B**. O objetivo é comparar, em tempo real, a **Busca Gulosa** e o **A\***.

Disciplina: Estrutura de Dados Não Lineares, prof. Aluisio Igor Rego Fontes.

## Como rodar

Requisitos: macOS 13 ou superior e Xcode 15 ou superior.

Pelo Xcode:

1. Abra o `Package.swift`.
2. Escolha o esquema **CacadorEstelar**.
3. Pressione ⌘R.

Pelo terminal, dentro da pasta do projeto:

```bash
swift run -c release
```

O modo release deixa a cena bem mais fluida.

## Os algoritmos

O setor é um **grafo implícito**:

- cada célula é um vértice;
- as arestas levam às 4 vizinhas, ou às 8 com diagonais;
- o peso da aresta é o custo do terreno de destino (vezes √2 na diagonal).

| Terreno | Custo |
|---|---|
| Rota hiperespacial | 1 |
| Vácuo | 2 |
| Nebulosa | 3 |
| Campo de detritos | 5 |
| Tempestade iônica | 8 |
| Asteroide | intransponível |

**Busca Gulosa, f(n) = h(n).** Olha só para a distância estimada até o alvo. É rápida e explora poucos nós. Porém, ignora o custo já pago e costuma atravessar tempestades e detritos.

**A\*, f(n) = g(n) + h(n).** Soma o custo acumulado à heurística. Se a heurística for admissível (nunca superestima), a rota encontrada é ótima.

As duas usam um heap binário mínimo como fila de prioridade. No A\* há relaxamento de arestas.

Como o custo mínimo é 1, Manhattan, Euclidiana, Octil e Chebyshev são admissíveis. A exceção é a Manhattan com diagonais, que superestima. O app avisa quando isso acontece, e dá para ver o A\* perder a garantia de ótimo.

## Métricas em tempo real

- Nós explorados.
- Tempo de convergência (ms).
- Custo planejado e custo percorrido.
- Saltos.
- Replanejamentos.
- Tamanho máximo da fronteira.
- Custo ótimo de referência.
- Eficiência, mostrada em um mostrador com estrelas.

O **Duelo** (⌘D) roda os dois algoritmos no mesmo setor. As explorações aparecem sobrepostas: vermelho para a Gulosa, azul para o A\*. Barras comparativas e um veredito fecham a análise.

## Controles

| Ação | Como fazer |
|---|---|
| Pintar terreno | Clique ou arraste no setor |
| Mover A ou B | Arraste o farol dourado (A) ou o verde (B) |
| Orbitar a câmera | Botão direito, ou ⌥ + arrastar |
| Zoom | Rolagem ou pinça no trackpad |
| Iniciar caçada | ⌘↩ |
| Duelo | ⌘D |
| Parar | Esc |
| Gerar setor | ⌘G |

Pintar durante a caçada é **sabotagem ao vivo**: o caçador precisa replanejar.

## Modos de jogo

- **Interceptação:** o alvo fica parado, e a rota é comparada com o custo ótimo.
- **Perseguição:** o mensageiro foge a cada 4 unidades de custo gastas pelo caçador. Rotas caras dão vantagem a ele.
- **Chuva de meteoros:** a cada 5 saltos caem asteroides, às vezes em cima da rota.

## Câmeras

- **Orbital:** visão livre, que pode girar e aproximar.
- **Tática:** vista de cima, como um mapa.
- **Cockpit:** câmera presa atrás do caça.

## Conquistas

Salto perfeito, Piloto sortudo, Sensor afiado, Casco chamuscado, Caçador de recompensas, Sobrevivente, Sabotador e Esquadrão. Passe o mouse sobre cada uma para ver a condição de desbloqueio.

## Estrutura

```
Sources/CacadorEstelar/
├── App.swift              janela, layout, barras superior e inferior
├── Modelo/
│   ├── Grade.swift        paleta, terrenos, grade (grafo implícito)
│   ├── Busca.swift        heap, heurísticas, Gulosa e A*
│   ├── Mapas.swift        geradores de setor
│   └── JogoModel.swift    estado, animação, modos, conquistas
├── Cena3D/
│   ├── Texturas.swift     texturas procedurais e asteroides low-poly
│   ├── Pecas.swift        naves, faróis, partículas, geometrias compartilhadas
│   ├── Renderizador.swift sincroniza a cena com o modelo (diff por célula)
│   └── VisaoEspacial.swift SCNView com mouse, ponte para SwiftUI
└── HUD/
    ├── Componentes.swift  vidro holográfico, botões, medidores
    ├── PainelComando.swift
    └── PainelTelemetria.swift
```

Todos os gráficos são gerados por código: não há arquivos de imagem ou modelos 3D externos.
