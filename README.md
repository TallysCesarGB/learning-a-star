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
- ZEM e t_go, no modo Perseguição com navegação proporcional.

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
- **Perseguição:** o mensageiro foge a cada 4 unidades de custo gastas pelo caçador. Rotas caras dão vantagem a ele. Neste modo, você escolhe a guiagem do caçador (veja abaixo).
- **Chuva de meteoros:** a cada 5 saltos caem asteroides, às vezes em cima da rota.

## Guiagem no modo Perseguição

A Gulosa e o A\* resolvem **planejamento**: qual é a rota mais barata até um ponto. No modo Perseguição, o ponto se move. Então surge uma segunda pergunta, de **guiagem**: para onde mirar e quando vale recalcular a rota?

O app oferece três guiagens:

| Guiagem | Para onde mira | Quando replaneja |
|---|---|---|
| **Pura** | Posição atual do mensageiro | Toda vez que ele se move |
| **PN · ZEM** | Posição atual do mensageiro | Quando o comando N·ZEM/t_go² passa do limiar |
| **PN + antecipação** | Ponto de interceptação previsto | Quando o comando N·ZEM/t_go² passa do limiar |

A ideia da navegação proporcional (PN) vem da guiagem de mísseis:

- **ZEM (Zero-Effort Miss):** a distância, em células, entre onde o mensageiro vai estar quando a rota terminar e onde a rota termina. É o erro que vai acontecer se ninguém mudar de rumo.
- **t_go:** o custo que falta percorrer na rota atual, usado como "tempo até o encontro".
- **Comando:** a = N · ZEM / t_go², com N = 3. Um ZEM grande longe do alvo é tolerado; um ZEM pequeno perto do alvo já pede correção.
- **Retroalimentação:** a cada salto, o caçador mede a posição do mensageiro e atualiza a velocidade estimada com um filtro passa-baixa (constante de tempo τ = 12). Depois recalcula o ZEM. É uma malha fechada.

Na grade, "corrigir o rumo" significa rodar uma nova busca. Por isso a PN aqui decide **quando** vale pagar por uma busca, em vez de comandar uma aceleração contínua.

Durante a caçada, o ponto previsto aparece como uma mira magenta. A linha magenta entre o fim da rota e a mira é o próprio ZEM. A telemetria mostra o ZEM e o t_go ao vivo.

### Comparativo

O botão **Comparar guiagens** roda 30 perseguições por guiagem no setor atual, sem animação, com as mesmas sementes de fuga para as três. O resultado aparece em barras na telemetria.

O script `benchmark/guiagem.py` é uma porta da mesma lógica para Python e roda o comparativo em muitos setores de uma vez:

```bash
python3 benchmark/guiagem.py --por-tipo
```

Resultado com A\*, heurística Manhattan e 4 direções, em 159 setores de 29×43 (40 de cada tipo). As médias consideram só as capturas:

| Métrica | Pura | PN · ZEM | PN + antecipação |
|---|---:|---:|---:|
| Taxa de captura | 100% | 100% | 100% |
| Custo percorrido | 111,5 | 111,1 (−0%) | 118,0 (+6%) |
| Saltos | 67,7 | 67,5 (−0%) | 71,3 (+5%) |
| Replanejamentos | 26,2 | 4,6 (−83%) | 3,9 (−85%) |
| Nós explorados (total) | 6.409 | 633 (−90%) | 691 (−89%) |
| Tempo de busca (relativo à pura) | 100% | 10% | 11% |

Com outras configurações:

| Configuração | Replanejamentos (PN · ZEM) | Nós explorados (PN · ZEM) | Custo (PN · ZEM) | Custo (PN + antecipação) |
|---|---:|---:|---:|---:|
| A\*, octil, 8 direções | −82% | −89% | +3% | +10% |
| Gulosa, Manhattan, 4 direções | −89% | −94% | −22% | −11% |

O que os números mostram:

1. **A retroalimentação pelo ZEM é o ganho principal.** O caçador para de replanejar a cada movimento do mensageiro e só corrige quando o erro previsto importa. Com isso, faz cerca de 85% menos buscas e explora cerca de 90% menos nós, sem piorar o custo da rota.
2. **Na Gulosa, a PN também reduz o custo** (−22%). Replanejar o tempo todo faz a Gulosa trocar de rota gananciosa a cada salto e andar em zigue-zague. Menos replanejamento significa uma trajetória mais estável.
3. **A antecipação não compensa nesta grade.** Mirar no ponto previsto aumenta o custo de 6% a 10% com o A\*. Há três motivos:
   - a PN supõe um alvo que não manobra, mas o mensageiro reage ao caçador e muda de direção para fugir;
   - o mensageiro é lento (uma célula a cada 4 de custo), então a vantagem de antecipar é pequena;
   - em 4 direções, existem muitas rotas de mesmo custo, e a perseguição pura já consegue se ajustar quase sem perda.

Por isso a guiagem padrão é **PN · ZEM**.

Os números do script vêm de setores gerados pelo gerador de números aleatórios do Python. Rodando o comparativo dentro do app, os valores mudam um pouco de setor para setor, mas a tendência se mantém.

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
│   ├── Guiagem.swift      navegação proporcional, ZEM, fuga, simulador do comparativo
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

benchmark/
└── guiagem.py             comparativo das guiagens em muitos setores (Python 3)
```

Todos os gráficos são gerados por código: não há arquivos de imagem ou modelos 3D externos.