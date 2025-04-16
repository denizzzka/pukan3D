module pukan.renderer;

public import pukan.renderer.device;

import pukan.vulkan_sdk;
import pukan.exceptions;
import std.string: toStringz;

/// VK_MAKE_API_VERSION macros
uint makeApiVersion(uint variant, uint major, uint minor, uint patch)
{
    return ((((uint)(variant)) << 29U) | (((uint)(major)) << 22U) | (((uint)(minor)) << 12U) | ((uint)(patch)));
}

class Backend(alias Logger)
{
    static void log_info(A...)(A s)
    {
        Logger.info(s);
    }

    VkApplicationInfo info = {
         sType: VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
         apiVersion: makeApiVersion(0, 1, 2, 0),
         pEngineName: "pukan",
         engineVersion: makeApiVersion(0, 0, 0, 1),
    };

    VkInstance instance;
    VkAllocationCallbacks* allocator = null;

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

        vkCreateInstance(&createInfo, allocator, &instance)
            .vkCheck("Vulkan instance creation failed");

        log_info("Vulkan instance created");
    }

    ~this()
    {
        vkDestroyInstance(instance, allocator);
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

            foreach(l; layers)
                log_info(l.layerName);
        }
    }

    VkPhysicalDevice[] devices()
    {
        uint count;

        vkEnumeratePhysicalDevices(instance, &count, null).vkCheck;

        VkPhysicalDevice[] devs;

        if(count > 0)
        {
            devs.length = count;

            vkEnumeratePhysicalDevices(instance, &count, devs.ptr).vkCheck;
        }

        return devs;
    }

    void printAllDevices()
    {
        foreach(d; devices)
        {
            VkPhysicalDeviceProperties props;
            vkGetPhysicalDeviceProperties(d, &props);

            VkPhysicalDeviceProperties2 props2 = {
                sType: VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2
            };
            vkGetPhysicalDeviceProperties2(d, &props2);

            VkPhysicalDeviceMemoryProperties mem;
            vkGetPhysicalDeviceMemoryProperties(d, &mem);

            VkPhysicalDeviceFeatures features;
            vkGetPhysicalDeviceFeatures(d, &features);

            log_info(props);
            log_info(props2);
            log_info(mem);
            log_info(features);
        }
    }

    debug scope attachFlightRecorder()
    {
        auto d = new FlightRecorder!Backend(this);

        // Extension commands that are not core or WSI have to be loaded
        auto fun = cast(PFN_vkCreateDebugUtilsMessengerEXT) vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");

        fun(instance, &d.createInfo, allocator, &d.messenger)
            .vkCheck(__FUNCTION__);

        return d;
    }
}

auto vkCheck(VkResult ret, string err_descr = "Vulkan exception")
{
    if(ret != VkResult.VK_SUCCESS)
        throw new PukanException(err_descr, ret);

    return ret;
}

class FlightRecorder(TBackend)
{
    TBackend backend;

    VkDebugUtilsMessengerCreateInfoEXT createInfo;
    VkDebugUtilsMessengerEXT messenger;

    this(TBackend b)
    {
        backend = b;

        with(VkDebugUtilsMessageSeverityFlagBitsEXT)
        with(VkDebugUtilsMessageTypeFlagBitsEXT)
        createInfo = VkDebugUtilsMessengerCreateInfoEXT(
            sType: VkStructureType.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            messageSeverity: (VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT),
            messageType: VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT,
            pfnUserCallback: &messenger_callback
        );
    }

    ~this()
    {
        auto fun = cast(PFN_vkDestroyDebugUtilsMessengerEXT) vkGetInstanceProcAddr(backend.instance, "vkDestroyDebugUtilsMessengerEXT");

        fun(backend.instance, messenger, backend.allocator);
    }

    extern(C) static uint messenger_callback(
        VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
        VkDebugUtilsMessageTypeFlagsEXT messageType,
        const VkDebugUtilsMessengerCallbackDataEXT* pCallbackData,
        void* pUserData
    )
    {
        import std.stdio;
        writeln(pCallbackData.pMessage);

        return VkResult.VK_SUCCESS;
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
