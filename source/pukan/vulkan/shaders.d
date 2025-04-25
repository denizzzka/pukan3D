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
    VkShaderEXT ext; /// Used by VK_EXT_shader_object
    private void[] data;

    this(LogicalDevice dev, string filename)
    {
        device = dev;

        data = read(filename);

        enforce!PukanException(data.length % 4 == 0, "SPIR-V code size must be a multiple of 4");

        const code = cast(uint[]) data;

        VkShaderModuleCreateInfo cinf = {
            sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            codeSize: data.length,
            pCode: code.ptr,
        };

        vkCreateShaderModule(dev.device, &cinf, dev.backend.allocator, &shaderModule).vkCheck;
    }

    /// VK_EXT_shader_object extension
    void compileShader(VkShaderStageFlagBits stage)
    {
        auto vkCreateShadersEXT = cast(PFN_vkCreateShadersEXT) vkGetInstanceProcAddr(device.backend.instance, "vkCreateShadersEXT");

        const code = cast(uint[]) data;

        VkShaderCreateInfoEXT createInfoEXT = {
            sType: VK_STRUCTURE_TYPE_SHADER_CREATE_INFO_EXT,
            codeType: VK_SHADER_CODE_TYPE_SPIRV_EXT,
            codeSize: data.length,
            pCode: code.ptr,
            pName: "main",
            stage: stage,
        };

        vkCreateShadersEXT(device, 1, &createInfoEXT, device.backend.allocator, &ext).vkCheck;
    }

    ~this()
    {
        auto vkDestroyShaderEXT = cast(PFN_vkDestroyShaderEXT) vkGetInstanceProcAddr(device.backend.instance, "vkDestroyShaderEXT");
        vkDestroyShaderEXT(device, ext, device.backend.allocator);

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

import dlib.math.vector;

struct Vertex {
    Vector2f pos;
    Vector3f color;

    static auto getBindingDescription() {
        VkVertexInputBindingDescription r = {
            binding: 0,
            stride: this.sizeof,
            inputRate: VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return r;
    }

    static auto getAttributeDescriptions()
    {
        VkVertexInputAttributeDescription[2] ad;

        ad[0] = VkVertexInputAttributeDescription(
            binding: 0,
            location: 0,
            format: VK_FORMAT_R32G32_SFLOAT,
            offset: pos.offsetof,
        );

        ad[1] = VkVertexInputAttributeDescription(
            binding: 0,
            location: 1,
            format: VK_FORMAT_R32G32B32_SFLOAT,
            offset: color.offsetof,
        );

        return ad;
    }
};

const Vertex[] vertices = [
    Vertex(Vector2f(0.0f, -0.5f), Vector3f(1.0f, 0.0f, 0.0f)),
    Vertex(Vector2f(0.5f, 0.5f), Vector3f(0.0f, 1.0f, 0.0f)),
    Vertex(Vector2f(-0.5f, 0.5f), Vector3f(0.0f, 0.0f, 1.0f)),
];
