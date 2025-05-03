module pukan.vulkan.memory;

import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;

class MemoryBufferMappedToCPU(LogicalDevice) : MemoryBuffer!LogicalDevice
{
    void[] cpuBuf; /// CPU-mapped memory buffer

    this(LogicalDevice device, size_t size, VkBufferUsageFlags usageFlags)
    {
        VkBufferCreateInfo createInfo = {
            size: size,
            usage: usageFlags,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
        };

        super(device, createInfo, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

        void* createdBuf;
        vkMapMemory(device, deviceMemory, 0 /*offset*/, size, 0 /*flags*/, cast(void**) &createdBuf).vkCheck;

        cpuBuf = createdBuf[0 .. size];
    }

    ~this()
    {
        vkUnmapMemory(device, deviceMemory);
    }
}

//TODO: Incorporate into LogicalDevice by using mixin template?
class MemoryBuffer(LogicalDevice) : MemoryBufferBase!LogicalDevice
{
    VkBuffer buf;
    alias this = buf;

    this(LogicalDevice device, ref VkBufferCreateInfo createInfo, in VkMemoryPropertyFlags propFlags)
    {
        vkCall(device.device, &createInfo, device.backend.allocator, &buf);

        VkMemoryRequirements memRequirements;
        vkGetBufferMemoryRequirements(device.device, buf, &memRequirements);

        super(device, memRequirements, propFlags);

        vkBindBufferMemory(device, buf, deviceMemory, 0 /*memoryOffset*/).vkCheck;
    }

    ~this()
    {
        vkDestroyBuffer(device.device, buf, device.backend.allocator);
    }

    //TODO: static?
    void recordCopyBuffer(VkCommandBuffer cmdBuf, VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size)
    {
        VkBufferCopy copyRegion = {
            size: size,
        };

        vkCmdCopyBuffer(cmdBuf, srcBuffer, dstBuffer, 1, &copyRegion);
    }

    //TODO: static?
    void copyBuffer(CommandPool!LogicalDevice cmdPool, VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size)
    {
        cmdPool.recordOneTime(
            (cmdBuf) => recordCopyBuffer(cmdBuf, srcBuffer, dstBuffer, size)
        );

        cmdPool.submitAll();
    }
}

class MemoryBufferBase(LogicalDevice)
{
    LogicalDevice device;
    VkDeviceMemory deviceMemory;

    this(LogicalDevice dev, in VkMemoryRequirements memRequirements, in VkMemoryPropertyFlags propFlags)
    {
        device = dev;

        VkMemoryAllocateInfo allocInfo = {
            allocationSize: memRequirements.size,
            memoryTypeIndex: device.backend.findMemoryType(memRequirements.memoryTypeBits, propFlags),
        };

        vkCall(device.device, &allocInfo, device.backend.allocator, &deviceMemory);
    }

    ~this()
    {
        vkFreeMemory(device.device, deviceMemory, device.backend.allocator);
    }
}

/// Ability to transfer data into GPU
class TransferBuffer(LogicalDevice)
{
    LogicalDevice device;
    MemoryBufferMappedToCPU!LogicalDevice cpuBuffer;
    MemoryBuffer!LogicalDevice gpuBuffer;

    this(LogicalDevice device, size_t size, VkBufferUsageFlags mergeUsageFlags = VK_BUFFER_USAGE_TRANSFER_DST_BIT)
    {
        this.device = device;

        cpuBuffer = device.create!MemoryBufferMappedToCPU(size, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,);

        VkBufferCreateInfo dstBufInfo = {
            size: size,
            usage: VK_BUFFER_USAGE_TRANSFER_DST_BIT | mergeUsageFlags,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
        };

        gpuBuffer = device.create!MemoryBuffer(dstBufInfo, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    }

    ~this()
    {
        destroy(gpuBuffer);
        destroy(cpuBuffer);
    }

    auto ref cpuBuf() => cpuBuffer.cpuBuf;

    void upload(CommandPool)(CommandPool commandPool)
    {
        // Copy host RAM buffer to GPU RAM
        gpuBuffer.copyBuffer(commandPool, cpuBuffer.buf, gpuBuffer.buf, cpuBuf.length);
    }

    void recordUpload(VkCommandBuffer buf)
    {
        gpuBuffer.recordCopyBuffer(buf, cpuBuffer.buf, gpuBuffer.buf, cpuBuf.length);
    }
}
