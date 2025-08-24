module frontend.parser.utils;

string strRepeat(string s, ulong times)
{
    string result;
    foreach (_; 0 .. times)
        result ~= s;
    return result;
}
