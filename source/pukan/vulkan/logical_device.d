module pukan.vulkan.logical_device;

import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.exceptions;
import log = std.logger;
import std.exception: enforce;
import std.string: toStringz;

class LogicalDevice(Backend)
{
    Backend backend; // TODO: rewrite to "Instance instance"
    VkDevice device;

    const uint familyIdx;

    package this(Backend b, VkPhysicalDevice physicalDevice, const(char*)[] extension_list)
    {
        backend = b;

        const fqIdxs = b.findSuitableQueueFamilies();
        enforce(fqIdxs.length > 0);
        familyIdx = cast(uint) fqIdxs[0];

        immutable float queuePriority = 1.0f;

        VkDeviceQueueCreateInfo queueCreateInfo = {
            sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex: familyIdx,
            queueCount: 1,
            pQueuePriorities: &queuePriority,
        };

        VkDeviceCreateInfo createInfo = {
            sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            queueCreateInfoCount: 1,
            pQueueCreateInfos: &queueCreateInfo,
            ppEnabledExtensionNames: extension_list.ptr,
            enabledExtensionCount: cast(uint) extension_list.length,
        };

        vkCreateDevice(physicalDevice, &createInfo, b.allocator, &device).vkCheck;
    }

    ~this()
    {
        vkDestroyDevice(device, backend.allocator);
    }

    //TODO: remove
    auto getQueue()
    {
        return getQueue(0);
    }

    ///
    auto getQueue(uint queueIdx)
    {
        VkQueue ret;
        vkGetDeviceQueue(device, familyIdx, queueIdx, &ret);

        return ret;
    }

    auto createSwapChain(in VkSurfaceCapabilitiesKHR capabilities)
    {
        VkSwapchainCreateInfoKHR cinf = {
            sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            surface: backend.surface,
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

        return new SwapChain!LogicalDevice(this, cinf);
    }

    auto loadShader(string filename)
    {
        return new ShaderModule!LogicalDevice(this, filename);
    }

    auto create(alias ClassType, A...)(A a)
    {
        return new ClassType!LogicalDevice(this, a);
    }

    auto createSemaphore()
    {
        return create!Semaphore;
    }

    auto createFence()
    {
        return new Fence!LogicalDevice(this);
    }
}

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

class Semaphore(LogicalDevice)
{
    LogicalDevice device;
    VkSemaphore semaphore;

    this(LogicalDevice dev)
    {
        device = dev;

        VkSemaphoreCreateInfo cinf = {
            sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        };

        vkCreateSemaphore(device.device, &cinf, device.backend.allocator, &semaphore).vkCheck;
    }

    ~this()
    {
        vkDestroySemaphore(device.device, semaphore, device.backend.allocator);
    }
}

class Fence(LogicalDevice)
{
    LogicalDevice device;
    VkFence fence;

    this(LogicalDevice dev)
    {
        device = dev;

        VkFenceCreateInfo cinf = {
            sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            flags: VK_FENCE_CREATE_SIGNALED_BIT,
        };

        vkCreateFence(device.device, &cinf, device.backend.allocator, &fence).vkCheck;
    }

    ~this()
    {
        vkDestroyFence(device.device, fence, device.backend.allocator);
    }
}
