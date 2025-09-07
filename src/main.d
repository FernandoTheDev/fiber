module main;

import std.stdio;
import std.array;
import std.file;
import std.getopt;
import std.path;
import std.string;
import std.conv;
import std.datetime.stopwatch;
import frontend.lexer.lexer;
import frontend.lexer.token;
import frontend.parser.parser;
import frontend.parser.ast;
import middle.semantic;
import middle.memory.memory;
import backend.codegen.builder;
import backend.vm.vm;
import config;

alias fileWrite = std.file.write;

struct CompilerOptions
{
    bool debugMode = false;
    bool showStats = false;
    string outputFile = null;
    string inputFile = null;
}

struct CompilationResult
{
    int[] byteCode;
    int[MEMORY_BUFFER] vmMemory;
    string[] stringConstants;
}

CompilationResult compileSource(string file, string source, FiberMemory mem, bool debugMode = false)
{
    Lexer lexer = new Lexer(source, file);
    Token[] tokens = lexer.tokenize();
    if (debugMode)
    {
        // writeln("Tokens: ", tokens);
    }

    Parser parser = new Parser(tokens);
    Program prog = parser.parse();
    if (debugMode)
    {
        writeln("AST:");
        prog.print(0);
        writeln();
    }

    Semantic semantic = new Semantic(mem);
    Program newProg = cast(Program) semantic.analyzeNode(prog);

    if (debugMode)
    {
        mem.debugMemory();
        writeln();
    }

    Builder codegen = new Builder(mem, semantic);
    codegen.generate(newProg);
    int[] byteCode = codegen.build();

    // Preparar dados para VM
    CompilationResult result;
    result.byteCode = byteCode;

    // Exportar memória e strings
    mem.exportToVM(result.vmMemory, result.stringConstants);

    if (debugMode)
    {
        writeln("=== Debug Info ===");
        writeln("Disassemble:");
        writeln(codegen.disassemble());
        writeln("Byte code: ", byteCode);
        writeln();

        writeln("=== String Constants ===");
        foreach (i, str; result.stringConstants)
        {
            writefln("%d: \"%s\"", i, str);
        }
        writeln();

        writeln("=== VM Memory (non-zero values) ===");
        foreach (i, val; result.vmMemory)
        {
            if (val != 0)
            {
                writefln("mem[%d] = %d", i, val);
            }
        }
        writeln();
    }

    return result;
}

void executeProgram(int[] byteCode, int[MEMORY_BUFFER] memBuffer, string[] stringConstants, bool debugMode = false)
{
    FiberVM vm = new FiberVM(byteCode, memBuffer);

    foreach (str; stringConstants)
    {
        vm.addStringLiteral(str);
    }

    if (debugMode)
    {
        writeln("Executing program with ", stringConstants.length, " string constants...");
    }
    vm.run();
}

struct SerializedProgram
{
    int[] byteCode;
    int[MEMORY_BUFFER] memory;
    string[] stringConstants;
}

string[] compressZeros(int[] data)
{
    string[] result;
    int i = 0;

    while (i < data.length)
    {
        if (data[i] == 0)
        {
            // Contar sequência de zeros
            int zeroCount = 0;
            int start = i;
            while (i < data.length && data[i] == 0)
            {
                zeroCount++;
                i++;
            }

            // Se tem mais de 2 zeros consecutivos, comprime
            if (zeroCount >= 3)
            {
                result ~= "F" ~ to!string(zeroCount);
            }
            else
            {
                // Poucos zeros, não compensa comprimir
                for (int j = 0; j < zeroCount; j++)
                {
                    result ~= "0";
                }
            }
        }
        else
        {
            // Valor não-zero, adiciona normalmente
            result ~= to!string(data[i]);
            i++;
        }
    }

    return result;
}

// Descomprime sequências Fn de volta para zeros
int[] decompressZeros(string[] compressedData, int expectedSize)
{
    int[] result;
    result.reserve(expectedSize);

    foreach (token; compressedData)
    {
        if (token.length > 1 && token[0] == 'F')
        {
            // Token de compressão Fn
            int zeroCount = to!int(token[1 .. $]);
            for (int i = 0; i < zeroCount; i++)
            {
                result ~= 0;
            }
        }
        else
        {
            // Valor normal
            result ~= to!int(token);
        }
    }

    return result;
}

