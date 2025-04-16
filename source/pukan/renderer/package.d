module pukan.renderer;

import pukan.vulkan_sdk;
import pukan.exceptions;
import log = std.logger;
import std.string: toStringz;

/// VK_MAKE_API_VERSION macros
uint makeApiVersion(uint variant, uint major, uint minor, uint patch)
{
    return ((((uint)(variant)) << 29U) | (((uint)(major)) << 22U) | (((uint)(minor)) << 12U) | ((uint)(patch)));
}

class Backend
{
    VkApplicationInfo info = {
         sType: VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
         apiVersion: makeApiVersion(0, 1, 2, 0),
         pEngineName: "pukan",
         engineVersion: makeApiVersion(0, 0, 0, 1),
    };

    VkInstance instance;
    VkAllocationCallbacks* custom_allocator = null;

    this(string appName, uint appVer)
    {
        info.pApplicationName = appName.toStringz;
        info.applicationVersion = appVer;

        VkInstanceCreateInfo createInfo = {
            sType: VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            pApplicationInfo: &info,
        };

        auto ret = vkCreateInstance(&createInfo, custom_allocator, &instance);
        if(ret != VkResult.VK_SUCCESS)
            throw new PukanException("Vulkan instance creation failed", ret);

        log.info("Vulkan instance created");
    }
}

class Frame
{
    //~ void resize
    //~ draw(render_packet)
}

struct RenderPacket
{
}
