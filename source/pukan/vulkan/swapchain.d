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
    Frame!LogicalDevice[] frames;

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

        frames.length = images.length;

        foreach(i, ref frame; frames)
            frame = new Frame!LogicalDevice(device, images[i], imageExtent, imageFormat);
    }

    ~this()
    {
        foreach(ref frame; frames)
            destroy(frame);

        foreach(ref fb; frameBuffers)
            vkDestroyFramebuffer(device.device, fb, device.backend.allocator);

        vkDestroySwapchainKHR(device.device, swapchain, device.backend.allocator);
    }

    //TODO: move to FrameBuffer struct (frame module)
    void initFramebuffers(VkRenderPass renderPass, VkImageView depthView)
    {
        assert(frames.length == images.length);
        assert(renderPass !is null);

        frameBuffers.length = frames.length;

        foreach(i, ref fb; frameBuffers)
        {
            VkImageView[2] attachments = [
                frames[i].imageView,
                depthView, //FIXME: imageViews and depthView must be referenced from FrameBuilder
            ];

            VkFramebufferCreateInfo framebufferInfo;
            framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            framebufferInfo.renderPass = renderPass;
            framebufferInfo.attachmentCount = cast(uint) attachments.length;
            framebufferInfo.pAttachments = attachments.ptr;
            framebufferInfo.width = imageExtent.width;
            framebufferInfo.height = imageExtent.height;
            framebufferInfo.layers = 1;

            vkCreateFramebuffer(device.device, &framebufferInfo, device.backend.allocator, &fb).vkCheck;
        }
    }
}
