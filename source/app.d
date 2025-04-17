import pukan;
import glfw3.api;
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

void main() {
    version(none)
    version(linux)
    version(DigitalMars)
    {
        import etc.linux.memoryerror;
        registerMemoryAssertHandler();
    }

    immutable name = "D/pukan3D/Raylib project";

    version(all)
        static auto getLogger() => stdThreadLocalLog();
    else
        static auto getLogger() => MuteLogger();

    auto vk = new Backend!(getLogger)(name, makeApiVersion(1,2,3,4));
    scope(exit) destroy(vk);

    vk.printAllAvailableLayers();

    debug auto dbg = vk.attachFlightRecorder();
    debug scope(exit) destroy(dbg);

    enforce(glfwInit());
    scope(exit) glfwTerminate();

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    auto window = glfwCreateWindow(width, height, name.toStringz, null, null);
    enforce(window, "Cannot create a window");

    //~ glfwSetWindowUserPointer(demo.window, demo);
    //~ glfwSetWindowRefreshCallback(demo.window, &demo_refresh_callback);
    //~ glfwSetFramebufferSizeCallback(demo.window, &demo_resize_callback);
    //~ glfwSetKeyCallback(demo.window, &demo_key_callback);

    import pukan.vulkan_sdk: VkSurfaceKHR;
    VkSurfaceKHR surface;
    glfwCreateWindowSurface(
        vk.instance,
        window,
        cast(glfw3.internal.VkAllocationCallbacks*) vk.allocator,
        cast(ulong*) &surface
    );

    vk.useSurface(surface);

    // implement main loop
}
