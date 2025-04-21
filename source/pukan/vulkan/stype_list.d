module pukan.vulkan.stype_list;

import pukan.vulkan.bindings;
import std.meta;
import std.traits;

struct Entry(T, alias t)
{
    alias CreateInfoT = T;
    enum VkStructureType sType = t;
}

alias ST = VkStructureType;

alias sType_list = AliasSeq!(
    Entry!(VkInstanceCreateInfo,    ST.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO),
);

template getCreateInfoStructureType(T)
{
    static foreach(e; sType_list)
    {
        static if(is(e.CreateInfoT == PointerTarget!T))
            enum VkStructureType getCreateInfoStructureType = e.sType;
    }
}

unittest
{
    enum x = getCreateInfoStructureType!(VkInstanceCreateInfo*);
    static assert(x == VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
}
