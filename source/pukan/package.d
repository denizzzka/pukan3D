module pukan;

public import pukan.renderer;

import pukan.vulkan_sdk;

import std.typecons;

alias DeltaTime = Typedef!(float, float.init, "delta time");

//~ struct VulkanContext
//~ {
    //~ VkInstance instance;
//~ }

struct MuteLogger
{
    void info(T...)(T s) {}
}

string toPrettyString(T)(ref T val)
{
    import mir.ser.json: serializeJsonPretty;
    import std.conv: to;

    return val.serializeJsonPretty.to!string;
}
