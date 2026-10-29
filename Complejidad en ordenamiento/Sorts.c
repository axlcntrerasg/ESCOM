/*
 * sorts.c — Bubble sort, Mergesort, Tree sort, Heapsort y Counting sort
 * sobre arreglos de números reales (double).
 *
 * Uso:  ./sorts <algoritmo> <n> [semilla]
 *       algoritmo ∈ {bubble, merge, tree, heap, counting}
 *
 * Imprime una línea CSV:
 *   lenguaje,algoritmo,n,segundos,pico_memoria_kb,ordenado
 *
 * El tiempo mide únicamente el ordenamiento (no la generación de datos).
 * La memoria es el pico de memoria residente (VmHWM / ru_maxrss) del proceso.
 */
#define _POSIX_C_SOURCE 199309L
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <time.h>

/* ---------------------------------------------------------------------- */
/*  Generación de datos (idéntica en C y Go)                               */
/* ---------------------------------------------------------------------- */

/* Los datos son reales en [0, 100000) con 2 decimales: x = k / 100,
 * k entero uniforme en [0, 10^7). Esa precisión fija es lo que permite
 * aplicar Counting sort a números reales. */
#define KEY_RANGE 10000000ULL
#define SCALE 100.0

static uint64_t splitmix64(uint64_t *state) {
    uint64_t z = (*state += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

static void generate(double *a, size_t n, uint64_t seed) {
    uint64_t s = seed;
    for (size_t i = 0; i < n; i++)
        a[i] = (double)(splitmix64(&s) % KEY_RANGE) / SCALE;
}

/* ---------------------------------------------------------------------- */
/*  1. Bubble sort — O(n²) tiempo, O(1) memoria extra                      */
/* ---------------------------------------------------------------------- */
static void bubble_sort(double *a, size_t n) {
    if (n < 2) return;
    size_t last = n - 1;
    while (last > 0) {
        size_t new_last = 0;            /* posición del último intercambio */
        for (size_t i = 0; i < last; i++) {
            if (a[i] > a[i + 1]) {
                double t = a[i]; a[i] = a[i + 1]; a[i + 1] = t;
                new_last = i;
            }
        }
        last = new_last;                /* lo posterior ya está ordenado  */
    }
}

/* ---------------------------------------------------------------------- */
/*  2. Mergesort — O(n log n) tiempo, O(n) memoria extra                   */
/* ---------------------------------------------------------------------- */
static void merge_rec(double *a, double *buf, size_t lo, size_t hi) {
    if (hi - lo < 2) return;
    size_t mid = lo + (hi - lo) / 2;
    merge_rec(a, buf, lo, mid);
    merge_rec(a, buf, mid, hi);
    if (a[mid - 1] <= a[mid]) return;   /* mitades ya en orden */
    memcpy(buf + lo, a + lo, (hi - lo) * sizeof(double));
    size_t i = lo, j = mid, k = lo;
    while (i < mid && j < hi) a[k++] = (buf[j] < buf[i]) ? buf[j++] : buf[i++];
    while (i < mid) a[k++] = buf[i++];
    while (j < hi)  a[k++] = buf[j++];
}

static void merge_sort(double *a, size_t n) {
    double *buf = malloc(n * sizeof(double));
    if (!buf) { perror("malloc"); exit(1); }
    merge_rec(a, buf, 0, n);
    free(buf);
}

/* ---------------------------------------------------------------------- */
/*  3. Tree sort — árbol binario de búsqueda (no balanceado)               */
/*     O(n log n) esperado con datos aleatorios, O(n) memoria extra.       */
/*     Los nodos viven en un arreglo (índices de 32 bits en lugar de       */
/*     punteros) para que el consumo de memoria sea comparable entre       */
/*     lenguajes: 16 bytes por nodo.                                       */
/* ---------------------------------------------------------------------- */
typedef struct { double key; uint32_t left, right; } Node;
#define NIL UINT32_MAX

static void tree_sort(double *a, size_t n) {
    if (n < 2) return;
    Node *t = malloc(n * sizeof(Node));
    if (!t) { perror("malloc"); exit(1); }
    t[0] = (Node){a[0], NIL, NIL};
    for (uint32_t i = 1; i < n; i++) {           /* inserción iterativa */
        double x = a[i];
        t[i] = (Node){x, NIL, NIL};
        uint32_t cur = 0;
        for (;;) {
            if (x < t[cur].key) {                 /* repetidos van a la derecha */
                if (t[cur].left == NIL) { t[cur].left = i; break; }
                cur = t[cur].left;
            } else {
                if (t[cur].right == NIL) { t[cur].right = i; break; }
                cur = t[cur].right;
            }
        }
    }
    /* Recorrido in-orden iterativo con pila explícita */
    size_t cap = 1024, sp = 0, k = 0;
    uint32_t *stack = malloc(cap * sizeof(uint32_t));
    uint32_t cur = 0;
    while (cur != NIL || sp > 0) {
        while (cur != NIL) {
            if (sp == cap) { cap *= 2; stack = realloc(stack, cap * sizeof(uint32_t)); }
            stack[sp++] = cur;
            cur = t[cur].left;
        }
        cur = stack[--sp];
        a[k++] = t[cur].key;
        cur = t[cur].right;
    }
    free(stack);
    free(t);
}

/* ---------------------------------------------------------------------- */
/*  4. Heapsort — O(n log n) tiempo, O(1) memoria extra                    */
/* ---------------------------------------------------------------------- */
static void sift_down(double *a, size_t start, size_t end) {
    size_t root = start;
    double x = a[root];
    for (;;) {
        size_t child = 2 * root + 1;
        if (child >= end) break;
        if (child + 1 < end && a[child] < a[child + 1]) child++;
        if (a[child] <= x) break;
        a[root] = a[child];
        root = child;
    }
    a[root] = x;
}

static void heap_sort(double *a, size_t n) {
    if (n < 2) return;
    for (size_t i = n / 2; i-- > 0;) sift_down(a, i, n);   /* construir heap */
    for (size_t end = n - 1; end > 0; end--) {
        double t = a[0]; a[0] = a[end]; a[end] = t;
        sift_down(a, 0, end);
    }
}

/* ---------------------------------------------------------------------- */
/*  5. Counting sort — O(n + k) tiempo, O(k) memoria extra                 */
/*     Cada real se convierte a su clave entera k = round(x·100).          */
/*     k = (máx − mín + 1) es el número de claves posibles.                */
/* ---------------------------------------------------------------------- */
static void counting_sort(double *a, size_t n) {
    if (n < 2) return;
    int64_t mn = llround(a[0] * SCALE), mx = mn;
    for (size_t i = 1; i < n; i++) {
        int64_t v = llround(a[i] * SCALE);
        if (v < mn) mn = v;
        if (v > mx) mx = v;
    }
    size_t k = (size_t)(mx - mn + 1);
    uint32_t *count = calloc(k, sizeof(uint32_t));
    if (!count) { perror("calloc"); exit(1); }
    for (size_t i = 0; i < n; i++) count[llround(a[i] * SCALE) - mn]++;
    size_t pos = 0;
    for (size_t v = 0; v < k; v++) {
        double x = (double)((int64_t)v + mn) / SCALE;
        for (uint32_t c = count[v]; c > 0; c--) a[pos++] = x;
    }
    free(count);
}

/* Sin ordenar: sirve para medir la memoria base (solo el arreglo). */
static void no_sort(double *a, size_t n) { (void)a; (void)n; }

/* ---------------------------------------------------------------------- */
static long peak_rss_kb(void) {
    FILE *f = fopen("/proc/self/status", "r");
    if (f) {
        char line[256];
        while (fgets(line, sizeof line, f))
            if (strncmp(line, "VmHWM:", 6) == 0) { fclose(f); return atol(line + 6); }
        fclose(f);
    }
    struct rusage ru; getrusage(RUSAGE_SELF, &ru);
    return ru.ru_maxrss;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "uso: %s <bubble|merge|tree|heap|counting> <n> [semilla]\n", argv[0]);
        return 1;
    }
    const char *alg = argv[1];
    size_t n = strtoull(argv[2], NULL, 10);
    uint64_t seed = argc > 3 ? strtoull(argv[3], NULL, 10) : 42;

    void (*sort)(double *, size_t) = NULL;
    if      (!strcmp(alg, "none"))     sort = no_sort;   /* línea base de memoria */
    else if (!strcmp(alg, "bubble"))   sort = bubble_sort;
    else if (!strcmp(alg, "merge"))    sort = merge_sort;
    else if (!strcmp(alg, "tree"))     sort = tree_sort;
    else if (!strcmp(alg, "heap"))     sort = heap_sort;
    else if (!strcmp(alg, "counting")) sort = counting_sort;
    else { fprintf(stderr, "algoritmo desconocido: %s\n", alg); return 1; }

    double *a = malloc(n * sizeof(double));
    if (!a) { perror("malloc"); return 1; }
    generate(a, n, seed);
    uint64_t sum_before = 0;             /* suma de claves: verifica que no se pierdan datos */
    for (size_t i = 0; i < n; i++) sum_before += (uint64_t)llround(a[i] * SCALE);

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    sort(a, n);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double secs = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;

    int ok = 1;
    if (sort == no_sort) {
        printf("C,none,%zu,0,%ld,n/a\n", n, peak_rss_kb());
        return 0;
    }
    for (size_t i = 1; i < n; i++) if (a[i - 1] > a[i]) { ok = 0; break; }
    uint64_t sum_after = 0;
    for (size_t i = 0; i < n; i++) sum_after += (uint64_t)llround(a[i] * SCALE);
    if (sum_after != sum_before) ok = 0;

    printf("C,%s,%zu,%.6f,%ld,%s\n", alg, n, secs, peak_rss_kb(), ok ? "si" : "NO");
    free(a);
    return ok ? 0 : 2;
}
