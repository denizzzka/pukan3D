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

    this(LogicalDevice dev, uint queueFamilyIndex)
    {
        device = dev;

        VkCommandPoolCreateInfo cinf;
        cinf.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        cinf.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
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
            VkCommandBufferAllocateInfo allocInfo;
            allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
            allocInfo.commandPool = commandPool;
            allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
            allocInfo.commandBufferCount = cast(uint) commandBuffers.length;

            vkAllocateCommandBuffers(device.device, &allocInfo, &buf).vkCheck;
        }
    }

    auto ref buf()
    {
        return commandBuffers[0];
    }

    static void recordBegin(ref VkCommandBuffer commandBuffer, VkCommandBufferBeginInfo beginInfo)
    {
        debug beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        vkBeginCommandBuffer(commandBuffer, &beginInfo).vkCheck;
    }

    static void recordEnd(ref VkCommandBuffer commandBuffer)
    {
        vkEndCommandBuffer(commandBuffer).vkCheck;
    }

    void oneTimeBufferRun(void delegate() dg)
    {
        VkCommandBufferBeginInfo beginInfo = {
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            flags: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

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

        vkQueueSubmit(device.getQueue(), 1, &submitInfo, null).vkCheck;
        vkQueueWaitIdle(device.getQueue());
    }

    void recordCommandBuffer(
        SwapChain!LogicalDevice swapChain,
        ref VkCommandBuffer commandBuffer,
        VkRenderPass renderPass,
        uint imageIndex,
        VkBuffer vertexBuffer,
        VkBuffer indexBuffer,
        uint indexCount,
        VkDescriptorSet[] descriptorSets,
        VkPipelineLayout pipelineLayout,
        ref VkPipeline graphicsPipeline
    )
    {
        VkRenderPassBeginInfo renderPassInfo;
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderPassInfo.renderPass = renderPass;
        renderPassInfo.framebuffer = swapChain.frameBuffers[imageIndex];
        renderPassInfo.renderArea.offset = VkOffset2D(0, 0);
        renderPassInfo.renderArea.extent = swapChain.imageExtent;

        auto clearValues = [
            VkClearValue(
                color: VkClearColorValue(float32: [0.0f, 0.0f, 0.0f, 1.0f]),
            ),
            VkClearValue(
                depthStencil: VkClearDepthStencilValue(1, 0),
            ),
        ];

        renderPassInfo.pClearValues = clearValues.ptr;
        renderPassInfo.clearValueCount = cast(uint) clearValues.length;

        vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

        {
            VkViewport viewport;
            viewport.x = 0.0f;
            viewport.y = 0.0f;
            viewport.width = cast(float) swapChain.imageExtent.width;
            viewport.height = cast(float) swapChain.imageExtent.height;
            viewport.minDepth = 0.0f;
            viewport.maxDepth = 1.0f;
            vkCmdSetViewport(commandBuffer, 0, 1, &viewport);

            VkRect2D scissor;
            scissor.offset = VkOffset2D(0, 0);
            scissor.extent = swapChain.imageExtent;
            vkCmdSetScissor(commandBuffer, 0, 1, &scissor);

            auto vertexBuffers = [vertexBuffer];
            VkDeviceSize[] offsets = [VkDeviceSize(0)];
            vkCmdBindVertexBuffers(commandBuffer, 0, 1, vertexBuffers.ptr, offsets.ptr);
            vkCmdBindIndexBuffer(commandBuffer, indexBuffer, 0, VK_INDEX_TYPE_UINT16);
            vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipelineLayout, 0, cast(uint) descriptorSets.length, descriptorSets.ptr, 0, null);

            vkCmdDrawIndexed(commandBuffer, cast(uint) indices.length, 1, 0, 0, 0);
        }

        vkCmdEndRenderPass(commandBuffer);
    }

    void resetBuffer(uint buffIdx)
    {
        vkResetCommandBuffer(commandBuffers[buffIdx], 0 /*VkCommandBufferResetFlagBits*/).vkCheck;
    }
}
