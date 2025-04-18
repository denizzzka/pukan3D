module pukan.renderer.surface;

import pukan.vulkan_sdk;

mixin template SurfaceMethods()
{
    void printSurfaceCapabilities(VkPhysicalDevice pd)
    {
        import pukan: toPrettyString;

        VkSurfaceCapabilitiesKHR c;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(pd, surface, &c);

        log_info(c.toPrettyString);
    }

    //~ VkSurfaceFormatKHR ?
}
