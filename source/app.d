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

    auto device = vk.createLogicalDevice();
    scope(exit) destroy(device);

    debug auto dbg = vk.attachFlightRecorder();
    debug scope(exit) destroy(dbg);

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

    auto swapChain = new SwapChain!(typeof(device))(device, surface);
    scope(exit) destroy(swapChain);

    auto graphicsQueue = device.getQueue();
    auto presentQueue = device.getQueue();

    auto vertShader = device.loadShader("vert.spv");
    scope(exit) destroy(vertShader);
    auto fragShader = device.loadShader("frag.spv");
    scope(exit) destroy(fragShader);

    import pukan.vulkan.bindings;

    // Not used, just for testing:
    vertShader.compileShader(VK_SHADER_STAGE_VERTEX_BIT);
    fragShader.compileShader(VK_SHADER_STAGE_FRAGMENT_BIT);

    auto frameBuilder = device.create!FrameBuilder(swapChain.imageFormat, graphicsQueue, presentQueue);
    scope(exit) destroy(frameBuilder);

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

    auto bindingDescriptions = [Vertex.getBindingDescription];
    auto attributeDescriptions = Vertex.getAttributeDescriptions;

    VkPipelineVertexInputStateCreateInfo vertexInputInfo = {
        sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount: cast(uint) bindingDescriptions.length,
        pVertexBindingDescriptions: bindingDescriptions.ptr,
        vertexAttributeDescriptionCount: cast(uint) attributeDescriptions.length,
        pVertexAttributeDescriptions: attributeDescriptions.ptr,
    };

    auto pipelineLayout = createPipelineLayout(device);
    scope(exit) vkDestroyPipelineLayout(device, pipelineLayout, device.backend.allocator);

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
    pipelineInfo.subpass = 0;
    pipelineInfo.basePipelineHandle = null; // Optional
    pipelineInfo.basePipelineIndex = -1; // Optional

    auto graphicsPipelines = device.create!GraphicsPipelines([pipelineInfo], swapChain.imageFormat);
    scope(exit) destroy(graphicsPipelines);

    swapChain.initFramebuffers(graphicsPipelines.renderPass);

    void recreateSwapChain()
    {
        vkDeviceWaitIdle(device.device);
        destroy(swapChain);
        swapChain = new SwapChain!(typeof(device))(device, surface);
        swapChain.initFramebuffers(graphicsPipelines.renderPass);
    }

    auto vertexBuffer = device.create!TransferBuffer(Vertex.sizeof * vertices.length, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
    scope(exit) destroy(vertexBuffer);

    auto indicesBuffer = device.create!TransferBuffer(ushort.sizeof * indices.length, VK_BUFFER_USAGE_INDEX_BUFFER_BIT);
    scope(exit) destroy(indicesBuffer);

    // Copy vertices to mapped memory
    vertexBuffer.localBuf[0..$] = cast(void[]) vertices;
    indicesBuffer.localBuf[0..$] = cast(void[]) indices;

    vertexBuffer.upload(frameBuilder.commandPool);
    indicesBuffer.upload(frameBuilder.commandPool);

    auto imageAvailable = device.createSemaphore;
    scope(exit) destroy(imageAvailable);
    auto renderFinished = device.createSemaphore;
    scope(exit) destroy(renderFinished);

    auto inFlightFence = device.createFence;
    scope(exit) destroy(inFlightFence);

    void recreateSwapChainWithNewWindowSize()
    {
        int width;
        int height;

        glfwGetFramebufferSize(window, &width, &height);

        while (width == 0 || height == 0)
        {
            /*
            TODO: I don't understand this logic, but it allowed to
            overcome refresh freezes when increasing the window size.
            Perhaps this code does not work as it should, but it is
            shown in this form in different articles.
            */

            glfwGetFramebufferSize(window, &width, &height);
            glfwWaitEvents();
        }

        recreateSwapChain();
    }

    import pukan.exceptions;

    // Main loop
    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        // Draw frame:
        vkWaitForFences(device.device, 1, &inFlightFence.fence, VK_TRUE, uint.max).vkCheck;

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

        vkResetFences(device.device, 1, &inFlightFence.fence).vkCheck;

        frameBuilder.commandPool.resetBuffer(0);
        frameBuilder.commandPool.recordCommandBuffer(
            swapChain,
            frameBuilder.commandPool.commandBuffers[0],
            graphicsPipelines.renderPass,
            imageIndex,
            vertexBuffer.gpuBuffer.buf,
            indicesBuffer.gpuBuffer.buf,
            cast(uint) indices.length,
            graphicsPipelines.pipelines[0]
        );

        {
            VkSubmitInfo submitInfo;
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;

            auto waitSemaphores = [imageAvailable.semaphore];
            submitInfo.waitSemaphoreCount = cast(uint) waitSemaphores.length;
            submitInfo.pWaitSemaphores = waitSemaphores.ptr;

            auto waitStages = cast(uint) VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            submitInfo.pWaitDstStageMask = &waitStages;

            submitInfo.commandBufferCount = 1;
            submitInfo.pCommandBuffers = &frameBuilder.commandPool.commandBuffers[0];

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

            glfwWaitEventsTimeout(0.3);
            static size_t frameNum;
            frameNum++;
            writeln("frame: ", frameNum);

            {
                auto ret = vkQueuePresentKHR(presentQueue, &presentInfo);

                if (ret == VK_ERROR_OUT_OF_DATE_KHR || ret == VK_SUBOPTIMAL_KHR || framebufferResized)
                {
                    framebufferResized = false;
                    recreateSwapChainWithNewWindowSize();
                    continue;
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
