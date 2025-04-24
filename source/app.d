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

    auto createSwapChain()
    {
        writeln("createSwapChain called");

        const capab = vk.getSurfaceCapabilities(vk.devices[vk.deviceIdx], surface);
        capab.toPrettyString.writeln;

        enforce(capab.currentExtent.width != uint.max, "unsupported, see VkSurfaceCapabilitiesKHR(3) Manual Page");

        return device.createSwapChain(capab);
    }

    auto graphicsQueue = device.getQueue();
    auto presentQueue = device.getQueue();

    auto vertShader = device.loadShader("vert.spv");
    scope(exit) destroy(vertShader);
    auto fragShader = device.loadShader("frag.spv");
    scope(exit) destroy(fragShader);

    auto cmdPool = device.createCommandPool();
    scope(exit) destroy(cmdPool);

    auto frame = device.create!Frame(&createSwapChain, graphicsQueue, presentQueue);
    scope(exit) destroy(frame);

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
    viewport.width = frame.swapChain.imageExtent.width;
    viewport.height = frame.swapChain.imageExtent.height;
    viewport.minDepth = 0.0f;
    viewport.maxDepth = 1.0f;

    VkRect2D scissor;
    scissor.offset = VkOffset2D(0, 0);
    scissor.extent = frame.swapChain.imageExtent;

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
    pipelineInfo.layout = frame.pipelineLayout;
    pipelineInfo.renderPass = frame.renderPass;
    pipelineInfo.subpass = 0;
    pipelineInfo.basePipelineHandle = null; // Optional
    pipelineInfo.basePipelineIndex = -1; // Optional

    auto graphicsPipelines = device.create!GraphicsPipelines([pipelineInfo]);
    scope(exit) destroy(graphicsPipelines);

    cmdPool.initBuffs(2);
    enforce(cmdPool.commandBuffers.length == 2, "commandBuffers.length="~cmdPool.commandBuffers.length.to!string);

    // Vertex buff allocation

    VkBufferCreateInfo stagingBufInfo = {
        size: Vertex.sizeof * vertices.length,
        usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        sharingMode: VK_SHARING_MODE_EXCLUSIVE,
    };

    auto stagingBuffer = device.create!MemoryBuffer(stagingBufInfo, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    scope(exit) destroy(stagingBuffer);

    VkBufferCreateInfo vertexBufInfo = {
        size: Vertex.sizeof * vertices.length,
        usage: VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        sharingMode: VK_SHARING_MODE_EXCLUSIVE,
    };

    auto vertexBuffer = device.create!MemoryBuffer(vertexBufInfo, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    scope(exit) destroy(vertexBuffer);

    {
        Vertex* data;
        vkMapMemory(device.device, stagingBuffer.deviceMemory, 0 /*offset*/, stagingBufInfo.size, 0 /*flags*/, cast(void**) &data);
        scope(exit) vkUnmapMemory(device.device, stagingBuffer.deviceMemory);

        // Copy data to mapped memory
        data[0 .. vertices.length] = vertices[0 .. $];

        // Copy host RAM buffer to GPU RAM
        vertexBuffer.copyBuffer(cmdPool.commandBuffers[1], stagingBuffer.buf, vertexBuffer.buf, stagingBufInfo.size);
    }

    auto imageAvailable = device.createSemaphore;
    scope(exit) destroy(imageAvailable);
    auto renderFinished = device.createSemaphore;
    scope(exit) destroy(renderFinished);

    auto inFlightFence = device.createFence;
    scope(exit) destroy(inFlightFence);

    void recreateSwapChain()
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

        frame.recreateSwapChain();
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
            auto ret = vkAcquireNextImageKHR(device.device, frame.swapChain.swapchain, ulong.max, imageAvailable.semaphore, null, &imageIndex);

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

        cmdPool.resetBuffer(0);
        cmdPool.recordCommandBuffer(frame.swapChain, cmdPool.commandBuffers[0], frame.renderPass, imageIndex, vertexBuffer.buf, graphicsPipelines.pipelines[0]);

        {
            VkSubmitInfo submitInfo;
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;

            auto waitSemaphores = [imageAvailable.semaphore];
            submitInfo.waitSemaphoreCount = cast(uint) waitSemaphores.length;
            submitInfo.pWaitSemaphores = waitSemaphores.ptr;

            auto waitStages = cast(uint) VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            submitInfo.pWaitDstStageMask = &waitStages;

            submitInfo.commandBufferCount = 1;
            submitInfo.pCommandBuffers = &cmdPool.commandBuffers[0];

            auto signalSemaphores = [renderFinished.semaphore];
            submitInfo.signalSemaphoreCount = cast(uint) signalSemaphores.length;
            submitInfo.pSignalSemaphores = signalSemaphores.ptr;

            vkQueueSubmit(device.getQueue(), 1, &submitInfo, inFlightFence.fence).vkCheck("failed to submit draw command buffer");

            VkPresentInfoKHR presentInfo;
            presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;

            presentInfo.waitSemaphoreCount = cast(uint) signalSemaphores.length;
            presentInfo.pWaitSemaphores = signalSemaphores.ptr;

            auto swapChains = [frame.swapChain.swapchain];
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
                    recreateSwapChain();
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
