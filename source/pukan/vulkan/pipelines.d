module pukan.vulkan.pipelines;

import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;

abstract class Pipelines(LogicalDevice)
{
    LogicalDevice device;
    VkPipeline[] pipelines;
    alias this = pipelines;

    this(LogicalDevice dev)
    {
        device = dev;
    }

    ~this()
    {
        foreach(ref p; pipelines)
            vkDestroyPipeline(device.device, p, device.backend.allocator);
    }
}

class GraphicsPipelines(LogicalDevice) : Pipelines!LogicalDevice
{
    VkRenderPass renderPass;

    this(LogicalDevice dev, VkGraphicsPipelineCreateInfo[] infos, VkFormat imageFormat, VkFormat depthFormat)
    {
        super(dev);

        renderPass = createRenderPass(device, imageFormat, depthFormat);

        foreach(ref inf; infos)
            inf.renderPass = renderPass;

        pipelines.length = infos.length;

        vkCreateGraphicsPipelines(
            device.device,
            null, // pipelineCache
            cast(uint) infos.length,
            infos.ptr,
            device.backend.allocator,
            pipelines.ptr
        ).vkCheck;
    }

    ~this()
    {
        vkDestroyRenderPass(device, renderPass, device.backend.allocator);
    }
}

auto createPipelineLayout(LogicalDevice, DescriptorSetLayout)(LogicalDevice device, DescriptorSetLayout descriptorSetLayout)
{
    // pipeline layout can be used to pass uniform vars into shaders
    VkPipelineLayoutCreateInfo pipelineLayoutCreateInfo = {
        setLayoutCount: 1,
        pSetLayouts: &descriptorSetLayout.vkObj,
        pushConstantRangeCount: 0, // Optional
        pPushConstantRanges: null, // Optional
    };

    VkPipelineLayout pipelineLayout;
    vkCall(device, &pipelineLayoutCreateInfo, device.backend.allocator, &pipelineLayout);

    return pipelineLayout;
}

VkRenderPass createRenderPass(LogicalDevice)(LogicalDevice device, VkFormat imageFormat, VkFormat depthFormat)
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

    VkAttachmentDescription depthAttachment;
    {
        depthAttachment.format = depthFormat;
        depthAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
        depthAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        depthAttachment.storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        depthAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        depthAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        depthAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        depthAttachment.finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
    }

    VkAttachmentReference depthAttachmentRef = {
        layout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        attachment: 1,
    };

    auto attachments = [
        colorAttachment,
        depthAttachment,
    ];

    VkSubpassDescription subpass;
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;
    subpass.pDepthStencilAttachment = &depthAttachmentRef;

    VkSubpassDependency dependency;
    {
        dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
        dependency.dstSubpass = 0;
        dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
        dependency.srcAccessMask = 0;
        dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
        dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    }

    VkRenderPassCreateInfo renderPassInfo;
    renderPassInfo.attachmentCount = cast(uint) attachments.length;
    renderPassInfo.pAttachments = attachments.ptr;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;
    renderPassInfo.dependencyCount = 1;
    renderPassInfo.pDependencies = &dependency;

    VkRenderPass ret;
    vkCall(device.device, &renderPassInfo, device.backend.allocator, &ret);

    return ret;
}
