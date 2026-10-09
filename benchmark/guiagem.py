#!/usr/bin/env python3
"""
Benchmark: Perseguição pura × Navegação proporcional por ZEM

Porta fiel, em Python, da lógica do Caçador Estelar usada no modo Perseguição:
grade e vizinhos (Grade.swift), Gulosa/A* (Busca.swift), geradores de setor
(Mapas.swift), fuga do mensageiro (JogoModel.swift) e a guiagem (Guiagem.swift).

Roda as três guiagens no MESMO setor, com a MESMA semente para o mensageiro,
e imprime a média das métricas.

Uso:
    python3 benchmark/guiagem.py                 # 40 setores por tipo
    python3 benchmark/guiagem.py --setores 80 --por-tipo
    python3 benchmark/guiagem.py --algoritmo gulosa --diagonal
"""
import argparse
import heapq
import math
import random
import statistics
import time

SQRT2 = math.sqrt(2)
INF = math.inf

# Terrenos: rota, vácuo, nebulosa, detritos, tempestade, asteroide
ROTA, VACUO, NEBULOSA, DETRITOS, TEMPESTADE, ASTEROIDE = range(6)
CUSTO = [1, 2, 3, 5, 8, INF]

# Constantes da guiagem (idênticas às de Guiagem.swift)
GANHO_N = 3.0            # ganho de navegação N
LIMIAR = 0.1             # comando a partir do qual vale replanejar
TAU = 12.0               # constante de tempo do filtro de velocidade
LIMITE_PASSOS = 1500
CUSTO_FUGA = 4.0         # o mensageiro anda 1 célula a cada 4 de custo do caçador


# ---------------------------------------------------------------- Grade
class Grade:
    def __init__(self, linhas, colunas, preench=VACUO):
        self.linhas, self.colunas = linhas, colunas
        self.c = [preench] * (linhas * colunas)

    def contem(self, p):
        return 0 <= p[0] < self.linhas and 0 <= p[1] < self.colunas

    def __getitem__(self, p):
        return self.c[p[0] * self.colunas + p[1]]

    def __setitem__(self, p, v):
        self.c[p[0] * self.colunas + p[1]] = v

    def passavel(self, p):
        return self[p] != ASTEROIDE

    def vizinhos(self, p, diagonal):
        r, c = p
        out = []
        for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            n = (r + dr, c + dc)
            if self.contem(n) and self.passavel(n):
                out.append((n, CUSTO[self[n]]))
        if diagonal:
            for dr, dc in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
                n = (r + dr, c + dc)
                if not (self.contem(n) and self.passavel(n)):
                    continue
                if self.passavel((r + dr, c)) and self.passavel((r, c + dc)):
                    out.append((n, CUSTO[self[n]] * SQRT2))
        return out

    def custo_passo(self, a, b):
        diag = a[0] != b[0] and a[1] != b[1]
        return CUSTO[self[b]] * (SQRT2 if diag else 1)


# ---------------------------------------------------------------- Busca
def heuristica(nome, a, b):
    dr, dc = abs(a[0] - b[0]), abs(a[1] - b[1])
    if nome == "manhattan":
        return dr + dc
    if nome == "euclidiana":
        return math.hypot(dr, dc)
    if nome == "octil":
        return max(dr, dc) + (SQRT2 - 1) * min(dr, dc)
    return max(dr, dc)


def buscar(g, inicio, alvo, algoritmo, heur, diagonal):
    """Retorna (encontrou, caminho, custo, nos_explorados)."""
    gcost = {inicio: 0.0}
    pai = {}
    fechados = set()
    aberta = []
    cont = 0  # desempate estável (o heap do Swift não é estável; não muda médias)
    if g.contem(inicio) and g.contem(alvo) and g.passavel(alvo):
        h0 = heuristica(heur, inicio, alvo)
        heapq.heappush(aberta, (h0, h0, cont, 0.0, inicio))
    nos = 0
    encontrou = False
    while aberta:
        f, h, _, gn, p = heapq.heappop(aberta)
        if p in fechados:
            continue
        if algoritmo == "astar" and gn > gcost.get(p, INF):
            continue
        fechados.add(p)
        nos += 1
        if p == alvo:
            encontrou = True
            break
        for v, w in g.vizinhos(p, diagonal):
            if v in fechados:
                continue
            ng = gn + w
            if algoritmo == "astar":
                if ng < gcost.get(v, INF):
                    gcost[v] = ng
                    pai[v] = p
                    hv = heuristica(heur, v, alvo)
                    cont += 1
                    heapq.heappush(aberta, (ng + hv, hv, cont, ng, v))
            else:
                if v not in gcost:
                    gcost[v] = ng
                    pai[v] = p
                    hv = heuristica(heur, v, alvo)
                    cont += 1
                    heapq.heappush(aberta, (hv, hv, cont, ng, v))
    caminho = []
    if encontrou:
        a = alvo
        caminho.append(a)
        while a in pai:
            a = pai[a]
            caminho.append(a)
        caminho.reverse()
    return encontrou, caminho, (gcost[alvo] if encontrou else INF), nos


