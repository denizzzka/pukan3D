module pukan.vulkan.frame;

//~ import pukan.exceptions;
import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;
//~ import pukan: toPrettyString;
//~ import std.exception: enforce;
//~ import std.string: toStringz;

struct FrameSettings
{
}

//TODO: can LogicalDevice be alias to instanced object?
class Frame(LogicalDevice)
{
    alias SwapChainFactoryDg = SwapChain!LogicalDevice delegate();

    LogicalDevice device;
    SwapChainFactoryDg createSwapChain;
    SwapChain!LogicalDevice swapChain;
    VkQueue graphicsQueue;
    VkQueue presentQueue;
    CommandPool!LogicalDevice commandPool;
    VkRenderPass renderPass;

    this(LogicalDevice dev, ref FrameSettings, SwapChainFactoryDg scFactoryDg, VkQueue graphics, VkQueue present)
    {
        device = dev;
        createSwapChain = scFactoryDg;
        swapChain = createSwapChain();
        graphicsQueue = graphics;
        presentQueue = present;

        commandPool = device.createCommandPool();
        commandPool.initBuffs(1);

        renderPass = createRenderPass(swapChain);
    }

    ~this()
    {
        vkDestroyRenderPass(device.device, renderPass, device.backend.allocator); //FIXME: wrong code
        destroy(commandPool);
        destroy(swapChain);
    }

    void recreateSwapChain()
    {
        vkDeviceWaitIdle(device.device);
        destroy(swapChain);
        swapChain = createSwapChain();
        //~ swapChain.initFramebuffers(renderPass);
    }

    //~ void resize
    //~ draw(render_packet)
}

VkRenderPass createRenderPass(S)(S swapChain)
{
    VkAttachmentDescription colorAttachment;
    colorAttachment.format = swapChain.imageFormat;
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    VkAttachmentReference colorAttachmentRef;
    colorAttachmentRef.attachment = 0;
    colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    VkSubpassDescription subpass;
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;

    VkRenderPassCreateInfo renderPassInfo;
    renderPassInfo.attachmentCount = 1;
    renderPassInfo.pAttachments = &colorAttachment;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;

    return create(swapChain.device.device, &renderPassInfo, swapChain.device.backend.allocator);
}
