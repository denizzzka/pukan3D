module pukan.vulkan.frame;

//~ import pukan.exceptions;
import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;

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
    VkPipelineLayout pipelineLayout;

    this(LogicalDevice dev, SwapChainFactoryDg scFactoryDg, VkQueue graphics, VkQueue present)
    {
        device = dev;
        createSwapChain = scFactoryDg;
        swapChain = createSwapChain();
        graphicsQueue = graphics;
        presentQueue = present;

        commandPool = device.createCommandPool();
        commandPool.initBuffs(1);

        renderPass = createRenderPass(device, swapChain.imageFormat);

        swapChain.initFramebuffers(renderPass);

        // pipeline layout can be used to pass uniform vars into shaders
        VkPipelineLayoutCreateInfo pipelineLayoutCreateInfo = {
            setLayoutCount: 0, // Optional
            pSetLayouts: null, // Optional
            pushConstantRangeCount: 0, // Optional
            pPushConstantRanges: null, // Optional
        };

        vkCall(device, &pipelineLayoutCreateInfo, device.backend.allocator, &pipelineLayout);
    }

    ~this()
    {
        vkDestroyPipelineLayout(device, pipelineLayout, device.backend.allocator);
        vkDestroyRenderPass(device, renderPass, device.backend.allocator);
        destroy(commandPool);
        destroy(swapChain);
    }

    void recreateSwapChain()
    {
        vkDeviceWaitIdle(device.device);
        destroy(swapChain);
        swapChain = createSwapChain();
        swapChain.initFramebuffers(renderPass);
    }

    //~ void resize
    //~ draw(render_packet)
}

VkRenderPass createRenderPass(LogicalDevice)(LogicalDevice device, VkFormat imageFormat)
{
    VkAttachmentDescription colorAttachment;
    colorAttachment.format = imageFormat;
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

    VkRenderPass ret;
    vkCall(device.device, &renderPassInfo, device.backend.allocator, &ret);

    return ret;
}
