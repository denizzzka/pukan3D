module pukan.vulkan.swapchain;

import pukan.vulkan;
import pukan.vulkan.bindings;
import std.exception: enforce;

class SwapChain
{
    LogicalDevice device;
    VkSwapchainKHR swapchain;
    VkImage[] images;
    VkFormat imageFormat;
    VkExtent2D imageExtent;
    alias FrameIns = Frame!(LogicalDevice, device);
    FrameIns[] frames;

    this(LogicalDevice device, VkSurfaceKHR surface, RenderPass renderPass)
    {
        auto ref ins = device.backend;

        const capab = ins.getSurfaceCapabilities(ins.devices[ins.deviceIdx], surface);

        this(device, capab, renderPass);
    }

    this(LogicalDevice device, VkSurfaceCapabilitiesKHR capabilities, RenderPass renderPass)
    {
        enforce(capabilities.currentExtent.width != uint.max, "unsupported, see VkSurfaceCapabilitiesKHR(3) Manual Page");

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
            minImageCount: capabilities.minImageCount + 1,
            preTransform: capabilities.currentTransform,
            compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            clipped: VK_TRUE,
        };

        this(device, cinf, renderPass);
    }

    this(LogicalDevice d, VkSwapchainCreateInfoKHR cinf, RenderPass renderPass)
    {
        device = d;
        imageFormat = cinf.imageFormat;
        imageExtent = cinf.imageExtent;

        vkCreateSwapchainKHR(d.device, &cinf, d.backend.allocator, &swapchain).vkCheck;

        images = getArrayFrom!vkGetSwapchainImagesKHR(device.device, swapchain);

        frames.length = images.length;

        foreach(i, ref frame; frames)
            frame = new FrameIns(images[i], imageExtent, imageFormat, renderPass);
    }

    ~this()
    {
        foreach(ref frame; frames)
            destroy(frame);

        vkDestroySwapchainKHR(device.device, swapchain, device.backend.allocator);
    }
}
