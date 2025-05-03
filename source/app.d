import pukan;
import glfw3.api;
import std.conv: to;
import std.datetime.stopwatch;
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

    immutable name = "D/pukan3D/GLFW project";

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

    import pukan.vulkan.bindings;

    /*FIXME: RenderPass*/ auto renderPass = device.create!DefaultRenderPass(VK_FORMAT_B8G8R8A8_SRGB);
    scope(exit) destroy(renderPass);

    alias SwapChainImpl = SwapChain!(typeof(device));
    auto swapChain = new SwapChainImpl(device, surface, renderPass);
    scope(exit) destroy(swapChain);

    auto graphicsQueue = device.getQueue();
    auto presentQueue = device.getQueue();

    auto vertShader = device.loadShader("vert.spv");
    scope(exit) destroy(vertShader);
    auto fragShader = device.loadShader("frag.spv");
    scope(exit) destroy(fragShader);

    // Not used, just for testing:
    //TODO: fix compilation
    //~ vertShader.compileShader(VK_SHADER_STAGE_VERTEX_BIT);
    //~ fragShader.compileShader(VK_SHADER_STAGE_FRAGMENT_BIT);

    auto frameBuilder = device.create!FrameBuilder(graphicsQueue, presentQueue);
    scope(exit) destroy(frameBuilder);

    import pukan.vulkan.helpers;

    VkDescriptorSetLayoutBinding uboLayoutBinding = {
        binding: 0,
        descriptorType: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        descriptorCount: 1,
        stageFlags: VK_SHADER_STAGE_VERTEX_BIT,
    };

    VkDescriptorSetLayoutBinding samplerLayoutBinding = {
        binding: 1,
        descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        descriptorCount: 1,
        stageFlags: VK_SHADER_STAGE_FRAGMENT_BIT,
    };

    auto descriptorSetLayoutBindings = [
        uboLayoutBinding,
        samplerLayoutBinding,
    ];

    VkDescriptorSetLayoutCreateInfo descrLayoutCreateInfo = {
        bindingCount: cast(uint) descriptorSetLayoutBindings.length,
        pBindings: descriptorSetLayoutBindings.ptr,
    };

    scope descriptorSetLayout = create(device.device, &descrLayoutCreateInfo, vk.allocator);
    scope(exit) destroy(descriptorSetLayout);

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

    auto pipelineLayout = createPipelineLayout(device, descriptorSetLayout);
    scope(exit) vkDestroyPipelineLayout(device, pipelineLayout, device.backend.allocator);

    VkPipelineDepthStencilStateCreateInfo depthStencil;
    {
        depthStencil.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
        depthStencil.depthTestEnable = VK_TRUE;
        depthStencil.depthWriteEnable = VK_TRUE;
        depthStencil.depthCompareOp = VK_COMPARE_OP_LESS;
        depthStencil.depthBoundsTestEnable = VK_FALSE;
        depthStencil.stencilTestEnable = VK_FALSE;
    }

    VkGraphicsPipelineCreateInfo pipelineInfo;
    pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipelineInfo.stageCount = cast(uint) shaderStages.length;
    pipelineInfo.pStages = shaderStages.ptr;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pDepthStencilState = &depthStencil;

    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.pDynamicState = &dynamicState;
    pipelineInfo.layout = pipelineLayout;
    pipelineInfo.subpass = 0;
    pipelineInfo.basePipelineHandle = null; // Optional
    pipelineInfo.basePipelineIndex = -1; // Optional

    auto graphicsPipelines = device.create!GraphicsPipelines([pipelineInfo], renderPass);
    scope(exit) destroy(graphicsPipelines);

    void recreateSwapChain()
    {
        vkDeviceWaitIdle(device.device);
        destroy(swapChain);
        swapChain = new SwapChain!(typeof(device))(device, surface, renderPass);
    }

    auto vertexBuffer = device.create!TransferBuffer(Vertex.sizeof * vertices.length, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
    scope(exit) destroy(vertexBuffer);

    auto indicesBuffer = device.create!TransferBuffer(ushort.sizeof * indices.length, VK_BUFFER_USAGE_INDEX_BUFFER_BIT);
    scope(exit) destroy(indicesBuffer);

    // Copy vertices to mapped memory
    vertexBuffer.cpuBuf[0..$] = cast(void[]) vertices;
    indicesBuffer.cpuBuf[0..$] = cast(void[]) indices;

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

    //TODO: can be ctored automatically from descriptorSetLayoutBindings?
    VkDescriptorPoolSize[] poolSizes = [
        VkDescriptorPoolSize(
            type: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            descriptorCount: 1, // TODO: one per frame
        ),
        VkDescriptorPoolSize(
            type: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            descriptorCount: 1, // TODO: one per frame
        ),
    ];

    VkDescriptorPoolCreateInfo descriptorPoolInfo = {
        poolSizeCount: cast(uint) poolSizes.length,
        pPoolSizes: poolSizes.ptr,
        maxSets: 1, // TODO: number of frames
    };

    auto descriptorPool = create(device.device, &descriptorPoolInfo, vk.allocator);
    scope(exit) destroy(descriptorPool);

    VkDescriptorSetLayout[] layouts = [
        descriptorSetLayout.vkObj,
    ];
    VkDescriptorSetAllocateInfo descriptorSetAllocateInfo = {
        sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        descriptorPool: descriptorPool,
        descriptorSetCount: cast(uint) layouts.length,
        pSetLayouts: layouts.ptr,
    };

    VkDescriptorSet[] descriptorSets;
    descriptorSets.length = 1;
    vkAllocateDescriptorSets(device.device, &descriptorSetAllocateInfo, descriptorSets.ptr).vkCheck;

    VkDescriptorBufferInfo bufferInfo = {
        buffer: frameBuilder.uniformBuffer.gpuBuffer,
        offset: 0,
        range: UniformBufferObject.sizeof,
    };

    scope texture = device.create!Texture(frameBuilder.commandPool);
    scope(exit) destroy(texture);

    VkDescriptorImageInfo imageInfo = {
        imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        imageView: texture.imageView,
        sampler: texture.sampler,
    };

    auto descriptorWrites = [
        VkWriteDescriptorSet(
            sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            dstSet: descriptorSets[0 /*TODO: frame number*/],
            dstBinding: 0,
            dstArrayElement: 0,
            descriptorType: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            descriptorCount: 1,
            pBufferInfo: &bufferInfo,
        ),
        VkWriteDescriptorSet(
            sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            dstSet: descriptorSets[0],
            dstBinding: 1, //TODO: fetch this value from layout struct?
            dstArrayElement: 0,
            descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            descriptorCount: 1,
            pImageInfo: &imageInfo,
        )
    ];

    vkUpdateDescriptorSets(device, cast(uint) descriptorWrites.length, descriptorWrites.ptr, 0, null);

    import pukan.exceptions;

    auto sw = StopWatch(AutoStart.yes);

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

        updateUniformBuffer(frameBuilder, sw, swapChain.imageExtent);

        auto ref commandBuffer = frameBuilder.commandPool.buf;

        {
        frameBuilder.commandPool.resetBuffer(0);


        frameBuilder.commandPool.recordCommands((commandBuffer) {
            frameBuilder.uniformBuffer.recordUpload(commandBuffer);

            renderPass.recordCommandBuffer(
                swapChain,
                commandBuffer,
                graphicsPipelines.renderPass,
                imageIndex,
                vertexBuffer.gpuBuffer.buf,
                indicesBuffer.gpuBuffer.buf,
                cast(uint) indices.length,
                descriptorSets,
                pipelineLayout,
                graphicsPipelines.pipelines[0]
            );
        });

        }

        {
            VkSubmitInfo submitInfo;
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;

            auto waitSemaphores = [imageAvailable.semaphore];
            submitInfo.waitSemaphoreCount = cast(uint) waitSemaphores.length;
            submitInfo.pWaitSemaphores = waitSemaphores.ptr;

            auto waitStages = cast(uint) VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            submitInfo.pWaitDstStageMask = &waitStages;

            submitInfo.commandBufferCount = cast(uint) frameBuilder.commandPool.commandBuffers.length;
            submitInfo.pCommandBuffers = frameBuilder.commandPool.commandBuffers.ptr;

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

        {
            import core.thread.osthread: Thread;
            import core.time;

            static size_t frameNum;
            static size_t fps;

            frameNum++;
            writeln("FPS: ", fps, " frame: ", frameNum);

            enum targetFPS = 80;
            enum frameDuration = dur!"nsecs"(1_000_000_000 / targetFPS);
            static Duration prevTime;
            const curr = sw.peek;

            if(prevTime.split!"seconds" != curr.split!"seconds")
            {
                static size_t prevSecondFrameNum;
                fps = frameNum - prevSecondFrameNum;
                prevSecondFrameNum = frameNum;
            }

            auto remaining = frameDuration - (curr - prevTime);

            if(!remaining.isNegative)
                Thread.sleep(remaining);

            prevTime = curr;
        }
    }

    vkDeviceWaitIdle(device.device);
}

void updateUniformBuffer(T, V)(T frameBuilder, ref StopWatch sw, V imageExtent)
{
    const curr = sw.peek.total!"msecs" * 0.001;

    import dlib.math;

    auto rotation = rotationQuaternion(Vector3f(0, 0, 1), 90f.degtorad * curr);

    import std.stdio;
    writeln("rotateion=", rotation);

    static union U {
        UniformBufferObject ubo;
        ubyte[UniformBufferObject.sizeof] binary;
    }

    assert(frameBuilder.uniformBuffer.cpuBuf.length == UniformBufferObject.sizeof);

    U* u = cast(U*) frameBuilder.uniformBuffer.cpuBuf.ptr;
    u.ubo.model = rotation.toMatrix4x4;
    u.ubo.view = lookAtMatrix(
        Vector3f(1, 1, 1), // camera position
        Vector3f(0, 0, 0), // point at which the camera is looking
        Vector3f(0, 0, -1), // upward direction in World coordinates
    );
    u.ubo.proj = perspectiveMatrix(
        45.0f /* FOV */,
        cast(float) imageExtent.width / imageExtent.height,
        0.1f /* zNear */, 10.0f /* zFar */
    );
}
