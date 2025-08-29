module middle.memory.memory;

import std.conv;
import std.stdio;
import std.algorithm;
import std.array;
import config;

// Memória por contexto
struct ContextInfo
{
    int[string] pointers; // var name -> memory index
    int startOffset; // onde o contexto começa na memória
    int allocatedSize; // quantos slots foram alocados
    int usedSlots; // quantos slots estão sendo usados
}

class FiberMemory
{
private:
    bool[] occupied = new bool[MEMORY_BUFFER]; // flag para cada posição da memória

    // Sistema de contextos
    string currentContext;
    int nextContextId;

    string[] contextStack;
public:
    ContextInfo[string] contexts;
    int[] memory = new int[MEMORY_BUFFER];

    this()
    {
        // inicializa todas as posições como livres
        for (size_t i = 0; i < MEMORY_BUFFER; i++)
        {
            occupied[i] = false;
        }

        currentContext = "global";
        nextContextId = 0;

        // Cria contexto global padrão
        this.createContext("global", MEMORY_BUFFER / 2); // metade da memória para global
    }

    string createContext(int slotsNeeded = 64)
    {
        string contextId = "ctx_" ~ nextContextId.to!string;
        nextContextId++;
        createContext(contextId, slotsNeeded);
        return contextId;
    }

    bool createContext(string contextId, int slotsNeeded)
    {
        if (contextId in contexts)
        {
            return false; // contexto já existe
        }

        // Procura espaço livre contíguo para o contexto
        int startPos = findContiguousSpace(slotsNeeded);
        if (startPos == -1)
        {
            return false; // não há espaço suficiente
        }

        // Aloca o espaço para o contexto
        for (int i = startPos; i < startPos + slotsNeeded; i++)
        {
            occupied[i] = true;
        }

        // Cria o contexto
        contexts[contextId] = ContextInfo(
            (int[string]).init, // pointers vazios
            startPos, // offset inicial
            slotsNeeded, // tamanho alocado
            0
        );

        return true;
    }

    ContextInfo getContextInfoCurrent()
    {
        // TODO: validações de erro
        if (currentContext !in contexts)
        {
            // TODO: tratar essa porra, lançar uma exceção talvez
        }

        // Salva contexto atual na stack

        return this.contexts[currentContext];
    }

    bool loadContext(string contextId)
    {
        if (contextId !in contexts)
        {
            return false;
        }

        // Salva contexto atual na stack
        contextStack ~= currentContext;
        currentContext = contextId;

        return true;
    }

    bool restoreContext()
    {
        if (contextStack.length == 0)
        {
            return false;
        }

        // Restaura contexto anterior
        currentContext = contextStack[$ - 1];
        contextStack = contextStack[0 .. $ - 1];

        return true;
    }

    bool destroyContext(string contextId)
    {
        if (contextId !in contexts || contextId == "global")
        {
            return false; // não pode destruir global
        }

        auto ctx = contexts[contextId];

        // Libera todas as posições do contexto
        for (int i = ctx.startOffset; i < ctx.startOffset + ctx.allocatedSize; i++)
        {
            occupied[i] = false;
            memory[i] = 0;
        }

        // Remove o contexto
        contexts.remove(contextId);

        return true;
    }

    int alloca(string var, int value)
    {
        if (currentContext !in contexts)
        {
            return -1; // contexto atual não existe
        }

        auto ctx = &contexts[currentContext];

        if (var in ctx.pointers)
        {
            // Erro, variável já está alocada neste contexto
            return -1;
        }

        if (ctx.usedSlots >= ctx.allocatedSize)
        {
            // Contexto cheio
            return -1;
        }

        // Procura primeira posição livre dentro do espaço do contexto
        int contextStart = ctx.startOffset;
        int contextEnd = ctx.startOffset + ctx.allocatedSize;

        for (int i = contextStart; i < contextEnd; i++)
        {
            // Verifica se o slot está livre no contexto atual
            bool slotUsedInThisContext = false;
            foreach (varName, varIndex; ctx.pointers)
            {
                if (varIndex == i)
                {
                    slotUsedInThisContext = true;
                    break;
                }
            }

            // Se não está sendo usado no contexto atual, pode usar
            if (!slotUsedInThisContext)
            {
                memory[i] = value;
                ctx.pointers[var] = i;
                ctx.usedSlots++;
                return i;
            }
        }

        return -1; // não encontrou espaço livre
    }

    bool free(string var)
    {
        if (currentContext !in contexts)
        {
            return false;
        }

        auto ctx = &contexts[currentContext];

        if (var !in ctx.pointers)
        {
            return false; // variável não existe neste contexto
        }

        int indice = ctx.pointers[var];

        // limpa o valor
        memory[indice] = 0;

        // remove do mapeamento do contexto
        ctx.pointers.remove(var);
        ctx.usedSlots--;

        return true;
    }

    int* getPointer(string var)
    {
        if (currentContext !in contexts)
        {
            return null;
        }

        auto ctx = &contexts[currentContext];

        if (var !in ctx.pointers)
        {
            return null;
        }

        int indice = ctx.pointers[var];
        return &memory[indice];
    }

    int getValue(string var)
    {
        if (currentContext !in contexts)
        {
            return 0;
        }

        auto ctx = &contexts[currentContext];

        if (var !in ctx.pointers)
        {
            return 0; // ou throw exception
        }

        int indice = ctx.pointers[var];
        return memory[indice];
    }

    bool setValue(string var, int newValue)
    {
        if (currentContext !in contexts)
        {
            return false;
        }

        auto ctx = &contexts[currentContext];

        if (var !in ctx.pointers)
        {
            return false;
        }

        int indice = ctx.pointers[var];
        memory[indice] = newValue;
        return true;
    }

    // Método para copiar valor de argumento para variável do contexto
    bool storeArgument(string var, int argumentValue)
    {
        return setValue(var, argumentValue) || (alloca(var, argumentValue) != -1);
    }

    // Helpers
    private int findContiguousSpace(int slotsNeeded)
    {
        for (size_t i = 0; i <= MEMORY_BUFFER - slotsNeeded; i++)
        {
            bool hasSpace = true;

            // Verifica se há espaço contíguo
            for (size_t j = i; j < i + slotsNeeded; j++)
            {
                if (occupied[j])
                {
                    hasSpace = false;
                    break;
                }
            }

            if (hasSpace)
            {
                return cast(int) i;
            }
        }

        return -1; // não encontrou espaço
    }

    void debugMemory()
    {
        writeln("=== State of Memory (Current Context: ", currentContext, ") ===");

        // Mostra informações dos contextos
        foreach (ctxId, ctx; contexts)
        {
            writeln("Context: ", ctxId, " (", ctx.usedSlots, "/", ctx.allocatedSize, " slots, offset: ", ctx
                    .startOffset, ")");
            foreach (var, indice; ctx.pointers)
            {
                int currentValue = memory[indice];
                writeln("  Var: ", var, " -> Index: ", indice, " -> Value: ", currentValue);
            }
        }

        writeln("Context Stack: ", contextStack);

        size_t ocupadas = 0;
        for (size_t i = 0; i < MEMORY_BUFFER; i++)
        {
            if (occupied[i])
                ocupadas++;
        }
        writeln("Total Positions held: ", ocupadas, "/", MEMORY_BUFFER);
    }

    // Getters para debug/info
    string getCurrentContext()
    {
        return currentContext;
    }

    string[] getContextStack()
    {
        return contextStack.dup;
    }

    bool contextExists(string contextId)
    {
        return (contextId in contexts) !is null;
    }
}
