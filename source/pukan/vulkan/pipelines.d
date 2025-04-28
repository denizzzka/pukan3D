module pukan.vulkan.pipelines;

import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;
//~ import pukan.exceptions;
//~ import std.file: read;
//~ import std.exception: enforce;

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

    this(LogicalDevice dev, VkGraphicsPipelineCreateInfo[] infos, VkFormat imageFormat)
    {
        super(dev);

        renderPass = createRenderPass(device, imageFormat);

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
