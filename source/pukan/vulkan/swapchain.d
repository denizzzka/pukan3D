module pukan.vulkan.swapchain;

import pukan.vulkan;
import pukan.vulkan.bindings;

class SwapChain(LogicalDevice)
{
    LogicalDevice device;
    VkSwapchainKHR swapchain;
    VkImage[] images;
    VkFormat imageFormat;
    VkExtent2D imageExtent;
    VkFramebuffer[] frameBuffers;

    this(LogicalDevice d, VkSwapchainCreateInfoKHR cinf)
    {
        device = d;
        imageFormat = cinf.imageFormat;
        imageExtent = cinf.imageExtent;

        vkCreateSwapchainKHR(d.device, &cinf, d.backend.allocator, &swapchain).vkCheck;

        images = getArrayFrom!vkGetSwapchainImagesKHR(device.device, swapchain);
    }

    ~this()
    {
        foreach(ref fb; frameBuffers)
            vkDestroyFramebuffer(device.device, fb, device.backend.allocator);

        vkDestroySwapchainKHR(device.device, swapchain, device.backend.allocator);
    }

    alias ImgView = ImageView!SwapChain;

    auto createImageViews()
    {
        auto ret = new ImgView[images.length];

        foreach(i, img; images)
        {
            ret[i] = new ImgView(this, img);
        }

        return ret;
    }

    void initFramebuffers(ImgView[] imageViews, VkRenderPass renderPass)
    {
        assert(imageViews.length == images.length);

        frameBuffers.length = images.length;

        foreach(i, ref fb; frameBuffers)
        {
            VkFramebufferCreateInfo framebufferInfo;
            framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            framebufferInfo.renderPass = renderPass;
            framebufferInfo.attachmentCount = 1;
            framebufferInfo.pAttachments = &imageViews[i].imgView;
            framebufferInfo.width = imageExtent.width;
            framebufferInfo.height = imageExtent.height;
            framebufferInfo.layers = 1;

            vkCreateFramebuffer(device.device, &framebufferInfo, device.backend.allocator, &fb).vkCheck;
        }
    }

    auto createCommandPool()
    {
        return new CommandPool!SwapChain(this, device.familyIdx);
    }
}

class ImageView(SwapChain)
{
    SwapChain swapchain;
    VkImageView imgView;

    this(SwapChain sc, VkImage img)
    {
        swapchain = sc;

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

    ~this()
    {
        vkDestroyImageView(swapchain.device.device, imgView, swapchain.device.backend.allocator);
    }
}
