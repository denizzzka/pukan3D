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

VkPipelineMultisampleStateCreateInfo multisampling = {
    sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    sampleShadingEnable: VK_FALSE,
    rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
    minSampleShading: 1.0f, // Optional
    pSampleMask: null, // Optional
    alphaToCoverageEnable: VK_FALSE, // Optional
    alphaToOneEnable: VK_FALSE, // Optional
};

shared VkPipelineColorBlendAttachmentState colorBlendAttachment = {
    colorWriteMask: VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
    blendEnable: VK_FALSE,
    srcColorBlendFactor: VK_BLEND_FACTOR_ONE, // Optional
    dstColorBlendFactor: VK_BLEND_FACTOR_ZERO, // Optional
    colorBlendOp: VK_BLEND_OP_ADD, // Optional
    srcAlphaBlendFactor: VK_BLEND_FACTOR_ONE, // Optional
    dstAlphaBlendFactor: VK_BLEND_FACTOR_ZERO, // Optional
    alphaBlendOp: VK_BLEND_OP_ADD, // Optional
};

VkPipelineColorBlendStateCreateInfo colorBlending = {
    sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
    logicOpEnable: VK_FALSE,
    logicOp: VK_LOGIC_OP_COPY, // Optional
    attachmentCount: 1,
    pAttachments: &cast(VkPipelineColorBlendAttachmentState) colorBlendAttachment,
    blendConstants: [0.0f, 0.0f, 0.0f, 0.0f], // Optional
};
