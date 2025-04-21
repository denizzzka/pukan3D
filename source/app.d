import pukan;
import glfw3.api;
import std.conv: to;
import std.exception;
import std.logger;
import std.stdio;
import std.string: toStringz;

enum fps = 60;
enum width = 640;
enum height = 640;

//~ struct Clock
//~ {
    //~ float start_time;
    //~ float elapsed;
//~ }

//~ Clock getClock()
//~ {
    //~ Clock r;
    //~ r.el
    //~ GetTime
//~ }

// TODO: remove DebugVersion, https://github.com/dlang/phobos/issues/10750
debug version = DebugVersion;
version(DebugVersion)
    static auto getLogger() => stdThreadLocalLog();
else
    static auto getLogger() => MuteLogger();

void main() {
    version(linux)
    version(DigitalMars)
    {
        import etc.linux.memoryerror;
        registerMemoryAssertHandler();
    }

    immutable name = "D/pukan3D/Raylib project";

    enforce(glfwInit());
    scope(exit) glfwTerminate();

    enforce(glfwVulkanSupported());

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

    auto window = glfwCreateWindow(width, height, name.toStringz, null, null);
    enforce(window, "Cannot create a window");

    //~ glfwSetWindowUserPointer(demo.window, demo);
    //~ glfwSetWindowRefreshCallback(demo.window, &demo_refresh_callback);
    //~ glfwSetFramebufferSizeCallback(demo.window, &demo_resize_callback);
    //~ glfwSetKeyCallback(demo.window, &demo_key_callback);

    // Print needed extensions
    uint ext_count;
    const char** extensions = glfwGetRequiredInstanceExtensions(&ext_count);

    writeln("glfw needed extensions:");
    foreach(i; 0 .. ext_count)
        writeln(extensions[i].to!string);

    auto vk = new Backend!(getLogger)(name, makeApiVersion(1,2,3,4), extensions[0 .. ext_count]);
    scope(exit) destroy(vk);

    //~ vk.printAllDevices();
    //~ vk.printAllAvailableLayers();

    debug auto dbg = vk.attachFlightRecorder();
    debug scope(exit) destroy(dbg);

    auto device = vk.createLogicalDevice();
    scope(exit) destroy(device);

    import pukan.vulkan.bindings: VkSurfaceKHR;
    static import glfw3.internal;

    VkSurfaceKHR surface;
    glfwCreateWindowSurface(
        vk.instance,
        window,
        cast(glfw3.internal.VkAllocationCallbacks*) vk.allocator,
        cast(ulong*) &surface
    );

    vk.useSurface(surface);
    vk.printSurfaceFormats(vk.devices[vk.deviceIdx], surface);
    vk.printPresentModes(vk.devices[vk.deviceIdx], surface);

    const capab = vk.getSurfaceCapabilities(vk.devices[vk.deviceIdx], surface);
    capab.toPrettyString.writeln;

    enforce(capab.currentExtent.width != uint.max, "unsupported, see VkSurfaceCapabilitiesKHR(3) Manual Page");

    auto presentQueue = device.getQueue();

    auto swapChain = device.createSwapChain(capab);
    scope(exit) destroy(swapChain);

    auto imgViews = swapChain.createImageViews();
    scope(exit)
        foreach(img; imgViews)
            destroy(img);

    auto vertShader = device.loadShader("vert.spv");
    scope(exit) destroy(vertShader);
    auto fragShader = device.loadShader("frag.spv");
    scope(exit) destroy(fragShader);

    import pukan.vulkan.bindings;
    import pukan.vulkan.helpers;

    auto shaderStages = [
        vertShader.createShaderStageInfo(VK_SHADER_STAGE_VERTEX_BIT),
        fragShader.createShaderStageInfo(VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

    // Non-programmable stages:
    VkPipelineVertexInputStateCreateInfo vertexInputInfo;
    vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    //~ vertexInputInfo.vertexBindingDescriptionCount = 0;
    //~ vertexInputInfo.pVertexBindingDescriptions = null;
    //~ vertexInputInfo.vertexAttributeDescriptionCount = 0;
    //~ vertexInputInfo.pVertexAttributeDescriptions = null;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly;
    inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    inputAssembly.primitiveRestartEnable = VK_FALSE;

    VkViewport viewport;
    viewport.x = 0.0f;
    viewport.y = 0.0f;
    viewport.width = swapChain.imageExtent.width;
    viewport.height = swapChain.imageExtent.height;
    viewport.minDepth = 0.0f;
    viewport.maxDepth = 1.0f;

    VkRect2D scissor;
    scissor.offset = VkOffset2D(0, 0);
    scissor.extent = swapChain.imageExtent;

    VkPipelineViewportStateCreateInfo viewportState;
    viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewportState.viewportCount = 1;
    viewportState.pViewports = &viewport;
    viewportState.scissorCount = 1;
    viewportState.pScissors = &scissor;

    VkPipelineRasterizationStateCreateInfo rasterizer;
    rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterizer.rasterizerDiscardEnable = VK_FALSE;
    rasterizer.depthClampEnable = VK_FALSE;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.lineWidth = 1.0f;
    rasterizer.cullMode = VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE;
    rasterizer.depthBiasEnable = VK_FALSE;
    rasterizer.depthBiasConstantFactor = 0.0f; // Optional
    rasterizer.depthBiasClamp = 0.0f; // Optional
    rasterizer.depthBiasSlopeFactor = 0.0f; // Optional

    VkPipelineMultisampleStateCreateInfo multisampling;
    multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampling.sampleShadingEnable = VK_FALSE;
    multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
    multisampling.minSampleShading = 1.0f; // Optional
    multisampling.pSampleMask = null; // Optional
    multisampling.alphaToCoverageEnable = VK_FALSE; // Optional
    multisampling.alphaToOneEnable = VK_FALSE; // Optional

    VkPipelineColorBlendAttachmentState colorBlendAttachment;
    colorBlendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
    colorBlendAttachment.blendEnable = VK_FALSE;
    colorBlendAttachment.srcColorBlendFactor = VK_BLEND_FACTOR_ONE; // Optional
    colorBlendAttachment.dstColorBlendFactor = VK_BLEND_FACTOR_ZERO; // Optional
    colorBlendAttachment.colorBlendOp = VK_BLEND_OP_ADD; // Optional
    colorBlendAttachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE; // Optional
    colorBlendAttachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO; // Optional
    colorBlendAttachment.alphaBlendOp = VK_BLEND_OP_ADD; // Optional

    VkPipelineColorBlendStateCreateInfo colorBlending;
    colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    colorBlending.logicOpEnable = VK_FALSE;
    colorBlending.logicOp = VK_LOGIC_OP_COPY; // Optional
    colorBlending.attachmentCount = 1;
    colorBlending.pAttachments = &colorBlendAttachment;
    colorBlending.blendConstants[0] = 0.0f; // Optional
    colorBlending.blendConstants[1] = 0.0f; // Optional
    colorBlending.blendConstants[2] = 0.0f; // Optional
    colorBlending.blendConstants[3] = 0.0f; // Optional

    VkDynamicState[] dynamicStates = [
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_SCISSOR,
    ];
    VkPipelineDynamicStateCreateInfo dynamicState;
    dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamicState.dynamicStateCount = cast(uint) dynamicStates.length;
    dynamicState.pDynamicStates = dynamicStates.ptr;

    // pipeline layout can be used to pass uniform vars into shaders

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;
    pipelineLayoutInfo.setLayoutCount = 0; // Optional
    pipelineLayoutInfo.pSetLayouts = null; // Optional
    pipelineLayoutInfo.pushConstantRangeCount = 0; // Optional
    pipelineLayoutInfo.pPushConstantRanges = null; // Optional

    auto pipelineLayout = create(device.device, &pipelineLayoutInfo, vk.allocator);
    scope(exit) destroy(pipelineLayout);

    // ========= Create render pass: =========

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

    scope renderPass = create(device.device, &renderPassInfo, vk.allocator);
    scope(exit) destroy(renderPass);

    VkGraphicsPipelineCreateInfo pipelineInfo;
    pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipelineInfo.stageCount = cast(uint) shaderStages.length;
    pipelineInfo.pStages = shaderStages.ptr;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pDepthStencilState = null; // Optional
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.pDynamicState = &dynamicState;
    pipelineInfo.layout = pipelineLayout;
    pipelineInfo.renderPass = renderPass;
    pipelineInfo.subpass = 0;
    pipelineInfo.basePipelineHandle = null; // Optional
    pipelineInfo.basePipelineIndex = -1; // Optional

    VkPipeline graphicsPipeline;
    vkCreateGraphicsPipelines(device.device, null, 1, &pipelineInfo, null, &graphicsPipeline).vkCheck;
    scope(exit) vkDestroyPipeline(device.device, graphicsPipeline, vk.allocator);

    swapChain.initFramebuffers(imgViews, renderPass);

    auto cmdPool = swapChain.createCommandPool();
    scope(exit) destroy(cmdPool);

    cmdPool.initBuffs(1);
    enforce(cmdPool.commandBuffers.length == 1, "commandBuffers.length="~cmdPool.commandBuffers.length.to!string);

    cmdPool.recordCommandBuffer(cmdPool.commandBuffers[0], renderPass, 0, graphicsPipeline);

    auto imageAvailable = device.createSemaphore;
    scope(exit) destroy(imageAvailable);
    auto renderFinished = device.createSemaphore;
    scope(exit) destroy(renderFinished);

    auto inFlightFence = device.createFence;
    scope(exit) destroy(inFlightFence);

    // Main loop
    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        // Draw frame:
        vkWaitForFences(device.device, 1, &inFlightFence.fence, VK_TRUE, uint.max).vkCheck;
        vkResetFences(device.device, 1, &inFlightFence.fence).vkCheck;

        uint32_t imageIndex;
        vkAcquireNextImageKHR(device.device, swapChain.swapchain, ulong.max, imageAvailable.semaphore, null, &imageIndex);

        cmdPool.resetBuffer(0);
        cmdPool.recordCommandBuffer(cmdPool.commandBuffers[0], renderPass, imageIndex, graphicsPipeline);

        {
            VkSubmitInfo submitInfo;
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;

            auto waitSemaphores = [imageAvailable.semaphore];
            submitInfo.waitSemaphoreCount = cast(uint) waitSemaphores.length;
            submitInfo.pWaitSemaphores = waitSemaphores.ptr;

            auto waitStages = cast(uint) VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            submitInfo.pWaitDstStageMask = &waitStages;

            submitInfo.commandBufferCount = cast(uint) cmdPool.commandBuffers.length;
            submitInfo.pCommandBuffers = &cmdPool.commandBuffers[0];

            auto signalSemaphores = [renderFinished.semaphore];
            submitInfo.signalSemaphoreCount = cast(uint) signalSemaphores.length;
            submitInfo.pSignalSemaphores = signalSemaphores.ptr;

            vkQueueSubmit(device.getQueue(), 1, &submitInfo, inFlightFence.fence).vkCheck("failed to submit draw command buffer");

            VkPresentInfoKHR presentInfo;
            presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;

            presentInfo.waitSemaphoreCount = cast(uint) signalSemaphores.length;
            presentInfo.pWaitSemaphores = signalSemaphores.ptr;

            auto swapChains = [swapChain.swapchain];
            presentInfo.swapchainCount = cast(uint) swapChains.length;
            presentInfo.pSwapchains = swapChains.ptr;

            presentInfo.pImageIndices = &imageIndex;

            vkQueuePresentKHR(presentQueue, &presentInfo);
        }
    }

    vkDeviceWaitIdle(device.device);
}
