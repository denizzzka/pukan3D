module pukan.vulkan.swapchain;

import pukan.vulkan;
import pukan.vulkan.bindings;
import std.exception: enforce;

class SwapChain
{
    LogicalDevice device;
    VkSwapchainKHR swapchain;
    SwapChain oldSwapChain;
    VkImage[] images;
    VkFormat imageFormat;
    VkExtent2D imageExtent;
    Frame[] frames; //TODO: rename to frameBuffers
    enum maxFramesInFlight = 2; // not same as frames.length
    SyncFramesInFlight[maxFramesInFlight] syncPrimitives;
    int currentFrameSyncIdx;

    private ubyte framesSinceSwapchainReplacement = 0;

    this(LogicalDevice device, VkSurfaceKHR surface, RenderPass renderPass, SwapChain old)
    {
        auto ref ins = device.backend;

        const capab = ins.getSurfaceCapabilities(ins.devices[ins.deviceIdx], surface);

        this(device, capab, renderPass, old);
    }

    this(LogicalDevice device, VkSurfaceCapabilitiesKHR capabilities, RenderPass renderPass, SwapChain old)
    {
        import std.conv: to;

        ref cap = capabilities;

        enforce(cap.currentExtent.width != uint.max, "unsupported, see VkSurfaceCapabilitiesKHR(3) Manual Page");
        enforce(cap.minImageCount > 0);
        enforce(cap.maxImageCount == 0 || cap.maxImageCount >= 3, "maxImageCount: "~cap.maxImageCount.to!string);

        VkSwapchainCreateInfoKHR cinf = {
            sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            surface: device.backend.surface,
            imageFormat: renderPass.imageFormat,
            imageColorSpace: VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            imageExtent: capabilities.currentExtent,
            imageArrayLayers: 1, // number of views in a multiview/stereo surface. For non-stereoscopic-3D applications, this value is 1
            imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, // specifies that the image can be used to create a VkImageView suitable for use as a color or resolve attachment in a VkFramebuffer
            imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
            presentMode: VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR,
            minImageCount: 3, // triple buffering will be used
            preTransform: capabilities.currentTransform,
            compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            clipped: VK_TRUE,
            oldSwapchain: (old is null) ? null : old.swapchain,
        };

        this(device, cinf, renderPass, old);
    }

    this(LogicalDevice d, VkSwapchainCreateInfoKHR cinf, RenderPass renderPass, SwapChain old)
    {
        device = d;
        oldSwapChain = old;
        imageFormat = cinf.imageFormat;
        imageExtent = cinf.imageExtent;

        debug
        {
            if(old is null)
                assert(cinf.oldSwapchain is null);
            else
                assert(old.swapchain == cinf.oldSwapchain);
        }

        vkCreateSwapchainKHR(d.device, &cinf, d.backend.allocator, &swapchain).vkCheck;

        images = getArrayFrom!vkGetSwapchainImagesKHR(device.device, swapchain);
        enforce(images.length >= 3);

        frames.length = images.length;

        foreach(i, ref frame; frames)
            frame = new Frame(device, images[i], imageExtent, imageFormat, renderPass);

        syncPrimitives = new SyncFramesInFlight(device);
    }

    ~this()
    {
        destroy(oldSwapChain);

        foreach(ref frame; frames)
            destroy(frame);

        if(swapchain)
            vkDestroySwapchainKHR(device.device, swapchain, device.backend.allocator);
    }

    auto ref currSync()
    {
        return syncPrimitives[currentFrameSyncIdx];
    }

    void toNextFrame()
    {
        currentFrameSyncIdx = (currentFrameSyncIdx + 1) % maxFramesInFlight;
    }

    void oldSwapchainsMaintenance()
    {
        enum framesToOldSwapchainsDestory = 30;

        if(oldSwapChain !is null)
        {
            if(framesSinceSwapchainReplacement < framesToOldSwapchainsDestory)
                framesSinceSwapchainReplacement++;
            else
            {
                destroy(oldSwapChain);
                oldSwapChain = null;
                framesSinceSwapchainReplacement = 0;
            }
        }
    }
}

class SyncFramesInFlight
{
    Semaphore imageAvailable;
    Semaphore renderFinished;
    Fence inFlightFence;

    VkSemaphore[] waitSemaphores;
    VkSemaphore[] signalSemaphores;

    this(LogicalDevice device)
    {
        imageAvailable = device.create!Semaphore;
        renderFinished = device.create!Semaphore;
        inFlightFence = device.create!Fence;

        waitSemaphores = [imageAvailable.semaphore];
        signalSemaphores = [renderFinished.semaphore];
    }
}
