module pukan.vulkan.commands;

import pukan.vulkan;
import pukan.vulkan.bindings;

/**
Command pools are externally synchronized, meaning that a command pool
must not be used concurrently in multiple threads. That includes use
via recording commands on any command buffers allocated from the pool,
as well as operations that allocate, free, and reset command buffers or
the pool itself.
*/
class CommandPool(LogicalDevice)
{
    LogicalDevice device;

    VkCommandPool commandPool;
    VkCommandBuffer[] commandBuffers;

    enum VkCommandPoolCreateInfo defaultPoolCreateInfo = {
        sType: VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        flags: VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
    };

    enum VkCommandBufferAllocateInfo defaultBufferAllocateInfo = {
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    };

    enum VkCommandBufferBeginInfo defaultBufferBeginInfo = {
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    };

    enum VkCommandBufferBeginInfo defaultOneTimeBufferBeginInfo = {
        sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        flags: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    this(LogicalDevice dev, uint queueFamilyIndex)
    {
        device = dev;

        auto cinf = defaultPoolCreateInfo;
        cinf.queueFamilyIndex = queueFamilyIndex;

        vkCreateCommandPool(device.device, &cinf, device.backend.allocator, &commandPool).vkCheck;

        initBuffs(1);
    }

    ~this()
    {
        vkDestroyCommandPool(device.device, commandPool, device.backend.allocator);
    }

    private void initBuffs(uint count)
    {
        commandBuffers.length = count;

        foreach(i, ref buf; commandBuffers)
        {
            auto allocInfo = defaultBufferAllocateInfo;
            allocInfo.commandPool = commandPool;
            allocInfo.commandBufferCount = cast(uint) commandBuffers.length;

            vkAllocateCommandBuffers(device.device, &allocInfo, &buf).vkCheck;
        }
    }

    auto ref buf()
    {
        return commandBuffers[0];
    }

    void recordCommands(VkCommandBufferBeginInfo beginInfo, void delegate(VkCommandBuffer) dg)
    {
        vkBeginCommandBuffer(buf, &beginInfo).vkCheck;
        dg(buf);
        vkEndCommandBuffer(buf).vkCheck("failed to record command buffer");
    }

    void recordCommands(void delegate(VkCommandBuffer) dg)
    {
        auto cinf = defaultBufferBeginInfo;
        recordCommands(cinf, dg);
    }

    void recordOneTime(void delegate(VkCommandBuffer) dg)
    {
        auto cinf = defaultOneTimeBufferBeginInfo;
        recordCommands(cinf, dg);
    }

    void oneTimeBufferRun(void delegate() dg)
    {
        VkCommandBufferBeginInfo beginInfo = defaultOneTimeBufferBeginInfo;

        vkBeginCommandBuffer(buf, &beginInfo).vkCheck;

        dg();

        vkEndCommandBuffer(buf).vkCheck("failed to record command buffer");

        submitAll();
    }

    void submitAll()
    {
        VkSubmitInfo submitInfo = {
            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
            commandBufferCount: cast(uint) commandBuffers.length,
            pCommandBuffers: commandBuffers.ptr,
        };

        auto fence = device.createFence;
        scope(exit) destroy(fence);

        vkResetFences(device, 1, &fence.fence).vkCheck;
        vkQueueSubmit(device.getQueue(), 1, &submitInfo, fence).vkCheck;
        vkWaitForFences(device.device, 1, &fence.fence, VK_TRUE, uint.max).vkCheck;
    }
}
