module pukan.renderer.logical_device;

import pukan.renderer;
import pukan.vulkan_sdk;
import pukan.exceptions;
import log = std.logger;
import std.exception: enforce;
import std.string: toStringz;

class LogicalDevice(Backend)
{
    Backend backend;
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
}

class SwapChain(LogicalDevice)
{
    LogicalDevice device;
    VkSwapchainKHR swapchain;
    const uint imageCount;

    this(LogicalDevice d, VkSwapchainCreateInfoKHR cinf)
    {
        device = d;
        vkCreateSwapchainKHR(d.device, &cinf, d.backend.allocator, &swapchain).vkCheck;

        uint cnt;
        vkGetSwapchainImagesKHR(device.device, swapchain, &cnt, null).vkCheck;
        imageCount = cnt;
    }

    ~this()
    {
        vkDestroySwapchainKHR(device.device, swapchain, device.backend.allocator);
    }

    VkImage[] getImages()
    {
        uint cnt = imageCount;
        VkImage* images;
        vkGetSwapchainImagesKHR(device.device, swapchain, &cnt, images).vkCheck;
        assert(cnt == imageCount);

        return images[0 .. imageCount];
    }
}
