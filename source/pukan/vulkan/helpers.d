module pukan.vulkan.helpers;

import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.stype_list: getCreateInfoStructureType;

class VkObj(T...)
{
private
{
    enum findStr = "CreateInfo*";

    template IsCreateInfo(T)
    {
        enum string typeName = T.stringof;

        enum IsCreateInfo =
            typeName.length > findStr.length &&
            typeName[$-findStr.length .. $] == findStr;
    }

    static foreach(i, E; T)
    {
        static if(IsCreateInfo!E)
            enum createInfoIdx = i;
    }

    static assert(__traits(compiles, createInfoIdx), findStr~" argument not found");

    alias TCreateInfo = T[createInfoIdx];

    enum string infoStructName = TCreateInfo.stringof;
    enum resultingName = infoStructName[0 .. $ - ("CreateInfo".length + 1)];
    mixin("alias BaseType = "~resultingName~";");
    enum baseName = resultingName["Vk".length .. $];
    enum ctorName = "vkCreate"~baseName;
    enum dtorName = "vkDestroy"~baseName;
}

    VkAllocationCallbacks* allocator;
    BaseType vkObj;
    alias this = vkObj;

    this(T a)
    {
        // Placed out of debug scope to check release code too
        enum sTypeMustBe = getCreateInfoStructureType!TCreateInfo;

        debug
        {
            auto ref createInfo = a[createInfoIdx];
            createInfo.sType = sTypeMustBe;
        }

        allocator = a[createInfoIdx + 1];

        mixin("auto r = "~ctorName~"(a, &vkObj).vkCheck;");
        r.vkCheck(resultingName~" creation failed");
    }

    this(BaseType o, VkAllocationCallbacks* alloc)
    in(o !is null)
    {
        vkObj = o;
        allocator = alloc;
    }

    ~this()
    {
        mixin(dtorName~"(vkObj, allocator);");
    }
}

auto create(T...)(T s)
{
    return new VkObj!T(s);
}
