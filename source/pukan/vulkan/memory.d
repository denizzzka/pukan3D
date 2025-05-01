module pukan.vulkan.memory;

import pukan.exceptions: PukanException;
import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;

class ImageMemory(LogicalDevice) : MemoryBufferBase!LogicalDevice
{
    VkImage image;
    alias this = image;
    VkExtent3D imageExtent;

    this(LogicalDevice device, ref VkImageCreateInfo createInfo, in VkMemoryPropertyFlags propFlags)
    {
        vkCall(device.device, &createInfo, device.backend.allocator, &image);

        imageExtent = createInfo.extent;

        VkMemoryRequirements memRequirements;
        vkGetImageMemoryRequirements(device, image, &memRequirements);

        super(device, memRequirements, propFlags);

        vkBindImageMemory(device, image, super.deviceMemory, 0 /* memoryOffset */).vkCheck;
    }

    ~this()
    {
        vkDestroyImage(device, image, device.backend.allocator);
    }

    void addPipelineBarrier(CommandPool!LogicalDevice commandPool, VkImageLayout oldLayout, VkImageLayout newLayout)
    {
        VkImageMemoryBarrier barrier;
        barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier.oldLayout = oldLayout;
        barrier.newLayout = newLayout;
        barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED; // same queue family used
        barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED; // ditto
        barrier.image = image;
        barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        barrier.subresourceRange.baseMipLevel = 0;
        barrier.subresourceRange.levelCount = 1;
        barrier.subresourceRange.baseArrayLayer = 0;
        barrier.subresourceRange.layerCount = 1;

        VkPipelineStageFlags sourceStage;
        VkPipelineStageFlags destinationStage;

        if(oldLayout == VK_IMAGE_LAYOUT_UNDEFINED && newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
        {
            barrier.srcAccessMask = VK_ACCESS_NONE;
            barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

            sourceStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
            destinationStage = VK_PIPELINE_STAGE_TRANSFER_BIT;
        }
        else if(oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL && newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
        {
            barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

            sourceStage = VK_PIPELINE_STAGE_TRANSFER_BIT;
            destinationStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
        }
        else
            throw new PukanException("unsupported layout transition!");

        vkCmdPipelineBarrier(
            commandPool.buf,
            sourceStage,
            destinationStage,
            0, // dependencyFlags
            0, null,
            0, null,
            1, &barrier
        );
    }

    void copyFromBuffer(CommandPool!LogicalDevice commandPool, VkBuffer srcBuffer)
    {
        commandPool.oneTimeBufferRun(() =>
            addPipelineBarrier(commandPool, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
        );

        VkBufferImageCopy region;
        region.bufferOffset = 0;
        region.bufferRowLength = 0;
        region.bufferImageHeight = 0;

        region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        region.imageSubresource.mipLevel = 0;
        region.imageSubresource.baseArrayLayer = 0;
        region.imageSubresource.layerCount = 1;

        region.imageOffset = VkOffset3D(0, 0, 0);
        region.imageExtent = imageExtent;

        commandPool.oneTimeBufferRun(() =>
            vkCmdCopyBufferToImage(
                commandPool.buf,
                srcBuffer,
                image,
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                1, // regionCount
                &region
            )
        );

        commandPool.oneTimeBufferRun(() =>
            addPipelineBarrier(commandPool, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
        );
    }
}

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
        gpuBuffer.copyBuffer(commandPool.buf, cpuBuffer.buf, gpuBuffer.buf, cpuBuf.length);
    }

    void recordUpload(CommandPool)(CommandPool commandPool)
    {
        gpuBuffer.recordCopyBuffer(commandPool.buf, cpuBuffer.buf, gpuBuffer.buf, cpuBuf.length);
    }
}
