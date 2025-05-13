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
    CommandPool commandPool;

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
        scope(failure) destroy_DISABLED(renderPass);

        commandPool = device.createCommandPool();
        scope(failure) destroy_DISABLED(commandPool);

        swapChain = new SwapChain(device, commandPool, surface, renderPass, null);
        scope(failure) destroy_DISABLED(swapChain);

        graphicsQueue = device.getQueue();
        presentQueue = device.getQueue();

        frameBuilder = device.create!FrameBuilder(graphicsQueue, presentQueue);
        scope(failure) destroy_DISABLED(frameBuilder);

        vertShader = device.create!ShaderModule("vert.spv");
        scope(failure) destroy_DISABLED(vertShader);

        fragShader = device.create!ShaderModule("frag.spv");
        scope(failure) destroy_DISABLED(fragShader);

        shaderStages = [
            vertShader.createShaderStageInfo(VK_SHADER_STAGE_VERTEX_BIT),
            fragShader.createShaderStageInfo(VK_SHADER_STAGE_FRAGMENT_BIT),
        ];

        // Not used, just for testing:
        //TODO: fix compilation
        //~ vertShader.compileShader(VK_SHADER_STAGE_VERTEX_BIT);
        //~ fragShader.compileShader(VK_SHADER_STAGE_FRAGMENT_BIT);

        descriptorPool = device.create!DescriptorPool(descriptorSetLayoutBindings);
        scope(failure) destroy_DISABLED(descriptorPool);

        pipelineInfoCreator = new DefaultPipelineInfoCreator(device, descriptorPool.descriptorSetLayout, shaderStages);
        scope(failure) destroy_DISABLED(pipelineInfoCreator);

        VkGraphicsPipelineCreateInfo[] infos = [pipelineInfoCreator.pipelineCreateInfo];

        graphicsPipelines = device.create!GraphicsPipelines(infos, renderPass);
        scope(failure) destroy_DISABLED(graphicsPipelines);

        descriptorSets = descriptorPool.allocateDescriptorSets([descriptorPool.descriptorSetLayout]);
    }

    ~this()
    {
        destroy_DISABLED(swapChain);
    }

    void recreateSwapChain()
    {
        swapChain = new SwapChain(device, commandPool, surface, renderPass, swapChain);
    }

    void drawNextFrame(void delegate(ref Frame frame) dg)
    {
        import pukan.exceptions: PukanExceptionWithCode;

        swapChain.currSync.inFlightFence.wait();

        swapChain.oldSwapchainsMaintenance();

        uint imageIndex;

        {
            auto ret = frameBuilder.acquireNextImage(swapChain, imageIndex);

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

        swapChain.currSync.inFlightFence.reset();

        dg(swapChain.frames[imageIndex]);

        {
            frameBuilder.queueSubmit(swapChain);

            auto ret = frameBuilder.queueImageForPresentation(swapChain, imageIndex);

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

        swapChain.toNextFrame();
    }
}
