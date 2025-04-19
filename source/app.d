import pukan;
import glfw3.api;
import std.conv: to;
import std.exception;
import std.logger;
import std.stdio;
import std.string: toStringz;

enum fps = 60;
enum width = 640;
enum height = 640;

//~ struct Clock
//~ {
    //~ float start_time;
    //~ float elapsed;
//~ }

//~ Clock getClock()
//~ {
    //~ Clock r;
    //~ r.el
    //~ GetTime
//~ }

// TODO: remove DebugVersion, https://github.com/dlang/phobos/issues/10750
debug version = DebugVersion;
version(DebugVersion)
    static auto getLogger() => stdThreadLocalLog();
else
    static auto getLogger() => MuteLogger();

void main() {
    version(none)
    version(linux)
    version(DigitalMars)
    {
        import etc.linux.memoryerror;
        registerMemoryAssertHandler();
    }

    immutable name = "D/pukan3D/Raylib project";

    enforce(glfwInit());
    scope(exit) glfwTerminate();

    enforce(glfwVulkanSupported());

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    auto window = glfwCreateWindow(width, height, name.toStringz, null, null);
    enforce(window, "Cannot create a window");

    //~ glfwSetWindowUserPointer(demo.window, demo);
    //~ glfwSetWindowRefreshCallback(demo.window, &demo_refresh_callback);
    //~ glfwSetFramebufferSizeCallback(demo.window, &demo_resize_callback);
    //~ glfwSetKeyCallback(demo.window, &demo_key_callback);

    // Print needed extensions
    uint ext_count;
    const char** extensions = glfwGetRequiredInstanceExtensions(&ext_count);

    writeln("glfw needed extensions:");
    foreach(i; 0 .. ext_count)
        writeln(extensions[i].to!string);

    auto vk = new Backend!(getLogger)(name, makeApiVersion(1,2,3,4), extensions[0 .. ext_count]);
    scope(exit) destroy(vk);

    //~ vk.printAllDevices();
    //~ vk.printAllAvailableLayers();

    debug auto dbg = vk.attachFlightRecorder();
    debug scope(exit) destroy(dbg);

    auto device = vk.createLogicalDevice();
    scope(exit) destroy(device);

    import pukan.vulkan.bindings: VkSurfaceKHR;
    static import glfw3.internal;

    VkSurfaceKHR surface;
    glfwCreateWindowSurface(
        vk.instance,
        window,
        cast(glfw3.internal.VkAllocationCallbacks*) vk.allocator,
        cast(ulong*) &surface
    );

    vk.useSurface(surface);
    vk.printSurfaceFormats(vk.devices[vk.deviceIdx], surface);
    vk.printPresentModes(vk.devices[vk.deviceIdx], surface);

    const capab = vk.getSurfaceCapabilities(vk.devices[vk.deviceIdx], surface);
    capab.toPrettyString.writeln;

    enforce(capab.currentExtent.width != uint.max, "unsupported, see VkSurfaceCapabilitiesKHR(3) Manual Page");

    auto queue = device.getQueue();

    auto swapChain = device.createSwapChain(capab);
    scope(exit) destroy(swapChain);

    auto imgViews = swapChain.createImageViews();
    scope(exit)
        foreach(img; imgViews)
            destroy(img);

    auto vertShader = device.loadShader("vert.spv");
    scope(exit) destroy(vertShader);
    auto fragShader = device.loadShader("frag.spv");
    scope(exit) destroy(fragShader);

    // implement main loop
}
