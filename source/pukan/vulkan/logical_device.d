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
}

class SwapChain(LogicalDevice)
{
    LogicalDevice device;
    VkSwapchainKHR swapchain;
    VkImage[] images;
    VkFormat imageFormat;
    VkExtent2D imageExtent;

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
        vkDestroySwapchainKHR(device.device, swapchain, device.backend.allocator);
    }

    auto createImageViews()
    {
        alias ImgView = ImageView!SwapChain;

        //~ auto ret = new ImgView[images.length];
        ImgView[] ret;
        ret.length = images.length;

        foreach(i, img; images)
        {
            ret[i] = new ImgView(this, img);
            device.backend.log_info("img view created, ", i);
        }

        return ret;
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
