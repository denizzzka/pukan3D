module pukan.scene;

import pukan;
import pukan.vulkan;
import pukan.vulkan.bindings;

class Scene
{
    LogicalDevice device;
    VkSurfaceKHR surface;

    alias WindowSizeChangeDetectedCallback = void delegate();
    WindowSizeChangeDetectedCallback windowSizeChanged;

    SwapChain swapChain;
    FrameBuilder frameBuilder;
    DefaultRenderPass renderPass; //TODO: replace by RenderPass base?

    VkQueue graphicsQueue;
    VkQueue presentQueue;

    ShaderModule vertShader;
    ShaderModule fragShader;
    VkPipelineShaderStageCreateInfo[] shaderStages;

    DescriptorPool descriptorPool;
    VkDescriptorSet[] descriptorSets;

    DefaultPipelineInfoCreator pipelineInfoCreator;
    GraphicsPipelines graphicsPipelines;

    this(LogicalDevice dev, VkSurfaceKHR surf, VkDescriptorSetLayoutBinding[] descriptorSetLayoutBindings, WindowSizeChangeDetectedCallback wsc)
    {
        device = dev;
        surface = surf;
        windowSizeChanged = wsc;

        device.backend.useSurface(surface);

        renderPass = device.create!DefaultRenderPass(VK_FORMAT_B8G8R8A8_SRGB);
        scope(failure) destroy(renderPass);

        swapChain = new SwapChain(device, surface, renderPass);
        scope(failure) destroy(swapChain);

        graphicsQueue = device.getQueue();
        presentQueue = device.getQueue();

        frameBuilder = device.create!FrameBuilder(graphicsQueue, presentQueue);
        scope(failure) destroy(frameBuilder);

        {
            vertShader = device.loadShader("vert.spv");
            scope(failure) destroy(vertShader);

            fragShader = device.loadShader("frag.spv");
            scope(failure) destroy(fragShader);

            shaderStages = [
                vertShader.createShaderStageInfo(VK_SHADER_STAGE_VERTEX_BIT),
                fragShader.createShaderStageInfo(VK_SHADER_STAGE_FRAGMENT_BIT),
            ];
        }

        // Not used, just for testing:
        //TODO: fix compilation
        //~ vertShader.compileShader(VK_SHADER_STAGE_VERTEX_BIT);
        //~ fragShader.compileShader(VK_SHADER_STAGE_FRAGMENT_BIT);

        descriptorPool = device.create!DescriptorPool(descriptorSetLayoutBindings);
        scope(failure) destroy(descriptorPool);

        pipelineInfoCreator = new DefaultPipelineInfoCreator(device, descriptorPool.descriptorSetLayout, shaderStages);
        scope(failure) destroy(pipelineInfoCreator);

        VkGraphicsPipelineCreateInfo[] infos = [pipelineInfoCreator.pipelineCreateInfo];

        graphicsPipelines = device.create!GraphicsPipelines(infos, renderPass);
        scope(failure) destroy(graphicsPipelines);

        descriptorSets = descriptorPool.allocateDescriptorSets([descriptorPool.descriptorSetLayout]);
    }

    void recreateSwapChain()
    {
        vkDeviceWaitIdle(device);
        destroy(swapChain);
        swapChain = new SwapChain(device, surface, renderPass);
    }

    void drawNextFrame(void delegate(SwapChain.FrameIns currFrame) dg)
    {
        import pukan.exceptions: PukanExceptionWithCode;

        frameBuilder.inFlightFence.wait();

        {
            auto ret = frameBuilder.acquireNextImage(swapChain.swapchain);

            if(ret == VK_ERROR_OUT_OF_DATE_KHR)
            {
                recreateSwapChain();
                return;
            }
            else
            {
                if(ret != VK_SUCCESS && ret != VK_SUBOPTIMAL_KHR)
                    throw new PukanExceptionWithCode(ret, "failed to acquire swap chain image");
            }
        }

        frameBuilder.inFlightFence.reset();

        ref currFrame = swapChain.frames[frameBuilder.imageIndex];
        dg(currFrame);

        {
            frameBuilder.queueSubmit();
            auto ret = frameBuilder.queueImageForPresentation(swapChain.swapchain);

            if (ret == VK_ERROR_OUT_OF_DATE_KHR || ret == VK_SUBOPTIMAL_KHR)
            {
                windowSizeChanged();
                recreateSwapChain();
                return;
            }
            else
            {
                if(ret != VK_SUCCESS)
                    throw new PukanExceptionWithCode(ret, "failed to queue image for presentation");
            }
        }
    }
}
