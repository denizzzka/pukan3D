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

    this(LogicalDevice dev, VkQueue graphics, VkQueue present)
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

class Frame(LogicalDevice)
{
    LogicalDevice device; //TODO: remove
    VkImageView imageView;
    Depth!LogicalDevice depthBuf;
    VkFramebuffer frameBuffer;

    this(LogicalDevice dev, VkImage image, VkExtent2D imageExtent, VkFormat imageFormat, VkRenderPass renderPass)
    {
        device = dev;

        createImageView(imageView, device, imageFormat, image);
        depthBuf = Depth!LogicalDevice(device, imageExtent);

        {
            VkImageView[2] attachments = [
                imageView,
                depthBuf.depthView,
            ];

            VkFramebufferCreateInfo frameBufferInfo = {
                sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                renderPass: renderPass,
                attachmentCount: cast(uint) attachments.length,
                pAttachments: attachments.ptr,
                width: imageExtent.width,
                height: imageExtent.height,
                layers: 1,
            };

            vkCreateFramebuffer(device, &frameBufferInfo, device.backend.allocator, &frameBuffer).vkCheck;
        }
    }

    ~this()
    {
        vkDestroyFramebuffer(device, frameBuffer, device.backend.allocator);
        vkDestroyImageView(device, imageView, device.backend.allocator);
    }
}

void createImageView(LogicalDevice)(ref VkImageView imgView, LogicalDevice device, VkFormat imageFormat, VkImage image)
{
    VkImageViewCreateInfo cinf = {
        sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        viewType: VK_IMAGE_VIEW_TYPE_2D,
        format: imageFormat,
        components: VkComponentMapping(
            r: VK_COMPONENT_SWIZZLE_IDENTITY,
            g: VK_COMPONENT_SWIZZLE_IDENTITY,
            b: VK_COMPONENT_SWIZZLE_IDENTITY,
            a: VK_COMPONENT_SWIZZLE_IDENTITY,
        ),
        subresourceRange: VkImageSubresourceRange(
            aspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
            baseMipLevel: 0,
            levelCount: 1,
            baseArrayLayer: 0,
            layerCount: 1,
        ),
        image: image,
    };

    vkCreateImageView(device, &cinf, device.backend.allocator, &imgView).vkCheck;
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
        if(device is null) return;

        vkDestroyImageView(device, depthView, device.backend.allocator);
        destroy(depthImage);
    }

    //TODO: remove
    static auto createNew(LogicalDevice d, VkExtent2D ie)
    {
        return Depth!LogicalDevice(d, ie);
    }
}

abstract class RenderPass
{
    VkRenderPass vkRenderPass;
    alias this = vkRenderPass;

    VkFormat imageFormat;
}

class DefaultRenderPass(LogicalDevice) : RenderPass
{
    LogicalDevice device;
    enum VkFormat depthFormat = Depth!LogicalDevice.format;

    this(LogicalDevice dev, VkFormat imageFormat)
    {
        device = dev;
        this.imageFormat = imageFormat;

        VkAttachmentDescription colorAttachment = defaultColorAttachment;
        colorAttachment.format = imageFormat;

        VkAttachmentReference colorAttachmentRef = {
            attachment: 0,
            layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        };

        VkAttachmentDescription depthAttachment = defaultDepthAttachment;
        depthAttachment.format = depthFormat;

        VkAttachmentReference depthAttachmentRef = {
            layout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            attachment: 1,
        };

        auto attachments = [
            colorAttachment,
            depthAttachment,
        ];

        VkSubpassDescription subpass = {
            pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
            colorAttachmentCount: 1,
            pColorAttachments: &colorAttachmentRef,
            pDepthStencilAttachment: &depthAttachmentRef,
        };

        VkSubpassDependency dependency = defaultSubpassDependency;

        VkRenderPassCreateInfo renderPassInfo;
        renderPassInfo.attachmentCount = cast(uint) attachments.length;
        renderPassInfo.pAttachments = attachments.ptr;
        renderPassInfo.subpassCount = 1;
        renderPassInfo.pSubpasses = &subpass;
        renderPassInfo.dependencyCount = 1;
        renderPassInfo.pDependencies = &dependency;

        vkCall(device, &renderPassInfo, device.backend.allocator, &vkRenderPass);
    }

    ~this()
    {
        vkDestroyRenderPass(device, vkRenderPass, device.backend.allocator);
    }

    enum VkAttachmentDescription defaultColorAttachment = {
        samples: VK_SAMPLE_COUNT_1_BIT,
        loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    enum VkAttachmentDescription defaultDepthAttachment = {
        samples: VK_SAMPLE_COUNT_1_BIT,
        loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    enum VkSubpassDependency defaultSubpassDependency = {
        srcSubpass: VK_SUBPASS_EXTERNAL,
        dstSubpass: 0,
        srcStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        srcAccessMask: 0,
        dstStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        dstAccessMask: VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
    };
}
