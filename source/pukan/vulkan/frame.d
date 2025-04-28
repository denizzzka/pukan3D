module pukan.vulkan.frame;

//~ import pukan.exceptions;
import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;

//TODO: can LogicalDevice be alias to instanced object?
class FrameBuilder(LogicalDevice)
{
    LogicalDevice device;
    VkQueue graphicsQueue;
    VkQueue presentQueue;
    CommandPool!LogicalDevice commandPool;
    TransferBuffer!LogicalDevice uniformBuffer;

    this(LogicalDevice dev, VkFormat imageFormat, VkQueue graphics, VkQueue present)
    {
        device = dev;
        graphicsQueue = graphics;
        presentQueue = present;

        commandPool = device.createCommandPool();

        // FIXME: bad idea to allocate a memory buffer only for one uniform buffer,
        // need to allocate more memory then divide it into pieces
        uniformBuffer = device.create!TransferBuffer(UniformBufferObject.sizeof, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
    }

    ~this()
    {
        destroy(uniformBuffer);
        destroy(commandPool);
    }
}
