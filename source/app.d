import pukan;
import glfw3.api;
import std.conv: to;
import std.datetime.stopwatch;
import std.exception;
import std.logger;
import std.stdio;
import std.string: toStringz;

enum fps = 60;
enum width = 1;
enum height = 1;

//~ static extern(C) int mcheck_pedantic(void*);

//~ export extern(C) void free(void*) {};

import ldc.attributes;
@noSanitize("memory")
void init_glfw() { enforce(glfwInit()); }

void main() {
    version(linux)
    version(DigitalMars)
    {
        import etc.linux.memoryerror;
        registerMemoryAssertHandler();
    }

    import core.memory: GC;
    GC.disable();

    immutable name = "D/pukan3D/GLFW project";

    init_glfw();
    scope(exit) glfwTerminate();

    enforce(glfwVulkanSupported());

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

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

    //~ assert(mcheck_pedantic(null) != -1);

    //~ scope vkLib = new VulcanLibrary();
    //~ scope(exit) destroy_DISABLED(vkLib);

    auto vk = new Instance(name, makeApiVersion(1,2,3,4), extensions[0 .. ext_count]);
    scope(exit) destroy_DISABLED(vk);

    //~ vk.printAllDevices();
    //~ vk.printAllAvailableLayers();

    auto device = vk.createLogicalDevice();
    scope(exit)
    {
        destroy_DISABLED(device);
    }

    import pukan.vulkan.bindings: VkSurfaceKHR;
    static import glfw3.internal;

    VkSurfaceKHR surface;
    glfwCreateWindowSurface(
        vk.instance,
        window,
        cast(glfw3.internal.VkAllocationCallbacks*) vk.allocator,
        cast(ulong*) &surface
    );

    //~ vk.printSurfaceFormats(vk.devices[vk.deviceIdx], surface);
    //~ vk.printPresentModes(vk.devices[vk.deviceIdx], surface);

    import pukan.vulkan.bindings;

    VkDescriptorSetLayoutBinding[] descriptorSetLayoutBindings;
    {
        VkDescriptorSetLayoutBinding uboLayoutBinding = {
            binding: 0,
            descriptorType: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            descriptorCount: 1,
            stageFlags: VK_SHADER_STAGE_VERTEX_BIT,
        };

        VkDescriptorSetLayoutBinding samplerLayoutBinding = {
            binding: 1,
            descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            descriptorCount: 1,
            stageFlags: VK_SHADER_STAGE_FRAGMENT_BIT,
        };

        descriptorSetLayoutBindings = [
            uboLayoutBinding,
            samplerLayoutBinding,
        ];
    }

    void windowSizeChanged()
    {
        int width;
        int height;

        glfwGetFramebufferSize(window, &width, &height);

        while (width == 0 || height == 0)
        {
            /*
            TODO: I don't understand this logic, but it allowed to
            overcome refresh freezes when increasing the window size.
            Perhaps this code does not work as it should, but it is
            shown in this form in different articles.
            */

            glfwGetFramebufferSize(window, &width, &height);
            glfwWaitEvents();
        }
    }

    scope scene = new Scene(device, surface, descriptorSetLayoutBindings, &windowSizeChanged);
    scope(exit)
    {
        destroy_DISABLED(scene);
        GC.collect();
    }

return;

    //~ //FIXME: remove refs
    //~ auto swapChain = &scene.swapChain;
    //~ auto frameBuilder = &scene.frameBuilder;
    //~ ref pipelineInfoCreator = scene.pipelineInfoCreator;
    //~ ref graphicsPipelines = scene.graphicsPipelines;
    //~ auto descriptorSets = &scene.descriptorSets;

    //~ auto vertexBuffer = device.create!TransferBuffer(Vertex.sizeof * vertices.length, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
    //~ scope(exit) destroy_DISABLED(vertexBuffer);

    //~ auto indicesBuffer = device.create!TransferBuffer(ushort.sizeof * indices.length, VK_BUFFER_USAGE_INDEX_BUFFER_BIT);
    //~ scope(exit) destroy_DISABLED(indicesBuffer);

    //~ // Using any (first) buffer as buffer for initial loading
    //~ auto initBuf = &swapChain.currSync.commandBuf;

    //~ // Copy vertices to mapped memory
    //~ vertexBuffer.cpuBuf[0..$] = cast(void[]) vertices;
    //~ indicesBuffer.cpuBuf[0..$] = cast(void[]) indices;

    //~ vertexBuffer.uploadImmediate(swapChain.commandPool, *initBuf);
    //~ indicesBuffer.uploadImmediate(swapChain.commandPool, *initBuf);

    //~ scope texture = device.create!Texture(swapChain.commandPool, *initBuf);
    //~ scope(exit) destroy_DISABLED(texture);

    //~ VkWriteDescriptorSet[] descriptorWrites;

    //~ {
        //~ VkDescriptorBufferInfo bufferInfo = {
            //~ buffer: frameBuilder.uniformBuffer.gpuBuffer,
            //~ offset: 0,
            //~ range: UniformBufferObject.sizeof,
        //~ };

        //~ VkDescriptorImageInfo imageInfo = {
            //~ imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            //~ imageView: texture.imageView,
            //~ sampler: texture.sampler,
        //~ };

        //~ descriptorWrites = [
            //~ VkWriteDescriptorSet(
                //~ sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                //~ dstSet: (*descriptorSets)[0 /*TODO: frame number*/],
                //~ dstBinding: 0,
                //~ dstArrayElement: 0,
                //~ descriptorType: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                //~ descriptorCount: 1,
                //~ pBufferInfo: &bufferInfo,
            //~ ),
            //~ VkWriteDescriptorSet(
                //~ sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                //~ dstSet: (*descriptorSets)[0 /*TODO: frame number*/],
                //~ dstBinding: 1,
                //~ dstArrayElement: 0,
                //~ descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                //~ descriptorCount: 1,
                //~ pImageInfo: &imageInfo,
            //~ )
        //~ ];

        //~ scene.descriptorPool.updateSets(descriptorWrites);
    //~ }

    //~ vkDeviceWaitIdle(device.device);
}