# ---------------------------------------------------------------- Mapas
def mapa_aleatorio(L, C, dens, rng):
    g = Grade(L, C)
    for r in range(L):
        for c in range(C):
            x = rng.random()
            if x < dens:
                g[(r, c)] = ASTEROIDE
            elif x < dens + 0.07:
                g[(r, c)] = DETRITOS
            elif x < dens + 0.14:
                g[(r, c)] = NEBULOSA
            elif x < dens + 0.30:
                g[(r, c)] = ROTA
    return g


def mapa_labirinto(L, C, rng):
    g = Grade(L, C, ASTEROIDE)
    origem = (1, 1)
    vis = {origem}
    pilha = [origem]
    g[origem] = ROTA
    while pilha:
        r, c = pilha[-1]
        dirs = [(0, 2), (0, -2), (2, 0), (-2, 0)]
        rng.shuffle(dirs)
        avancou = False
        for dr, dc in dirs:
            n = (r + dr, c + dc)
            if 0 < n[0] < L - 1 and 0 < n[1] < C - 1 and n not in vis:
                g[(r + dr // 2, c + dc // 2)] = ROTA
                g[n] = ROTA
                vis.add(n)
                pilha.append(n)
                avancou = True
                break
        if not avancou:
            pilha.pop()
    for r in range(1, L - 1):
        for c in range(1, C - 1):
            x = rng.random()
            if g[(r, c)] == ASTEROIDE and x < 0.10:
                g[(r, c)] = rng.choice([DETRITOS, TEMPESTADE, VACUO])
            elif g[(r, c)] == ROTA and x < 0.18:
                g[(r, c)] = rng.choice([VACUO, NEBULOSA])
    return g


def ruido(L, C, esc, rng):
    gl, gc = L // esc + 2, C // esc + 2
    malha = [rng.random() for _ in range(gl * gc)]
    suave = lambda t: t * t * (3 - 2 * t)
    out = [0.0] * (L * C)
    for r in range(L):
        for c in range(C):
            fr, fc = r / esc, c / esc
            r0, c0 = int(fr), int(fc)
            tr, tc = suave(fr - r0), suave(fc - c0)
            a, b = malha[r0 * gc + c0], malha[r0 * gc + c0 + 1]
            d, e = malha[(r0 + 1) * gc + c0], malha[(r0 + 1) * gc + c0 + 1]
            topo, baixo = a + (b - a) * tc, d + (e - d) * tc
            out[r * C + c] = topo + (baixo - topo) * tr
    return out


def mapa_natureza(L, C, dens, rng):
    g = Grade(L, C)
    base, det = ruido(L, C, 9, rng), ruido(L, C, 3, rng)
    lim = 0.84 - dens * 0.45
    for r in range(L):
        for c in range(C):
            v = 0.7 * base[r * C + c] + 0.3 * det[r * C + c]
            if v < 0.27: t = TEMPESTADE
            elif v < 0.35: t = DETRITOS
            elif v < 0.56: t = VACUO
            elif v < lim: t = NEBULOSA
            else: t = ASTEROIDE
            g[(r, c)] = t
    r = rng.randint(L // 4, 3 * L // 4)
    for c in range(C):
        g[(r, c)] = ROTA
        if rng.randrange(4) == 0:
            r = min(L - 2, max(1, r + rng.randint(-1, 1)))
            g[(r, c)] = ROTA
    c = rng.randint(C // 4, 3 * C // 4)
    for rr in range(L):
        g[(rr, c)] = ROTA
        if rng.randrange(4) == 0:
            c = min(C - 2, max(1, c + rng.randint(-1, 1)))
            g[(rr, c)] = ROTA
    return g


def montar_mundo(tipo, L, C, dens, rng):
    if tipo == "vazio":
        g = Grade(L, C)
    elif tipo == "aleatorio":
        g = mapa_aleatorio(L, C, dens, rng)
    elif tipo == "labirinto":
        g = mapa_labirinto(L, C, rng)
    else:
        g = mapa_natureza(L, C, dens, rng)
    i, a = (L // 2, 1), (L // 2, C - 2)
    for p in (i, a):
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                q = (p[0] + dr, p[1] + dc)
                if g.contem(q) and not g.passavel(q):
                    g[q] = VACUO
        g[p] = ROTA
    return g, i, a


# ---------------------------------------------------------------- Fuga do mensageiro
def mover_presa(g, presa, predador, rng):
    opcoes = [p for p, _ in g.vizinhos(presa, False)]
    if not opcoes:
        return presa
    dist = lambda p: abs(p[0] - predador[0]) + abs(p[1] - predador[1])
    if rng.random() < 0.75:
        melhor = opcoes[0]
        for o in opcoes[1:]:
            dm, do = dist(melhor), dist(o)
            menor = CUSTO[g[melhor]] > CUSTO[g[o]] if dm == do else dm < do
            if menor:
                melhor = o
        return melhor
    return rng.choice(opcoes)


# ---------------------------------------------------------------- Guiagem
class Estimador:
    """Observador de velocidade: filtro passa-baixa de 1ª ordem (malha fechada)."""

    def __init__(self, presa):
        self.vr = self.vc = 0.0
        self.ultima = presa
        self.t = 0.0

    def observar(self, presa, tempo):
        dt = tempo - self.t
        if dt <= 0:
            return
        mr = (presa[0] - self.ultima[0]) / dt
        mc = (presa[1] - self.ultima[1]) / dt
        alfa = 1 - math.exp(-dt / TAU)
        self.vr += alfa * (mr - self.vr)
        self.vc += alfa * (mc - self.vc)
        self.ultima, self.t = presa, tempo


def prever(g, presa, est, tgo):
    r = min(max(presa[0] + est.vr * tgo, 0), g.linhas - 1)
    c = min(max(presa[1] + est.vc * tgo, 0), g.colunas - 1)
    return r, c


def celula_livre(g, ponto, reserva):
    r0, c0 = round(ponto[0]), round(ponto[1])  # meio a par, igual ao .toNearestOrEven do Swift
    for raio in range(4):
        melhor, md = None, INF
        for dr in range(-raio, raio + 1):
            for dc in range(-raio, raio + 1):
                if max(abs(dr), abs(dc)) != raio:
                    continue
                q = (r0 + dr, c0 + dc)
                if g.contem(q) and g.passavel(q):
                    d = math.hypot(q[0] - ponto[0], q[1] - ponto[1])
                    if d < md:
                        melhor, md = q, d
        if melhor:
            return melhor
    return reserva


def distancia_grade(a, b, diagonal):
    """Distância percorrida na grade: Manhattan (4 direções) ou octil (8)."""
    dr, dc = abs(a[0] - b[0]), abs(a[1] - b[1])
    return max(dr, dc) + (SQRT2 - 1) * min(dr, dc) if diagonal else dr + dc


def calcular_mira(g, predador, presa, est, custo_medio, diagonal):
    """Ponto de interceptação previsto (iteração de ponto fixo, 2 rodadas)."""
    dist = lambda a, b: distancia_grade(a, b, diagonal)
    tgo = dist(predador, presa) * custo_medio
    p = prever(g, presa, est, tgo)
    tgo = dist(predador, p) * custo_medio
    p = prever(g, presa, est, tgo)
    return celula_livre(g, p, presa), tgo


def zem_e_comando(g, presa, est, caminho, custo_restante):
    tgo = custo_restante
    prev = prever(g, presa, est, tgo)
    fim = caminho[-1]
    zem = math.hypot(prev[0] - fim[0], prev[1] - fim[1])
    comando = GANHO_N * zem / max(tgo, 1.0) ** 2   # a = N · ZEM / t_go²
    return zem, tgo, comando


# ---------------------------------------------------------------- Perseguição
def perseguir(g, inicio, alvo, algoritmo, heur, diagonal, guiagem, semente):
    """guiagem: "pura" | "zem" (PN, mira no alvo) | "antecipada" (PN, mira no ponto previsto)."""
    rng = random.Random(semente)
    predador, presa = inicio, alvo
    custo = 0.0
    passos = replans = nos = 0
    orc = 0.0
    est = Estimador(presa)
    ms = 0.0  # só o tempo das buscas, como no app
    primeira = True
    while True:
        destino = presa
        if guiagem == "antecipada" and not primeira:
            cm = custo / passos if passos else 2.0
            destino, _ = calcular_mira(g, predador, presa, est, cm, diagonal)
        t0 = time.perf_counter()
        ok, caminho, restante, n = buscar(g, predador, destino, algoritmo, heur, diagonal)
        nos += n
        if not ok and destino != presa:
            ok, caminho, restante, n = buscar(g, predador, presa, algoritmo, heur, diagonal)
            nos += n
        ms += (time.perf_counter() - t0) * 1000
        if not ok:
            return dict(capturou=False, custo=custo, passos=passos, replans=replans,
                        nos=nos, ms=ms)
        primeira = False
        fim = None
        while len(caminho) > 1:
            a, b = caminho[0], caminho[1]
            cp = g.custo_passo(a, b)
            caminho.pop(0)
            restante -= cp
            predador = b
            custo += cp
            passos += 1
            if predador == presa:
                fim = "capturou"; break
            if passos >= LIMITE_PASSOS:
                fim = "escapou"; break
            orc += cp
            moveu = False
            while orc >= CUSTO_FUGA:
                orc -= CUSTO_FUGA
                presa = mover_presa(g, presa, predador, rng)
                moveu = True
                if presa == predador:
                    fim = "capturou"; break
            if fim:
                break
            est.observar(presa, custo)
            if guiagem == "pura":
                if moveu:
                    fim = "replan"; break
            else:
                if len(caminho) > 1:
                    _, _, comando = zem_e_comando(g, presa, est, caminho, restante)
                    if comando > LIMIAR:
                        fim = "replan"; break
        if fim in ("capturou", "escapou"):
            return dict(capturou=fim == "capturou", custo=custo, passos=passos,
                        replans=replans, nos=nos, ms=ms)
        replans += 1


# ---------------------------------------------------------------- Execução
GUIAGENS = [("pura", "Perseguição pura"), ("zem", "PN por ZEM"),
            ("antecipada", "PN por ZEM + antecipação")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--setores", type=int, default=40, help="setores por tipo de mapa")
    ap.add_argument("--algoritmo", default="astar", choices=["astar", "gulosa"])
    ap.add_argument("--heuristica", default="manhattan",
                    choices=["manhattan", "euclidiana", "octil", "chebyshev"])
    ap.add_argument("--diagonal", action="store_true")
    ap.add_argument("--linhas", type=int, default=29)
    ap.add_argument("--colunas", type=int, default=43)
    ap.add_argument("--por-tipo", action="store_true", help="também imprime uma tabela por tipo de setor")
    args = ap.parse_args()

    tipos = [("natureza", "Nebulosa selvagem"), ("aleatorio", "Cinturão de asteroides"),
             ("labirinto", "Estação em ruínas"), ("vazio", "Setor limpo")]

    total = {k: [] for k, _ in GUIAGENS}
    for tipo, nome in tipos:
        res = {k: [] for k, _ in GUIAGENS}
        for s in range(args.setores):
            rng = random.Random(1000 + s)
            g, i, a = montar_mundo(tipo, args.linhas, args.colunas, 0.28, rng)
            if not buscar(g, i, a, "astar", "manhattan", False)[0]:
                continue
            for gui, _ in GUIAGENS:
                r = perseguir(g, i, a, args.algoritmo, args.heuristica, args.diagonal, gui, 7 + s)
                res[gui].append(r)
                total[gui].append(r)
        if args.por_tipo:
            imprimir(nome, res)
    config = f"{'A*' if args.algoritmo == 'astar' else 'Gulosa'}, {args.heuristica}, " \
             f"{'8' if args.diagonal else '4'} direções, grade {args.linhas}×{args.colunas}"
    imprimir(f"Todos os setores ({config})", total)


def imprimir(nome, res):
    n = len(res["pura"])
    print(f"\n### {nome}: {n} setores")
    print("| Métrica | " + " | ".join(r for _, r in GUIAGENS) + " |")
    print("|---|" + "---:|" * len(GUIAGENS))

    def taxa(k):
        return 100 * sum(r["capturou"] for r in res[k]) / n

    print("| Taxa de captura | " + " | ".join(f"{taxa(k):.0f}%" for k, _ in GUIAGENS) + " |")
    base = {}
    for chave, rotulo in [("custo", "Custo percorrido"), ("passos", "Saltos"),
                          ("replans", "Replanejamentos"), ("nos", "Nós explorados (total)"),
                          ("ms", "Tempo de busca (ms)")]:
        cel = []
        for k, _ in GUIAGENS:
            # médias só sobre as capturas, para comparar coisas comparáveis
            v = statistics.mean([r[chave] for r in res[k] if r["capturou"]] or [0])
            if k == "pura":
                base[chave] = v
                cel.append(f"{v:.1f}")
            else:
                var = (v - base[chave]) / base[chave] * 100 if base[chave] else 0
                cel.append(f"{v:.1f} ({var:+.0f}%)")
        print(f"| {rotulo} | " + " | ".join(cel) + " |")


if __name__ == "__main__":
    main()