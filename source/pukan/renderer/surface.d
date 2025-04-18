module pukan.renderer.surface;

import pukan.vulkan_sdk;
import pukan: toPrettyString;

mixin template SurfaceMethods()
{
    void printSurfaceFormats(VkPhysicalDevice pd, VkSurfaceKHR surface)
    {
        auto fmt = getArrayFrom!vkGetPhysicalDeviceSurfaceFormatsKHR(pd, surface);

        log_info(fmt);
    }

    void printSurfaceCapabilities(VkPhysicalDevice pd)
    {
        VkSurfaceCapabilitiesKHR c;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pd, surface, &c).vkCheck;

        log_info(c.toPrettyString);
    }
}
