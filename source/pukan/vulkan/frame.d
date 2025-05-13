module pukan.vulkan.frame;

//~ import pukan.exceptions;
import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;

//TODO: can LogicalDevice be alias to instanced object?
class FrameBuilder
{
    LogicalDevice device;
    VkQueue graphicsQueue;
    VkQueue presentQueue;
    TransferBuffer uniformBuffer;

    this(LogicalDevice dev, VkQueue graphics, VkQueue present)
    {
        device = dev;
        graphicsQueue = graphics;
        presentQueue = present;

        // FIXME: bad idea to allocate a memory buffer only for one uniform buffer,
        // need to allocate more memory then divide it into pieces
        uniformBuffer = device.create!TransferBuffer(UniformBufferObject.sizeof, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
    }

    ~this()
    {
        destroy_DISABLED(uniformBuffer);
    }

    VkResult acquireNextImage(SwapChain swapChain, out uint imageIndex)
    {
        return vkAcquireNextImageKHR(device, swapChain.swapchain, ulong.max /* timeout */, swapChain.currSync.imageAvailable, null /* fence */, &imageIndex);
    }

    //TODO: move to swapchain?
    void queueSubmit(SwapChain swapChain)
    {
        auto sync = swapChain.currSync;

        auto waitStages = cast(uint) VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

        VkSubmitInfo submitInfo = {
            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,

            pWaitDstStageMask: &waitStages,

            waitSemaphoreCount: cast(uint) sync.waitSemaphores.length,
            pWaitSemaphores: sync.waitSemaphores.ptr,

            commandBufferCount: 1,
            pCommandBuffers: &sync.commandBuf,

            signalSemaphoreCount: cast(uint) sync.signalSemaphores.length,
            pSignalSemaphores: sync.signalSemaphores.ptr,
        };

        vkQueueSubmit(device.getQueue(), 1, &submitInfo, sync.inFlightFence).vkCheck;
    }

    VkResult queueImageForPresentation(SwapChain swapChain, ref uint imageIndex)
    {
        auto sync = swapChain.currSync;

        VkSwapchainKHR[1] swapChains = [swapChain.swapchain];

        VkPresentInfoKHR presentInfo = {
            sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,

            pImageIndices: &imageIndex,

            waitSemaphoreCount: cast(uint) sync.signalSemaphores.length,
            pWaitSemaphores: sync.signalSemaphores.ptr,

            swapchainCount: cast(uint) swapChains.length,
            pSwapchains: swapChains.ptr,
        };

        return vkQueuePresentKHR(presentQueue, &presentInfo);
    }
}

class Frame
{
    LogicalDevice device;
    VkImageView imageView;
    DepthBuf depthBuf;
    VkFramebuffer frameBuffer;

    this(LogicalDevice dev, VkImage image, VkExtent2D imageExtent, VkFormat imageFormat, VkRenderPass renderPass)
    {
        device = dev;

        createImageView(imageView, device, imageFormat, image);
        depthBuf = DepthBuf(device, imageExtent);

        {
            VkImageView[2] attachments = [
                imageView,
                depthBuf.depthView,
            ];

            VkFramebufferCreateInfo frameBufferInfo = {
                sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                renderPass: renderPass,
                attachmentCount: cast(uint) attachments.length,
                pAttachments: attachments.ptr,
                width: imageExtent.width,
                height: imageExtent.height,
                layers: 1,
            };

            vkCreateFramebuffer(device, &frameBufferInfo, device.backend.allocator, &frameBuffer).vkCheck;
        }
    }

    ~this()
    {
        if(frameBuffer)
            vkDestroyFramebuffer(device, frameBuffer, device.backend.allocator);

        if(imageView)
            vkDestroyImageView(device, imageView, device.backend.allocator);
    }
}

void createImageView(ref VkImageView imgView, LogicalDevice device, VkFormat imageFormat, VkImage image)
{
    VkImageViewCreateInfo cinf = {
        sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        viewType: VK_IMAGE_VIEW_TYPE_2D,
        format: imageFormat,
        components: VkComponentMapping(
            r: VK_COMPONENT_SWIZZLE_IDENTITY,
            g: VK_COMPONENT_SWIZZLE_IDENTITY,
            b: VK_COMPONENT_SWIZZLE_IDENTITY,
            a: VK_COMPONENT_SWIZZLE_IDENTITY,
        ),
        subresourceRange: VkImageSubresourceRange(
            aspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
            baseMipLevel: 0,
            levelCount: 1,
            baseArrayLayer: 0,
            layerCount: 1,
        ),
        image: image,
    };

    vkCreateImageView(device, &cinf, device.backend.allocator, &imgView).vkCheck;
}

struct DepthBuf
{
    LogicalDevice device;
    ImageMemory depthImage;
    VkImageView depthView;
    //TODO: autodetection need
    enum format = VK_FORMAT_D24_UNORM_S8_UINT;

    this(LogicalDevice dev, VkExtent2D imageExtent)
    {
        device = dev;

        VkImageCreateInfo imageInfo = {
            imageType: VK_IMAGE_TYPE_2D,
            format: format,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            extent: VkExtent3D(imageExtent.width, imageExtent.height, 1),
            mipLevels: 1,
            arrayLayers: 1,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
            usage: VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            samples: VK_SAMPLE_COUNT_1_BIT,
        };

        depthImage = device.create!ImageMemory(imageInfo, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        VkImageViewCreateInfo cinf = {
            sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            viewType: VK_IMAGE_VIEW_TYPE_2D,
            format: format,
            subresourceRange: VkImageSubresourceRange(
                aspectMask: VK_IMAGE_ASPECT_DEPTH_BIT,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1,
            ),
            image: depthImage,
        };

        vkCreateImageView(device, &cinf, device.backend.allocator, &depthView).vkCheck;
    }

    ~this()
    {
        if(depthView)
            vkDestroyImageView(device, depthView, device.backend.allocator);

        destroy_DISABLED(depthImage);
    }
}