void saveProgram(int[] byteCode, int[512] memory, string[] stringConstants, string filename)
{
    string[] output;

    // Cabeçalho
    output ~= "FIBERBC";
    output ~= to!string(byteCode.length);
    output ~= to!string(MEMORY_BUFFER);
    output ~= to!string(stringConstants.length);

    // ByteCode comprimido
    string[] compressedByteCode = compressZeros(byteCode);
    output ~= compressedByteCode;

    output ~= "MEMORY";

    // Memória comprimida
    string[] compressedMemory = compressZeros(memory[]);
    output ~= compressedMemory;

    // Strings (nova seção)
    output ~= "STRINGS";
    foreach (str; stringConstants)
    {
        // Escapar strings para serialização
        string escaped = str.replace("\\", "\\\\").replace(" ", "\\s").replace("\n", "\\n");
        output ~= escaped;
    }

    string fileContent = output.join(" ");
    fileWrite(filename, fileContent);

    // Estatísticas de compressão
    int originalSize = 4 + cast(int) byteCode.length + MEMORY_BUFFER + cast(
        int) stringConstants.length;
    int compressedSize = cast(int) output.length;
    double ratio = cast(double) compressedSize / originalSize * 100.0;

    writeln("Program saved to: ", filename);
    writefln("Compression: %d -> %d tokens (%.1f%%)", originalSize, compressedSize, ratio);
    writefln("Includes %d string constants", stringConstants.length);
}

SerializedProgram loadProgram(string filename)
{
    SerializedProgram program;
    string content = readText(filename);
    string[] parts = content.strip().split(" ");

    if (parts.length < 5 || parts[0] != "FIBERBC")
        throw new Exception("Invalid bytecode file format");

    int bytecodeSize = to!int(parts[1]);
    int memorySize = to!int(parts[2]);
    int stringCount = to!int(parts[3]);

    if (memorySize != MEMORY_BUFFER)
        throw new Exception("Memory size mismatch");

    int memoryIndex = -1;
    int stringsIndex = -1;

    for (int i = 4; i < parts.length; i++)
    {
        if (parts[i] == "MEMORY" && memoryIndex == -1)
            memoryIndex = i;
        else if (parts[i] == "STRINGS" && stringsIndex == -1)
        {
            stringsIndex = i;
            break;
        }
    }

    if (memoryIndex == -1)
        throw new Exception("MEMORY separator not found");

    if (stringCount > 0 && stringsIndex == -1)
        throw new Exception("STRINGS separator not found but stringCount > 0");

    string[] compressedByteCode = parts[4 .. memoryIndex];
    int[] decompressedByteCode = decompressZeros(compressedByteCode, bytecodeSize);

    if (decompressedByteCode.length != bytecodeSize)
        throw new Exception("Bytecode decompression failed");

    string[] compressedMemory;
    if (stringsIndex != -1)
        compressedMemory = parts[memoryIndex + 1 .. stringsIndex];
    else
        compressedMemory = parts[memoryIndex + 1 .. $];

    int[] decompressedMemory = decompressZeros(compressedMemory, memorySize);

    if (decompressedMemory.length != memorySize)
        throw new Exception("Memory decompression failed");

    string[] stringConstants;
    if (stringsIndex != -1 && stringCount > 0)
    {
        int stringsEnd = stringsIndex + 1 + stringCount;
        if (stringsEnd > parts.length)
            throw new Exception(format(
                    "Not enough strings in file. Expected '%d', but only '%d' available",
                    stringCount, parts.length - stringsIndex - 1));

        string[] rawStrings = parts[stringsIndex + 1 .. stringsEnd];

        if (rawStrings.length != stringCount)
            throw new Exception(
                "String count mismatch. Expected {stringCount}, got {rawStrings.length}");

        foreach (rawStr; rawStrings)
        {
            string unescaped = rawStr.replace("\\s", " ").replace("\\n", "\n")
                .replace("\\\\", "\\");
            stringConstants ~= unescaped;
        }
    }

    program.byteCode = decompressedByteCode;

    for (int i = 0; i < MEMORY_BUFFER && i < decompressedMemory.length; i++)
        program.memory[i] = decompressedMemory[i];

    program.stringConstants = stringConstants;
    return program;
}

