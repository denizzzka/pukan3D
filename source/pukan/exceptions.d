module pukan.exceptions;

class PukanException: Exception
{
    import pukan.vulkan_sdk: VkResult;

    VkResult code;

    this(string msg, VkResult code, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure @safe
    {
        super(msg, file, line, nextInChain);
    }
}
