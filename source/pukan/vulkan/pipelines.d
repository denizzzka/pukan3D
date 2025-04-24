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
    this(LogicalDevice dev, VkGraphicsPipelineCreateInfo[] infos)
    {
        super(dev);

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
}

auto createPipelineLayout(LogicalDevice)(LogicalDevice device)
{
    // pipeline layout can be used to pass uniform vars into shaders
    VkPipelineLayoutCreateInfo pipelineLayoutCreateInfo = {
        setLayoutCount: 0, // Optional
        pSetLayouts: null, // Optional
        pushConstantRangeCount: 0, // Optional
        pPushConstantRanges: null, // Optional
    };

    VkPipelineLayout pipelineLayout;
    vkCall(device, &pipelineLayoutCreateInfo, device.backend.allocator, &pipelineLayout);

    return pipelineLayout;
}
