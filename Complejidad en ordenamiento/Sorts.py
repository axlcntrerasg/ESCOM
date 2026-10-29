#!/usr/bin/env python3
"""
sorts.py — Bubble sort, Mergesort, Tree sort, Heapsort y Counting sort
sobre arreglos de números reales (float de Python = double de 64 bits).

Uso:  python3 sorts.py <algoritmo> <n> [semilla]
      algoritmo ∈ {bubble, merge, tree, heap, counting, none}

Imprime una línea CSV:
  lenguaje,algoritmo,n,segundos,pico_memoria_kb,ordenado

El tiempo mide únicamente el ordenamiento (no la generación de datos).
La memoria es el pico de memoria residente (VmHWM) del proceso.
Todo está escrito en Python puro: no se usa sorted(), list.sort() ni NumPy.
"""
import operator
import sys
import time
from array import array
from itertools import islice

# ---------------------------------------------------------------------------
# Generación de datos (idéntica a la versión en C)
# Reales en [0, 100000) con 2 decimales: x = k/100, k uniforme en [0, 10^7).
# ---------------------------------------------------------------------------
KEY_RANGE = 10_000_000
SCALE = 100.0
MASK = (1 << 64) - 1


def generate(n, seed):
    a = [0.0] * n
    s = seed
    for i in range(n):
        s = (s + 0x9E3779B97F4A7C15) & MASK          # SplitMix64
        z = s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        z ^= z >> 31
        a[i] = (z % KEY_RANGE) / SCALE
    return a


# ---------------------------------------------------------------------------
# 1. Bubble sort — O(n²) tiempo, O(1) memoria extra
# ---------------------------------------------------------------------------
def bubble_sort(a):
    last = len(a) - 1
    while last > 0:
        new_last = 0                     # posición del último intercambio
        for i in range(last):
            if a[i] > a[i + 1]:
                a[i], a[i + 1] = a[i + 1], a[i]
                new_last = i
        last = new_last                  # lo posterior ya está ordenado


# ---------------------------------------------------------------------------
# 2. Mergesort — O(n log n) tiempo, O(n) memoria extra
# ---------------------------------------------------------------------------
def _merge_rec(a, buf, lo, hi):
    if hi - lo < 2:
        return
    mid = (lo + hi) // 2
    _merge_rec(a, buf, lo, mid)
    _merge_rec(a, buf, mid, hi)
    if a[mid - 1] <= a[mid]:             # mitades ya en orden
        return
    for i in range(lo, hi):              # copia sin crear una lista temporal
        buf[i] = a[i]                    # (buf[lo:hi] = a[lo:hi] duplicaría la memoria)
    i, j, k = lo, mid, lo
    while i < mid and j < hi:
        if buf[j] < buf[i]:
            a[k] = buf[j]
            j += 1
        else:
            a[k] = buf[i]
            i += 1
        k += 1
    while i < mid:
        a[k] = buf[i]
        i += 1
        k += 1
    while j < hi:
        a[k] = buf[j]
        j += 1
        k += 1


def merge_sort(a):
    buf = [0.0] * len(a)                 # un solo búfer auxiliar de n elementos
    _merge_rec(a, buf, 0, len(a))


# ---------------------------------------------------------------------------
# 3. Tree sort — ABB no balanceado. Los nodos viven en arreglos paralelos:
#    key[i] (copia de las claves) y left[i]/right[i] (índices de 32 bits,
#    -1 = sin hijo), igual que en la versión en C.
# ---------------------------------------------------------------------------
def tree_sort(a):
    n = len(a)
    if n < 2:
        return
    key = a[:]
    left = array("i", [-1]) * n
    right = array("i", [-1]) * n
    for i in range(1, n):                # inserción iterativa
        x = key[i]
        cur = 0
        while True:
            if x < key[cur]:             # repetidos van a la derecha
                nxt = left[cur]
                if nxt == -1:
                    left[cur] = i
                    break
            else:
                nxt = right[cur]
                if nxt == -1:
                    right[cur] = i
                    break
            cur = nxt
    # Recorrido in-orden iterativo con pila explícita
    stack = []
    k = 0
    cur = 0
    while cur != -1 or stack:
        while cur != -1:
            stack.append(cur)
            cur = left[cur]
        cur = stack.pop()
        a[k] = key[cur]
        k += 1
        cur = right[cur]


# ---------------------------------------------------------------------------
# 4. Heapsort — O(n log n) tiempo, O(1) memoria extra
# ---------------------------------------------------------------------------
def _sift_down(a, root, end):
    x = a[root]
    while True:
        child = 2 * root + 1
        if child >= end:
            break
        if child + 1 < end and a[child] < a[child + 1]:
            child += 1
        if a[child] <= x:
            break
        a[root] = a[child]
        root = child
    a[root] = x


def heap_sort(a):
    n = len(a)
    for i in range(n // 2 - 1, -1, -1):  # construir el heap
        _sift_down(a, i, n)
    for end in range(n - 1, 0, -1):
        a[0], a[end] = a[end], a[0]
        _sift_down(a, 0, end)


# ---------------------------------------------------------------------------
# 5. Counting sort — O(n + k) tiempo, O(k) memoria extra
#    Cada real se convierte a su clave entera round(x·100).
# ---------------------------------------------------------------------------
def counting_sort(a):
    n = len(a)
    if n < 2:
        return
    mn = mx = round(a[0] * SCALE)
    for x in a:
        v = round(x * SCALE)
        if v < mn:
            mn = v
        elif v > mx:
            mx = v
    count = [0] * (mx - mn + 1)
    for x in a:
        count[round(x * SCALE) - mn] += 1
    pos = 0
    for v, c in enumerate(count):
        if c:
            x = (v + mn) / SCALE
            for _ in range(c):
                a[pos] = x
                pos += 1


# ---------------------------------------------------------------------------
def peak_rss_kb():
    with open("/proc/self/status") as f:
        for line in f:
            if line.startswith("VmHWM:"):
                return int(line.split()[1])
    return -1


def key_sum(a):
    return sum(round(x * SCALE) for x in a)


SORTS = {"bubble": bubble_sort, "merge": merge_sort, "tree": tree_sort,
         "heap": heap_sort, "counting": counting_sort}


def main():
    if len(sys.argv) < 3:
        sys.exit("uso: sorts.py <bubble|merge|tree|heap|counting|none> <n> [semilla]")
    alg, n = sys.argv[1], int(sys.argv[2])
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 42
    if alg != "none" and alg not in SORTS:
        sys.exit(f"algoritmo desconocido: {alg}")

    a = generate(n, seed)
    if alg == "none":                    # línea base de memoria (solo el arreglo)
        print(f"Python,none,{n},0,{peak_rss_kb()},n/a")
        return

    before = key_sum(a)                  # verifica que no se pierdan datos
    t0 = time.perf_counter()
    SORTS[alg](a)
    secs = time.perf_counter() - t0
    peak = peak_rss_kb()

    ok = all(map(operator.le, a, islice(a, 1, None))) and key_sum(a) == before
    print(f"Python,{alg},{n},{secs:.6f},{peak},{'si' if ok else 'NO'}")
    sys.exit(0 if ok else 2)


if __name__ == "__main__":
    main()
