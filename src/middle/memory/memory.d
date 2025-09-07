module middle.memory.memory;

import std.conv;
import std.stdio;
import std.algorithm;
import std.array;
import std.variant;
import config;

// Enum para tipos de dados
enum DataType
{
    INT,
    STRING_REF // Referência para string no heap
}

// Estrutura para armazenar valor com tipo
struct TypedValue
{
    DataType type;
    int value; // Para int direto, ou índice da string no heap
}

// Memória por contexto
struct ContextInfo
{
    int[string] pointers; // var name -> memory index
    int startOffset; // onde o contexto começa na memória
    int allocatedSize; // quantos slots foram alocados
    int usedSlots; // quantos slots estão sendo usados

    // Pool de strings para este contexto
    string[] stringHeap;
    int[string] stringIndexMap; // string literal -> index no heap

    // Pool de doubles para este contexto
    double[] doubleHeap;
    int[double] doubleIndexMap; // double literal -> index no heap
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
    TypedValue[] memory = new TypedValue[MEMORY_BUFFER];

    this()
    {
        // inicializa todas as posições como livres
        for (size_t i = 0; i < MEMORY_BUFFER; i++)
        {
            occupied[i] = false;
            memory[i] = TypedValue(DataType.INT, 0);
        }

        currentContext = "global";
        nextContextId = 0;

        // Cria contexto global padrão
        this.createContext("global", MEMORY_BUFFER / (2 << 1));
    }

