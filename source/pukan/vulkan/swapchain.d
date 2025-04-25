module pukan.vulkan.swapchain;

import pukan.vulkan;
import pukan.vulkan.bindings;
import std.exception: enforce;

class SwapChain(LogicalDevice)
{
    LogicalDevice device;
    VkSwapchainKHR swapchain;
    VkImage[] images;
    VkFormat imageFormat;
    VkExtent2D imageExtent;
    VkFramebuffer[] frameBuffers;
    VkImageView[] imageViews;

    this(LogicalDevice device, VkSurfaceKHR surface)
    {
        auto ref ins = device.backend;

        const capab = ins.getSurfaceCapabilities(ins.devices[ins.deviceIdx], surface);

        this(device, capab);
    }

    this(LogicalDevice device, VkSurfaceCapabilitiesKHR capabilities)
    {
        enforce(capabilities.currentExtent.width != uint.max, "unsupported, see VkSurfaceCapabilitiesKHR(3) Manual Page");

        VkSwapchainCreateInfoKHR cinf = {
            sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            surface: device.backend.surface,
            imageFormat: VK_FORMAT_B8G8R8A8_SRGB,
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

        this(device, cinf);
    }

    this(LogicalDevice d, VkSwapchainCreateInfoKHR cinf)
    {
        device = d;
        imageFormat = cinf.imageFormat;
        imageExtent = cinf.imageExtent;

        vkCreateSwapchainKHR(d.device, &cinf, d.backend.allocator, &swapchain).vkCheck;

        images = getArrayFrom!vkGetSwapchainImagesKHR(device.device, swapchain);

        createImageViews();
    }

    ~this()
    {
        foreach(ref fb; frameBuffers)
            vkDestroyFramebuffer(device.device, fb, device.backend.allocator);

        destroyImageViews();

        vkDestroySwapchainKHR(device.device, swapchain, device.backend.allocator);
    }

    void createImageViews()
    {
        imageViews.length = images.length;

        foreach(i, ref view; imageViews)
            createImageView(view, this, images[i]);
    }

    void destroyImageViews()
    {
        foreach(ref iv; imageViews)
            vkDestroyImageView(device.device, iv, device.backend.allocator);
    }

    void initFramebuffers(VkRenderPass renderPass)
    {
        assert(imageViews.length == images.length);
        assert(renderPass !is null);

        frameBuffers.length = images.length;

        foreach(i, ref fb; frameBuffers)
        {
            VkFramebufferCreateInfo framebufferInfo;
            framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            framebufferInfo.renderPass = renderPass;
            framebufferInfo.attachmentCount = 1;
            framebufferInfo.pAttachments = &imageViews[i];
            framebufferInfo.width = imageExtent.width;
            framebufferInfo.height = imageExtent.height;
            framebufferInfo.layers = 1;

            vkCreateFramebuffer(device.device, &framebufferInfo, device.backend.allocator, &fb).vkCheck;
        }
    }
}

void createImageView(SwapChain)(ref VkImageView imgView, SwapChain sc, VkImage img)
{
    VkImageViewCreateInfo cinf = {
        sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        viewType: VK_IMAGE_VIEW_TYPE_2D,
        format: sc.imageFormat,
        components: VkComponentMapping(
            r: VK_COMPONENT_SWIZZLE_IDENTITY,
            g: VK_COMPONENT_SWIZZLE_IDENTITY,
            b: VK_COMPONENT_SWIZZLE_IDENTITY,
            a: VK_COMPONENT_SWIZZLE_IDENTITY,
        ),
        subresourceRange: VkImageSubresourceRange(
            aspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
            baseMipLevel: 0,
            levelCount: 1,
            baseArrayLayer: 0,
            layerCount: 1,
        ),
        image: img,
    };

    vkCreateImageView(sc.device.device, &cinf, sc.device.backend.allocator, &imgView).vkCheck;
}
