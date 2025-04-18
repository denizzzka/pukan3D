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

    package this(Backend b, VkPhysicalDevice physicalDevice, )
    {
        backend = b;

        const fqIdxs = b.findSuitableQueueFamilies();
        enforce(fqIdxs.length > 0);

        immutable float queuePriority = 1.0f;

        VkDeviceQueueCreateInfo queueCreateInfo = {
            sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex: cast(uint) fqIdxs[0],
            queueCount: 1,
            pQueuePriorities: &queuePriority,
        };

        VkDeviceCreateInfo createInfo = {
            sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            queueCreateInfoCount: 1,
            pQueueCreateInfos: &queueCreateInfo,
        };

        vkCreateDevice(physicalDevice, &createInfo, b.allocator, &device).vkCheck;
    }

    ~this()
    {
        vkDestroyDevice(device, backend.allocator);
    }
}
