module pukan.vulkan.memory;

import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;
//~ import pukan.exceptions;
//~ import std.file: read;
//~ import std.exception: enforce;

//TODO: Incorporate into LogicalDevice by using mixin template
class MemoryBuffer(LogicalDevice)
{
    LogicalDevice device;
    VkBuffer buf;
    VkDeviceMemory deviceMemory;

    this(LogicalDevice dev, ref VkBufferCreateInfo createInfo, VkMemoryPropertyFlags propFlags)
    {
        device = dev;

        vkCall(device.device, &createInfo, device.backend.allocator, &buf);

        VkMemoryRequirements memRequirements;
        vkGetBufferMemoryRequirements(device.device, buf, &memRequirements);

        VkMemoryAllocateInfo allocInfo = {
            allocationSize: memRequirements.size,
            memoryTypeIndex: device.backend.findMemoryType(memRequirements.memoryTypeBits, propFlags),
        };

        vkCall(device.device, &allocInfo, device.backend.allocator, &deviceMemory);

        vkBindBufferMemory(device.device, buf, deviceMemory, 0 /*memoryOffset*/).vkCheck;
    }

    ~this()
    {
        vkFreeMemory(device.device, deviceMemory, device.backend.allocator);
        vkDestroyBuffer(device.device, buf, device.backend.allocator);
    }

    void copyBuffer(VkCommandBuffer cmdBuf, VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size)
    {
        VkCommandBufferBeginInfo oneTime = {
            flags: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        CommandPool!LogicalDevice.recordBegin(cmdBuf, oneTime);

        VkBufferCopy copyRegion = {
            size: size,
        };

        vkCmdCopyBuffer(cmdBuf, srcBuffer, dstBuffer, 1, &copyRegion);

        CommandPool!LogicalDevice.recordEnd(cmdBuf);

        auto fence = device.createFence;
        scope(exit) destroy(fence);

        VkSubmitInfo submitInfo = {
            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
            commandBufferCount: 1,
            pCommandBuffers: &cmdBuf,
        };

        vkResetFences(device.device, 1, &fence.fence).vkCheck;
        vkQueueSubmit(device.getQueue(), 1, &submitInfo, fence.fence).vkCheck;

        vkWaitForFences(device.device, 1, &fence.fence, VK_TRUE, uint.max).vkCheck;

        vkResetCommandBuffer(cmdBuf, 0 /*VkCommandBufferResetFlagBits*/).vkCheck;
    }
}
