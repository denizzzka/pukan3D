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
    //~ glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

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

    auto vertShader = device.loadShader("vert.spv");
    scope(exit) destroy(vertShader);
    auto fragShader = device.loadShader("frag.spv");
    scope(exit) destroy(fragShader);

    auto cmdPool = device.createCommandPool();
    scope(exit) destroy(cmdPool);

    import pukan.vulkan.bindings;
    import pukan.vulkan.helpers;

    auto shaderStages = [
        vertShader.createShaderStageInfo(VK_SHADER_STAGE_VERTEX_BIT),
        fragShader.createShaderStageInfo(VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

    import pukan.vulkan.defaults;

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

    auto graphicsPipelines = device.create!GraphicsPipelines([pipelineInfo]);
    scope(exit) destroy(graphicsPipelines);

    swapChain.initFramebuffers(renderPass);

    cmdPool.initBuffs(1);
    enforce(cmdPool.commandBuffers.length == 1, "commandBuffers.length="~cmdPool.commandBuffers.length.to!string);

    cmdPool.recordCommandBuffer(swapChain, cmdPool.commandBuffers[0], renderPass, 0, graphicsPipelines.pipelines[0]);

    auto imageAvailable = device.createSemaphore;
    scope(exit) destroy(imageAvailable);
    auto renderFinished = device.createSemaphore;
    scope(exit) destroy(renderFinished);

    auto inFlightFence = device.createFence;
    scope(exit) destroy(inFlightFence);

    void recreateSwapChain()
    {
        destroy(swapChain);
        swapChain = device.createSwapChain(capab);
    }

    import pukan.exceptions;

    // Main loop
    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        // Draw frame:
        vkWaitForFences(device.device, 1, &inFlightFence.fence, VK_TRUE, uint.max).vkCheck;
        vkResetFences(device.device, 1, &inFlightFence.fence).vkCheck;

        uint32_t imageIndex;

        {
            auto ret = vkAcquireNextImageKHR(device.device, swapChain.swapchain, ulong.max, imageAvailable.semaphore, null, &imageIndex);

            if(ret == VK_ERROR_OUT_OF_DATE_KHR)
            {
                recreateSwapChain();
                continue;
            }
            else
            {
                if(ret != VK_SUCCESS && ret != VK_SUBOPTIMAL_KHR)
                    throw new PukanExceptionWithCode(ret, "failed to acquire swap chain image");
            }
        }

        cmdPool.resetBuffer(0);
        cmdPool.recordCommandBuffer(swapChain, cmdPool.commandBuffers[0], renderPass, imageIndex, graphicsPipelines.pipelines[0]);

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

            bool framebufferResized; // unused

            {
                auto ret = vkQueuePresentKHR(presentQueue, &presentInfo);

                if (ret == VK_ERROR_OUT_OF_DATE_KHR || ret == VK_SUBOPTIMAL_KHR || framebufferResized)
                {
                    framebufferResized = false;
                    recreateSwapChain();
                }
                else
                {
                    if(ret != VK_SUCCESS)
                        throw new PukanExceptionWithCode(ret, "failed to acquire swap chain image");
                }
            }
        }
    }

    vkDeviceWaitIdle(device.device);
}
