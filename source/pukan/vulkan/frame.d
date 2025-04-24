module pukan.vulkan.frame;

//~ import pukan.exceptions;
import pukan.vulkan;
import pukan.vulkan.bindings;
//~ import pukan.vulkan.helpers;
//~ import pukan: toPrettyString;
//~ import std.exception: enforce;
//~ import std.string: toStringz;

struct FrameSettings
{
}

//TODO: can LogicalDevice be alias to instanced object?
class Frame(LogicalDevice)
{
    LogicalDevice device;
    SwapChain!LogicalDevice swapChain;
    VkQueue graphicsQueue;
    VkQueue presentQueue;
    CommandPool!LogicalDevice commandPool;

    this(LogicalDevice dev, ref FrameSettings, SwapChain!LogicalDevice sc, VkQueue graphics, VkQueue present)
    {
        device = dev;
        swapChain = sc;
        graphicsQueue = graphics;
        presentQueue = present;

        commandPool = device.createCommandPool();
        commandPool.initBuffs(1);
    }

    ~this()
    {
        destroy(commandPool);
        destroy(swapChain);
    }

    //~ void resize
    //~ draw(render_packet)
}