string generateOutputFilename(string inputFile, string extension)
{
    return setExtension(inputFile, extension);
}

void printUsage(string programName)
{
    writeln("Usage: ", programName, " [options] <input-file>");
    writeln();
    writeln("Options:");
    writeln("  -d, --debug          Enable debug mode (show tokens, AST, bytecode)");
    writeln("  -s, --stats          Show execution statistics");
    writeln("  -o, --output=FILE    Save bytecode to specified file");
    writeln("  -h, --help          Show this help message");
    writeln();
    writeln("Supported file types:");
    writeln("  .fir    Source files (compiled and executed)");
    writeln("  .bc     Program files (executed directly with memory)");
    writeln();
    writeln("Examples:");
    writeln("  ", programName, " program.fir                    # Compile and run");
    writeln("  ", programName, " program.bc                     # Run bytecode directly");
    writeln("  ", programName, " -o program.bc program.fir      # Compile to bytecode file");
    writeln("  ", programName, " -d -s program.fir              # Debug mode with stats");
}

void main(string[] args)
{
    CompilerOptions options;

    try
    {
        auto helpInfo = getopt(args,
            "debug|d", "Enable debug mode", &options.debugMode,
            "stats|s", "Show execution statistics", &options.showStats,
            "output|o", "Output bytecode file", &options.outputFile,
        );

        if (helpInfo.helpWanted)
        {
            printUsage(args[0]);
            return;
        }

        if (args.length != 2)
        {
            writeln("ERROR: Valid source file is required.");
            writeln();
            printUsage(args[0]);
            return;
        }

        options.inputFile = args[1];

        if (!exists(options.inputFile))
        {
            writefln("ERROR: File '%s' does not exist.", options.inputFile);
            return;
        }

        FiberMemory mem = new FiberMemory();
        StopWatch totalTimer, compileTimer, vmTimer;

        if (options.showStats)
        {
            totalTimer.start();
        }

        if (extension(options.inputFile) == ".bc")
        {
            if (options.debugMode)
            {
                writeln("Loading program file: ", options.inputFile);
            }

            SerializedProgram program = loadProgram(options.inputFile);

            if (options.showStats)
            {
                vmTimer.start();
            }

            executeProgram(program.byteCode, program.memory, program.stringConstants, options
                    .debugMode);

            if (options.showStats)
            {
                vmTimer.stop();
                totalTimer.stop();
                writefln("VM execution time: %.4f ms", cast(double) vmTimer.peek.total!"usecs" / 1000.0);
                writefln("Total time: %.4f ms", cast(double) totalTimer.peek.total!"usecs" / 1000.0);
            }
        }
        else
        {
            if (options.showStats)
            {
                compileTimer.start();
            }

            string source = readText(options.inputFile);
            CompilationResult result = compileSource(options.inputFile, source, mem, options
                    .debugMode);

            if (options.showStats)
            {
                compileTimer.stop();
            }

            if (options.outputFile !is null)
            {
                saveProgram(result.byteCode, result.vmMemory, result.stringConstants, options
                        .outputFile);

                if (options.showStats)
                {
                    totalTimer.stop();
                    writefln("Compilation time: %.4f ms", cast(double) compileTimer.peek.total!"usecs" / 1000.0);
                    writefln("Total time: %.4f ms", cast(double)(
                            totalTimer.peek.total!"usecs" / 1000.0));
                }
                return;
            }

            if (options.showStats)
            {
                vmTimer.start();
            }

            executeProgram(result.byteCode, result.vmMemory, result.stringConstants, options
                    .debugMode);

            if (options.showStats)
            {
                vmTimer.stop();
                totalTimer.stop();
                writefln("Compilation time: %.4f ms", cast(double) compileTimer.peek.total!"usecs" / 1000.0);
                writefln("VM execution time: %.4f ms", cast(double) vmTimer.peek.total!"usecs" / 1000.0);
                writefln("Total time: %.4f ms", cast(double) totalTimer.peek.total!"usecs" / 1000.0);
            }
        }
    }
    catch (Exception e)
    {
        writeln(e);
        writeln("ERROR: ", e.msg);
        if (options.debugMode)
        {
            writeln("Stack trace:");
            writeln(e.info);
        }
    }
}
