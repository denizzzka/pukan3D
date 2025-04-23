module pukan.vulkan.commands;

import pukan.vulkan;
import pukan.vulkan.bindings;

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
    }

    ~this()
    {
        vkDestroyCommandPool(device.device, commandPool, device.backend.allocator);
    }

    void initBuffs(uint count)
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

    static void recordBegin(ref VkCommandBuffer commandBuffer, VkCommandBufferBeginInfo beginInfo)
    {
        debug beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        vkBeginCommandBuffer(commandBuffer, &beginInfo).vkCheck;
    }

    static void recordEnd(ref VkCommandBuffer commandBuffer)
    {
        vkEndCommandBuffer(commandBuffer).vkCheck;
    }

    void recordCommandBuffer(SwapChain!LogicalDevice swapChain, VkCommandBuffer commandBuffer, VkRenderPass renderPass, uint imageIndex, VkBuffer vertexBuffer, ref VkPipeline graphicsPipeline)
    {
        VkCommandBufferBeginInfo beginInfo;
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        vkBeginCommandBuffer(commandBuffer, &beginInfo).vkCheck;

        VkRenderPassBeginInfo renderPassInfo;
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderPassInfo.renderPass = renderPass;
        renderPassInfo.framebuffer = swapChain.frameBuffers[imageIndex];
        renderPassInfo.renderArea.offset = VkOffset2D(0, 0);
        renderPassInfo.renderArea.extent = swapChain.imageExtent;

        VkClearValue clearColor = {
            color: VkClearColorValue(float32: [0.0f, 0.0f, 0.0f, 1.0f])
        };
        renderPassInfo.pClearValues = &clearColor;
        renderPassInfo.clearValueCount = 1;

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

            vkCmdDraw(commandBuffer, 3, 1, 0, 0);
        }

        vkCmdEndRenderPass(commandBuffer);

        vkEndCommandBuffer(commandBuffer).vkCheck("failed to record command buffer");
    }

    void resetBuffer(uint buffIdx)
    {
        vkResetCommandBuffer(commandBuffers[buffIdx], 0 /*VkCommandBufferResetFlagBits*/).vkCheck;
    }
}
