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
    //TODO: make it replaceable
    RenderPass!LogicalDevice vkRenderPass;
    //TODO: remove?
    alias this = vkRenderPass;

    this(LogicalDevice dev, VkGraphicsPipelineCreateInfo[] infos, VkFormat imageFormat, VkFormat depthFormat)
    {
        super(dev);

        vkRenderPass = new RenderPass!LogicalDevice(device, imageFormat, depthFormat);

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
        scope(exit) destroy(vkRenderPass);
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
