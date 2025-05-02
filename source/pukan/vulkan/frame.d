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
    Depth!LogicalDevice depth;

    this(LogicalDevice dev, VkFormat imageFormat, VkQueue graphics, VkQueue present, VkExtent2D imageExtent)
    {
        device = dev;
        graphicsQueue = graphics;
        presentQueue = present;

        commandPool = device.createCommandPool();

        // FIXME: bad idea to allocate a memory buffer only for one uniform buffer,
        // need to allocate more memory then divide it into pieces
        uniformBuffer = device.create!TransferBuffer(UniformBufferObject.sizeof, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);

        depth = Depth!LogicalDevice(device, imageExtent);
    }

    ~this()
    {
        destroy(uniformBuffer);
        destroy(commandPool);
    }
}

struct Depth(LogicalDevice)
{
    LogicalDevice device;
    ImageMemory!LogicalDevice depthImage;
    VkImageView depthView;
    //TODO: autodetection need
    enum format = VK_FORMAT_D24_UNORM_S8_UINT;

    this(LogicalDevice dev, VkExtent2D imageExtent)
    {
        device = dev;

        VkImageCreateInfo imageInfo = {
            imageType: VK_IMAGE_TYPE_2D,
            format: format,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            extent: VkExtent3D(imageExtent.width, imageExtent.height, 1),
            mipLevels: 1,
            arrayLayers: 1,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
            usage: VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            samples: VK_SAMPLE_COUNT_1_BIT,
        };

        depthImage = device.create!ImageMemory(imageInfo, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        VkImageViewCreateInfo cinf = {
            sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            viewType: VK_IMAGE_VIEW_TYPE_2D,
            format: format,
            subresourceRange: VkImageSubresourceRange(
                aspectMask: VK_IMAGE_ASPECT_DEPTH_BIT,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1,
            ),
            image: depthImage,
        };

        vkCreateImageView(device, &cinf, device.backend.allocator, &depthView).vkCheck;
    }

    ~this()
    {
        vkDestroyImageView(device, depthView, device.backend.allocator);
        destroy(depthImage);
    }

    //TODO: remove
    static auto createNew(LogicalDevice d, VkExtent2D ie)
    {
        return Depth!LogicalDevice(d, ie);
    }
}
