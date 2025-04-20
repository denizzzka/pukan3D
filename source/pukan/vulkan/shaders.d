module pukan.vulkan.shaders;

import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.exceptions;
import std.file: read;
import std.exception: enforce;

class ShaderModule(LogicalDevice)
{
    LogicalDevice device;
    VkShaderModule shaderModule;

    this(LogicalDevice dev, string filename)
    {
        device = dev;

        const data = read(filename);

        enforce!PukanException(data.length % 4 == 0, "SPIR-V code size must be a multiple of 4");

        const code = cast(uint[]) data;

        VkShaderModuleCreateInfo cinf = {
            sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            codeSize: data.length,
            pCode: code.ptr,
        };

        vkCreateShaderModule(dev.device, &cinf, dev.backend.allocator, &shaderModule).vkCheck;
    }

    ~this()
    {
        vkDestroyShaderModule(device.device, shaderModule, device.backend.allocator);
    }

    auto createShaderStageInfo(VkShaderStageFlagBits stage)
    {
        VkPipelineShaderStageCreateInfo cinf = {
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage: stage,
            pName: "main", // shader entry point
        };

        __traits(getMember, cinf, "module") = shaderModule;

        return cinf;
    }
}
