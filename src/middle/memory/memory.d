module middle.memory.memory;

import std.conv;
import std.stdio;
import std.algorithm;
import std.array;
import config;

class FiberMemory
{
private:
    bool[MEMORY_BUFFER] occupied; // flag para cada posição da memória
public:
    // Mapeamento de variável -> registrador atual
    int[MEMORY_BUFFER] memory;
    // salva o ponteiro da variavel para a memória
    // pointers["x"] = 0
    int[string] pointers;

    this()
    {
        // inicializa todas as posições como livres
        for (size_t i = 0; i < MEMORY_BUFFER; i++)
        {
            occupied[i] = false;
        }
    }

    int alloca(string var, int value)
    {
        if (var in pointers)
        {
            // Erro, variavel já está alocada
            return -1; // ou throw exception
        }

        // Procura primeira posição livre na memória
        for (size_t i = 0; i < MEMORY_BUFFER; i++)
        {
            if (!occupied[i])
            {
                memory[i] = value;
                occupied[i] = true;
                pointers[var] = cast(int) i;
                return cast(int) i; // retorna o índice onde foi alocado
            }
        }

        // Memória cheia
        return -1;
    }

    bool free(string var)
    {
        if (var !in pointers)
        {
            return false; // variável não existe
        }

        int indice = pointers[var];

        // marca posição como livre
        occupied[indice] = false;
        memory[indice] = 0; // limpa o valor (opcional)

        // remove do mapeamento
        pointers.remove(var);

        return true;
    }

    int* getPointer(string var)
    {
        if (var !in pointers)
        {
            return null;
        }

        int indice = pointers[var];
        return &memory[indice];
    }

    int getValue(string var)
    {
        if (var !in pointers)
        {
            // Erro: variável não encontrada
            return 0; // ou throw exception
        }

        // Senão, pega da memória
        int indice = pointers[var];
        return memory[indice];
    }

    bool setValue(string var, int newValue)
    {
        if (var !in pointers)
        {
            return false;
        }
        // Senão, modifica na memória
        int indice = pointers[var];
        memory[indice] = newValue;
        return true;
    }

    void debugMemory()
    {
        writeln("=== State of Memory ===");
        foreach (var, indice; pointers)
        {
            string location = "Memory";
            int currentValue = memory[indice];

            writeln("Var: ", var, " -> Index: ", indice, " -> Value: ",
                currentValue, " -> Localization: ", location);
        }

        size_t ocupadas = 0;
        for (size_t i = 0; i < MEMORY_BUFFER; i++)
        {
            if (occupied[i])
                ocupadas++;
        }
        writeln("Positions held: ", ocupadas, "/MEMORY_BUFFER");
    }
}
