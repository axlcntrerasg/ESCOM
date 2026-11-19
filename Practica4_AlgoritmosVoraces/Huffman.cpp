#include <fstream>
#include <iostream>
#include <queue>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

using CodigoHuffmanMap = std::unordered_map<char, std::string>;

// Función solicitada:
// 1. Recorre el archivo de entrada carácter por carácter.
// 2. Sustituye cada carácter por su código Huffman (std::string).
// 3. Concatena todos los códigos en un gran std::string.
// 4. Escribe el resultado en el archivo de salida.
bool codificarArchivoATextoHuffman(
    const std::string& rutaEntrada,
    const std::string& rutaSalida,
    const CodigoHuffmanMap& tablaCodigos,
    std::string* flujoBitsGenerado = nullptr) {
    std::ifstream archivoEntrada(rutaEntrada, std::ios::binary);
    if (!archivoEntrada.is_open()) {
        std::cerr << "Error: no se pudo abrir el archivo de entrada: " << rutaEntrada << "\n";
        return false;
    }

    std::string bitsConcatenados;

    // Reserva estimada opcional para reducir realocaciones si se conoce el tamaño
    archivoEntrada.seekg(0, std::ios::end);
    std::streamsize tamArchivo = archivoEntrada.tellg();
    archivoEntrada.seekg(0, std::ios::beg);
    if (tamArchivo > 0) {
        bitsConcatenados.reserve(static_cast<std::size_t>(tamArchivo) * 4);
    }

    char ch;
    // archivoEntrada.get(ch) lee cada byte sin omitir espacios, saltos de línea ni '\0'
    while (archivoEntrada.get(ch)) {
        auto it = tablaCodigos.find(ch);
        if (it == tablaCodigos.end()) {
            std::cerr << "Error: no existe codigo Huffman para el caracter ASCII "
                      << static_cast<int>(static_cast<unsigned char>(ch)) << "\n";
            return false;
        }
        bitsConcatenados += it->second;
    }

    if (archivoEntrada.bad()) {
        std::cerr << "Error de lectura durante el recorrido del archivo de entrada.\n";
        return false;
    }

    std::ofstream archivoSalida(rutaSalida, std::ios::binary | std::ios::trunc);
    if (!archivoSalida.is_open()) {
        std::cerr << "Error: no se pudo abrir o crear el archivo de salida: " << rutaSalida << "\n";
        return false;
    }

    archivoSalida.write(bitsConcatenados.data(),
                        static_cast<std::streamsize>(bitsConcatenados.size()));
    if (!archivoSalida.good()) {
        std::cerr << "Error al escribir la cadena resultante en el archivo de salida.\n";
        return false;
    }

    if (flujoBitsGenerado != nullptr) {
        *flujoBitsGenerado = std::move(bitsConcatenados);
    }

    return true;
}

// --- Auxiliares para construir un árbol y una tabla de códigos de ejemplo ---

struct NodoHuffman {
    char caracter;
    std::size_t frecuencia;
    NodoHuffman* izquierda;
    NodoHuffman* derecha;

    NodoHuffman(char c, std::size_t f, NodoHuffman* izq = nullptr, NodoHuffman* der = nullptr)
        : caracter(c), frecuencia(f), izquierda(izq), derecha(der) {}
};

struct ComparadorNodo {
    bool operator()(const NodoHuffman* a, const NodoHuffman* b) const {
        return a->frecuencia > b->frecuencia;
    }
};

void generarCodigosRecursivo(const NodoHuffman* nodo, const std::string& prefijo, CodigoHuffmanMap& tabla) {
    if (!nodo) return;

    if (!nodo->izquierda && !nodo->derecha) {
        // Caso borde: archivo con un único tipo de carácter repetido
        tabla[nodo->caracter] = prefijo.empty() ? "0" : prefijo;
        return;
    }

    generarCodigosRecursivo(nodo->izquierda, prefijo + "0", tabla);
    generarCodigosRecursivo(nodo->derecha, prefijo + "1", tabla);
}

void liberarArbol(NodoHuffman* nodo) {
    if (!nodo) return;
    liberarArbol(nodo->izquierda);
    liberarArbol(nodo->derecha);
    delete nodo;
}

CodigoHuffmanMap construirTablaDesdeArchivo(const std::string& rutaEntrada) {
    std::unordered_map<char, std::size_t> frecuencias;
    std::ifstream in(rutaEntrada, std::ios::binary);
    char ch;
    while (in.get(ch)) {
        ++frecuencias[ch];
    }

    CodigoHuffmanMap tabla;
    if (frecuencias.empty()) return tabla;

    std::priority_queue<NodoHuffman*, std::vector<NodoHuffman*>, ComparadorNodo> pq;
    for (const auto& par : frecuencias) {
        pq.push(new NodoHuffman(par.first, par.second));
    }

    while (pq.size() > 1) {
        NodoHuffman* izq = pq.top(); pq.pop();
        NodoHuffman* der = pq.top(); pq.pop();
        pq.push(new NodoHuffman('\0', izq->frecuencia + der->frecuencia, izq, der));
    }

    NodoHuffman* raiz = pq.top();
    generarCodigosRecursivo(raiz, "", tabla);
    liberarArbol(raiz);

    return tabla;
}

int main() {
    const std::string archivoEntrada = "entrada.txt";
    const std::string archivoSalida = "salida_huffman_texto.txt";

    // 1. Crear un archivo de entrada de prueba
    {
        std::ofstream demo(archivoEntrada, std::ios::binary);
        demo << "ABRACADABRA!";
    }

    // 2. Generar la tabla de códigos (char -> std::string de '0' y '1')
    CodigoHuffmanMap tabla = construirTablaDesdeArchivo(archivoEntrada);

    std::cout << "Tabla de codigos generada:\n";
    for (const auto& par : tabla) {
        std::cout << "  '" << par.first << "' -> " << par.second << "\n";
    }

    // 3. Ejecutar la función solicitada
    std::string cadenaCompleta;
    if (codificarArchivoATextoHuffman(archivoEntrada, archivoSalida, tabla, &cadenaCompleta)) {
        std::cout << "\nArchivo guardado en '" << archivoSalida << "'.\n";
        std::cout << "Longitud total de la cadena (en caracteres '0'/'1'): "
                  << cadenaCompleta.size() << "\n";
        std::cout << "Contenido: " << cadenaCompleta << "\n";
    }

    return 0;
}
