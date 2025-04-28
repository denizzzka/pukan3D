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
    alias this = buf;
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
        // Buffer is bound, so it should be destroyed first to avoid complaints from validator like:
        // vkFreeMemory(): VK Object VkBuffer [...] still has a reference to mem obj VkDeviceMemory [...]

        vkDestroyBuffer(device.device, buf, device.backend.allocator);
        vkFreeMemory(device.device, deviceMemory, device.backend.allocator);
    }

    void recordCopyBuffer(VkCommandBuffer cmdBuf, VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size)
    {
        VkBufferCopy copyRegion = {
            size: size,
        };

        vkCmdCopyBuffer(cmdBuf, srcBuffer, dstBuffer, 1, &copyRegion);
    }

    void copyBuffer(VkCommandBuffer cmdBuf, VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size)
    {
        VkCommandBufferBeginInfo oneTime = {
            flags: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        CommandPool!LogicalDevice.recordBegin(cmdBuf, oneTime);

        recordCopyBuffer(cmdBuf, srcBuffer, dstBuffer, size);

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

/// Ability to transfer data into GPU
class TransferBuffer(LogicalDevice)
{
    LogicalDevice device;
    void[] localBuf;
    MemoryBuffer!LogicalDevice cpuBuffer;
    MemoryBuffer!LogicalDevice gpuBuffer;

    this(LogicalDevice device, size_t size, VkBufferUsageFlags mergeUsageFlags)
    {
        this.device = device;

        VkBufferCreateInfo srcBufInfo = {
            size: size,
            usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
        };

        cpuBuffer = device.create!MemoryBuffer(srcBufInfo, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

        VkBufferCreateInfo dstBufInfo = {
            size: size,
            usage: VK_BUFFER_USAGE_TRANSFER_DST_BIT | mergeUsageFlags,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
        };

        gpuBuffer = device.create!MemoryBuffer(dstBufInfo, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        void* createdBuf;
        vkMapMemory(device, cpuBuffer.deviceMemory, 0 /*offset*/, srcBufInfo.size, 0 /*flags*/, cast(void**) &createdBuf).vkCheck;

        localBuf = createdBuf[0 .. size];
    }

    ~this()
    {
        vkUnmapMemory(device, cpuBuffer.deviceMemory);
        destroy(gpuBuffer);
        destroy(cpuBuffer);
    }

    void upload(CommandPool)(CommandPool commandPool)
    {
        // Copy host RAM buffer to GPU RAM
        gpuBuffer.copyBuffer(commandPool.buf, cpuBuffer.buf, gpuBuffer.buf, localBuf.length);
    }

    void recordUpload(CommandPool)(CommandPool commandPool)
    {
        gpuBuffer.recordCopyBuffer(commandPool.buf, cpuBuffer.buf, gpuBuffer.buf, localBuf.length);
    }
}
