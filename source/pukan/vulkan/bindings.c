// This trampoline file is need because importC can't import .h files directly

#include <vulkan/vulkan.h>

#ifdef WIN32
    #include <vulkan/vulkan_win32.h>
#else
    // X11
    #include <xcb/xcb.h>
    #include <vulkan/vulkan_xcb.h>
#endif