    bool createContext(string contextId, int slotsNeeded = 64)
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
            0, // slots usados
            [], // string heap vazio
            (int[string]).init
        );

        return true;
    }

    ContextInfo getContextInfoCurrent()
    {
        if (currentContext !in contexts)
        {
            // TODO: tratar essa porra, lançar uma exceção talvez
            throw new Exception("Contexto não encontrado!");
        }

        return this.contexts[currentContext];
    }

    ContextInfo* getCurrentContextPtr()
    {
        if (currentContext !in contexts)
        {
            throw new Exception("Contexto não encontrado!");
        }

        return &contexts[currentContext];
    }

    ref ContextInfo getCurrentContextRef()
    {
        if (currentContext !in contexts)
        {
            throw new Exception("Contexto não encontrado!");
        }

        return contexts[currentContext];
    }

    ref ContextInfo getCurrentContextRef(string context)
    {
        if (context !in contexts)
        {
            throw new Exception("Contexto não encontrado!");
        }

        return contexts[context];
    }

    ContextInfo* getCurrentContextPtr(string context)
    {
        if (context !in contexts)
        {
            throw new Exception("Contexto não encontrado!");
        }

        return &contexts[context];
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
            memory[i] = TypedValue(DataType.INT, 0);
        }

        // Remove o contexto
        contexts.remove(contextId);

        return true;
    }

    // Método original para alocar inteiros
    int alloca(string var, int value)
    {
        return allocaTyped(var, TypedValue(DataType.INT, value));
    }

    // Novo método para alocar strings
    int allocaString(string var, string value)
    {
        if (currentContext !in contexts)
        {
            return -1;
        }

        auto ctx = &contexts[currentContext];

        // Adiciona string ao heap e obtém índice
        int stringIndex = addStringToHeap(value);

        return allocaTyped(var, TypedValue(DataType.STRING_REF, stringIndex));
    }

    // Método interno para alocação tipada
    private int allocaTyped(string var, TypedValue typedValue)
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
                memory[i] = typedValue;
                ctx.pointers[var] = i;
                ctx.usedSlots++;
                return i;
            }
        }

        return -1; // não encontrou espaço livre
    }

    // Adiciona string ao heap do contexto atual
    int addStringToHeap(string str)
    {
        if (currentContext !in contexts)
        {
            return -1;
        }

        auto ctx = &contexts[currentContext];

        // Se a string já existe, retorna o índice existente
        if (str in ctx.stringIndexMap)
        {
            return ctx.stringIndexMap[str];
        }

        // Adiciona nova string
        int newIndex = cast(int) ctx.stringHeap.length;
        ctx.stringHeap ~= str;
        ctx.stringIndexMap[str] = newIndex;

        return newIndex;
    }

    // Obtém string do heap
    string getStringFromHeap(int index)
    {
        if (currentContext !in contexts)
        {
            return "";
        }

        auto ctx = &contexts[currentContext];

        if (index < 0 || index >= ctx.stringHeap.length)
        {
            return "";
        }

        return ctx.stringHeap[index];
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
        memory[indice] = TypedValue(DataType.INT, 0);

        // remove do mapeamento do contexto
        ctx.pointers.remove(var);
        ctx.usedSlots--;

        return true;
    }

    TypedValue* getTypedPointer(string var)
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

    int* getPointer(string var)
    {
        auto typedPtr = getTypedPointer(var);
        if (typedPtr is null)
        {
            return null;
        }
        return &(typedPtr.value);
    }

    int getValue(string var)
    {
        auto typedPtr = getTypedPointer(var);
        if (typedPtr is null || typedPtr.type != DataType.INT)
        {
            return 0;
        }
        return typedPtr.value;
    }

    string getStringValue(string var)
    {
        auto typedPtr = getTypedPointer(var);
        if (typedPtr is null || typedPtr.type != DataType.STRING_REF)
        {
            return "";
        }
        return getStringFromHeap(typedPtr.value);
    }

    DataType getVariableType(string var)
    {
        auto typedPtr = getTypedPointer(var);
        if (typedPtr is null)
        {
            return DataType.INT; // default
        }
        return typedPtr.type;
    }

    bool setValue(string var, int newValue)
    {
        auto typedPtr = getTypedPointer(var);
        if (typedPtr is null)
        {
            return false;
        }

        typedPtr.type = DataType.INT;
        typedPtr.value = newValue;
        return true;
    }

    bool setStringValue(string var, string newValue)
    {
        auto typedPtr = getTypedPointer(var);
        if (typedPtr is null)
        {
            return false;
        }

        int stringIndex = addStringToHeap(newValue);
        typedPtr.type = DataType.STRING_REF;
        typedPtr.value = stringIndex;
        return true;
    }

    // Método para copiar valor de argumento para variável do contexto
    bool storeArgument(string var, int argumentValue)
    {
        return setValue(var, argumentValue) || (alloca(var, argumentValue) != -1);
    }

    void exportToVM(ref int[MEMORY_BUFFER] vmMemory, ref string[] stringConstants)
    {
        for (int i = 0; i < MEMORY_BUFFER; i++)
        {
            vmMemory[i] = 0;
        }
        stringConstants = [];

        int[string] globalStringMap;

        globalStringMap[""] = 0;
        stringConstants ~= "";

        foreach (ctxId, ctx; contexts)
        {
            foreach (str; ctx.stringHeap)
            {
                if (str !in globalStringMap)
                {
                    globalStringMap[str] = cast(int) stringConstants.length;
                    stringConstants ~= str;
                }
            }
        }

        foreach (ctxId, ctx; contexts)
        {
            foreach (var, addr; ctx.pointers)
            {
                if (addr >= 0 && addr < MEMORY_BUFFER)
                {
                    if (memory[addr].type == DataType.STRING_REF)
                    {
                        int heapIndex = memory[addr].value;
                        string str = "";

                        if (heapIndex >= 0 && heapIndex < ctx.stringHeap.length)
                            str = ctx.stringHeap[heapIndex];

                        vmMemory[addr] = globalStringMap[str];
                    }
                    else
                    {
                        vmMemory[addr] = memory[addr].value;
                    }
                }
            }
        }
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
                TypedValue currentValue = memory[indice];
                if (currentValue.type == DataType.INT)
                {
                    writeln("  Var: ", var, " -> Index: ", indice, " -> Value: ", currentValue.value, " (int)");
                }
                else
                {
                    string strValue = getStringFromHeap(currentValue.value);
                    writeln("  Var: ", var, " -> Index: ", indice, " -> Value: \"", strValue,
                        "\" (string, heap index: ", currentValue.value, ")");
                }
            }

            // Mostra heap de strings
            if (ctx.stringHeap.length > 0)
            {
                writeln("  String Heap: ", ctx.stringHeap);
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

    bool copyStringBetweenContexts(string fromContext, string toContext, int memoryIndex)
    {
        if (fromContext !in contexts || toContext !in contexts)
            return false;

        auto fromCtx = &contexts[fromContext];
        auto toCtx = &contexts[toContext];

        if (memoryIndex < 0 || memoryIndex >= MEMORY_BUFFER)
            return false;

        if (memory[memoryIndex].type != DataType.STRING_REF)
            return false;

        int fromStringIndex = memory[memoryIndex].value;
        if (fromStringIndex < 0 || fromStringIndex >= fromCtx.stringHeap.length)
            return false;

        string actualString = fromCtx.stringHeap[fromStringIndex];

        // Adicionar string ao heap do contexto de destino
        string oldContext = currentContext;
        currentContext = toContext;
        int newStringIndex = addStringToHeap(actualString);
        currentContext = oldContext;

        // Atualizar referência no contexto de destino
        memory[memoryIndex].value = newStringIndex;

        return true;
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
