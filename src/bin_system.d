module bin_system;

import std.stdio;
import std.file;

enum BinDataType : ubyte
{
    HEADER = 1, // Para "Fiber"
    NUMERIC = 2, // Para números como 54, 512, etc
    BYTES_SEQUENCE = 3, // Para sequências como 70 101 114...
    SECTION_HEADER = 4, // Define que existe uma seção
    MEMORY = 5, // Section
    STRINGS = 6, // Section
    STRING_DATA = 7, // Para strings com formatação
    RAW_BYTE = 8 // Para bytes individuais
}

void addTLVHeader(ref ubyte[] buffer, string header)
{
    buffer ~= BinDataType.HEADER;
    uint length = cast(uint) header.length;
    ubyte* lenPtr = cast(ubyte*)&length;
    buffer ~= lenPtr[0 .. 4];
    buffer ~= cast(ubyte[]) header;
}

void addTLVNumeric(ref ubyte[] buffer, uint value)
{
    buffer ~= BinDataType.NUMERIC;
    uint length = 4;
    ubyte* lenPtr = cast(ubyte*)&length;
    buffer ~= lenPtr[0 .. 4];
    ubyte* valuePtr = cast(ubyte*)&value;
    buffer ~= valuePtr[0 .. 4];
}

void addTLVByte(ref ubyte[] buffer, ubyte value)
{
    buffer ~= BinDataType.RAW_BYTE;
    uint length = 1;
    ubyte* lenPtr = cast(ubyte*)&length;
    buffer ~= lenPtr[0 .. 4];
    buffer ~= value;
}

void addTLVBytes(ref ubyte[] buffer, ubyte[] values)
{
    buffer ~= BinDataType.BYTES_SEQUENCE;
    uint length = cast(uint) values.length;
    ubyte* lenPtr = cast(ubyte*)&length;
    buffer ~= lenPtr[0 .. 4];
    buffer ~= values;
}

void addTLVSectionHeader(ref ubyte[] buffer, BinDataType section)
{
    buffer ~= BinDataType.SECTION_HEADER; // Tipo TLV (sempre o mesmo para seções)
    uint length = 1; // BinDataType sempre tem 1 byte
    ubyte* lenPtr = cast(ubyte*)&length;
    buffer ~= lenPtr[0 .. 4]; // Comprimento (4 bytes)
    buffer ~= section; // O valor do enum (1 byte)
}

void addTLVString(ref ubyte[] buffer, string str)
{
    buffer ~= BinDataType.STRING_DATA;
    uint length = cast(uint) str.length;
    ubyte* lenPtr = cast(ubyte*)&length;
    buffer ~= lenPtr[0 .. 4];
    buffer ~= cast(ubyte[]) str;
}

void readTLVItem(ref File f, ref ubyte[1] typeBuffer, ref ubyte[4] lengthBuffer)
{
    ubyte[] typeResult = f.rawRead(typeBuffer);
    if (typeResult.length == 0)
        throw new Exception("Unexpected end of file");

    ubyte[] lengthResult = f.rawRead(lengthBuffer);
    if (lengthResult.length != 4)
        throw new Exception("Failed to read length");
}

string readTLVString(ref File f, ref ubyte[4] lengthBuffer)
{
    uint length = *cast(uint*) lengthBuffer.ptr;
    ubyte[] stringBuffer = new ubyte[length];
    ubyte[] result = f.rawRead(stringBuffer);
    if (result.length != length)
        throw new Exception("Failed to read string data");
    return cast(string) stringBuffer;
}

int readTLVInt(ref File f, ref ubyte[4] lengthBuffer)
{
    uint length = *cast(uint*) lengthBuffer.ptr;
    if (length != 4)
        throw new Exception("Invalid int length - expected 4 bytes");
    ubyte[4] intBuffer;
    ubyte[] result = f.rawRead(intBuffer);
    if (result.length != 4)
        throw new Exception("Failed to read int data");
    return *cast(int*) intBuffer.ptr;
}

ubyte[] readTLVBytes(ref File f, ref ubyte[4] lengthBuffer)
{
    uint length = *cast(uint*) lengthBuffer.ptr;
    ubyte[] bytesBuffer = new ubyte[length];
    ubyte[] result = f.rawRead(bytesBuffer);
    if (result.length != length)
        throw new Exception("Failed to read bytes data");
    return bytesBuffer;
}
