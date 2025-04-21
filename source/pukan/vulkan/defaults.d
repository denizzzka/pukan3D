module pukan.vulkan.defaults;

import pukan.vulkan.bindings;

// Non-programmable stages:

VkPipelineVertexInputStateCreateInfo vertexInputInfo = {
    sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    //~ vertexBindingDescriptionCount: 0,
    //~ pVertexBindingDescriptions: null,
    //~ vertexAttributeDescriptionCount: 0,
    //~ pVertexAttributeDescriptions: null,
};

VkPipelineInputAssemblyStateCreateInfo inputAssembly = {
    sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    primitiveRestartEnable: VK_FALSE,
};

VkPipelineRasterizationStateCreateInfo rasterizer = {
    sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    rasterizerDiscardEnable: VK_FALSE,
    depthClampEnable: VK_FALSE,
    polygonMode: VK_POLYGON_MODE_FILL,
    lineWidth: 1.0f,
    cullMode: VK_CULL_MODE_BACK_BIT,
    frontFace: VK_FRONT_FACE_CLOCKWISE,
    depthBiasEnable: VK_FALSE,
    depthBiasConstantFactor: 0.0f, // Optional
    depthBiasClamp: 0.0f, // Optional
    depthBiasSlopeFactor: 0.0f, // Optional
};
