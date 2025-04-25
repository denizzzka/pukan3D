module pukan.vulkan.frame;

//~ import pukan.exceptions;
import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;

//TODO: can LogicalDevice be alias to instanced object?
class Frame(LogicalDevice)
{
    LogicalDevice device;
    VkQueue graphicsQueue;
    VkQueue presentQueue;
    CommandPool!LogicalDevice commandPool;

    this(LogicalDevice dev, VkFormat imageFormat, VkQueue graphics, VkQueue present)
    {
        device = dev;
        graphicsQueue = graphics;
        presentQueue = present;

        commandPool = device.createCommandPool();
        commandPool.initBuffs(1);
    }

    ~this()
    {
        destroy(commandPool);
    }
}
