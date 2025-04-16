module pukan.exceptions;

class PukanException: Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure @safe
    {
        super(msg, file, line, nextInChain);
    }
}
