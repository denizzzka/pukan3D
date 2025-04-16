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

        const(char*)[] extension_list = [
            VK_KHR_SURFACE_EXTENSION_NAME.ptr,
        ];

        version(Windows)
            extension_list ~= VK_KHR_WIN32_SURFACE_EXTENSION_NAME.ptr;
        else
            extension_list ~= VK_KHR_XCB_SURFACE_EXTENSION_NAME.ptr; //X11

        debug extension_list ~= VK_EXT_DEBUG_UTILS_EXTENSION_NAME.ptr;

        const(char*)[] validation_layers;
        debug validation_layers ~= "VK_LAYER_KHRONOS_validation";

        VkInstanceCreateInfo createInfo = {
            sType: VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            pApplicationInfo: &info,
            ppEnabledExtensionNames: extension_list.ptr,
            enabledExtensionCount: cast(uint) extension_list.length,
            ppEnabledLayerNames: validation_layers.ptr,
            enabledLayerCount: cast(uint) validation_layers.length,
        };

        vkCreateInstance(&createInfo, custom_allocator, &instance)
            .vkCheck("Vulkan instance creation failed");

        log.info("Vulkan instance created");
    }

    ~this()
    {
        vkDestroyInstance(instance, custom_allocator);
    }

    void printAllAvailableLayers()
    {
        uint count;

        vkEnumerateInstanceLayerProperties(&count, null).vkCheck;

        if(count > 0)
        {
            VkLayerProperties[] layers;
            layers.length = count;

            vkEnumerateInstanceLayerProperties(&count, layers.ptr).vkCheck;

            import std.stdio;
            foreach(l; layers)
                writeln(l.layerName);
        }
    }
}

auto vkCheck(VkResult ret, string err_descr = "Vulkan exception")
{
    if(ret != VkResult.VK_SUCCESS)
        throw new PukanException(err_descr, ret);

    return ret;
}

class Frame
{
    //~ void resize
    //~ draw(render_packet)
}

struct RenderPacket
{
}
