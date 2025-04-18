module pukan.renderer.surface;

import pukan.vulkan_sdk;
import pukan: toPrettyString;

mixin template SurfaceMethods()
{
    void printSurfaceFormats(VkPhysicalDevice pd, VkSurfaceKHR surface)
    {
        auto fmts = getArrayFrom!vkGetPhysicalDeviceSurfaceFormatsKHR(pd, surface);
        log_info(fmts);
    }

    void printPresentModes(VkPhysicalDevice pd, VkSurfaceKHR surface)
    {
        auto modes = getArrayFrom!vkGetPhysicalDeviceSurfacePresentModesKHR(pd, surface);
        log_info(modes.toPrettyString);
    }

    void printSurfaceCapabilities(VkPhysicalDevice pd, VkSurfaceKHR surface)
    {
        VkSurfaceCapabilitiesKHR c;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pd, surface, &c).vkCheck;

        log_info(c.toPrettyString);
    }
}
