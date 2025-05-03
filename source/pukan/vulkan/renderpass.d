module pukan.vulkan.renderpass;

import pukan.vulkan;
import pukan.vulkan.bindings;
import pukan.vulkan.helpers;

abstract class RenderPass
{
    VkRenderPass vkRenderPass;
    alias this = vkRenderPass;

    VkFormat imageFormat;
}

class DefaultRenderPass(LogicalDevice) : RenderPass
{
    LogicalDevice device;
    enum VkFormat depthFormat = DepthBuf!LogicalDevice.format;

    this(LogicalDevice dev, VkFormat imageFormat)
    {
        device = dev;
        this.imageFormat = imageFormat;

        VkAttachmentDescription colorAttachment = defaultColorAttachment;
        colorAttachment.format = imageFormat;

        VkAttachmentReference colorAttachmentRef = {
            attachment: 0,
            layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        };

        VkAttachmentDescription depthAttachment = defaultDepthAttachment;
        depthAttachment.format = depthFormat;

        VkAttachmentReference depthAttachmentRef = {
            layout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            attachment: 1,
        };

        auto attachments = [
            colorAttachment,
            depthAttachment,
        ];

        VkSubpassDescription subpass = {
            pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
            colorAttachmentCount: 1,
            pColorAttachments: &colorAttachmentRef,
            pDepthStencilAttachment: &depthAttachmentRef,
        };

        VkSubpassDependency dependency = defaultSubpassDependency;

        VkRenderPassCreateInfo renderPassInfo;
        renderPassInfo.attachmentCount = cast(uint) attachments.length;
        renderPassInfo.pAttachments = attachments.ptr;
        renderPassInfo.subpassCount = 1;
        renderPassInfo.pSubpasses = &subpass;
        renderPassInfo.dependencyCount = 1;
        renderPassInfo.pDependencies = &dependency;

        vkCall(device, &renderPassInfo, device.backend.allocator, &vkRenderPass);
    }

    ~this()
    {
        vkDestroyRenderPass(device, vkRenderPass, device.backend.allocator);
    }

    enum VkAttachmentDescription defaultColorAttachment = {
        samples: VK_SAMPLE_COUNT_1_BIT,
        loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    enum VkAttachmentDescription defaultDepthAttachment = {
        samples: VK_SAMPLE_COUNT_1_BIT,
        loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    enum VkSubpassDependency defaultSubpassDependency = {
        srcSubpass: VK_SUBPASS_EXTERNAL,
        dstSubpass: 0,
        srcStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        srcAccessMask: 0,
        dstStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        dstAccessMask: VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
    };
}
