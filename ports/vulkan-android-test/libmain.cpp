#include <android/api-level.h>
#include <android/native_window_jni.h>
#define VK_USE_PLATFORM_ANDROID_KHR
#include <vulkan/vulkan.h>

#include <string>
#include <vector>

struct vulkan_exception_t final {
    const VkResult code;
    const char* message;
};

class vulkan_instance_t final {
  public:
    VkInstance handle{};
    VkApplicationInfo info{};
    std::string name;

  public:
    explicit vulkan_instance_t(const char* name, std::vector<const char* const> layers,
                               std::vector<const char* const> extensions) noexcept(false) {
        info.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        info.pApplicationName = name;
        info.applicationVersion = 0x00'00;
        info.apiVersion = VK_API_VERSION_1_1;
        info.pEngineName = nullptr;
        info.engineVersion = VK_API_VERSION_1_1;
        VkInstanceCreateInfo request{};
        request.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        request.pApplicationInfo = &info;
        request.enabledExtensionCount = static_cast<uint32_t>(extensions.size());
        if (request.enabledExtensionCount > 0)
            request.ppEnabledExtensionNames = extensions.data();
        request.enabledLayerCount = static_cast<uint32_t>(layers.size());
        if (request.enabledLayerCount > 0)
            request.ppEnabledLayerNames = layers.data();
        if (auto ec = vkCreateInstance(&request, nullptr, &handle))
            throw vulkan_exception_t{ec, "vkCreateInstance"};
    }
    ~vulkan_instance_t() noexcept {
        vkDestroyInstance(handle, nullptr);
    }
    vulkan_instance_t(const vulkan_instance_t&) = delete;
    vulkan_instance_t(vulkan_instance_t&&) = delete;
    vulkan_instance_t& operator=(const vulkan_instance_t&) = delete;
    vulkan_instance_t& operator=(vulkan_instance_t&&) = delete;
};

VkResult get_physical_device(VkInstance instance, std::vector<VkPhysicalDevice>& devices) noexcept {
    uint32_t count = 0;
    if (auto ec = vkEnumeratePhysicalDevices(instance, &count, nullptr); ec != VK_SUCCESS)
        return ec;
    devices.resize(count);
    return vkEnumeratePhysicalDevices(instance, &count, devices.data());
}

uint32_t test_physical_devices() noexcept {
    try {
        vulkan_instance_t instance{"vulkan-android-test", {}, {"VK_KHR_surface"}};
        std::vector<VkPhysicalDevice> gpus{};
        if (auto ec = get_physical_device(instance.handle, gpus); ec != VK_SUCCESS)
            return ec;
        for (const auto& unit : gpus) {
            VkPhysicalDeviceProperties props{};
            vkGetPhysicalDeviceProperties(unit, &props);
        }
    } catch (const vulkan_exception_t& ex) {
        return ex.code;
    }
    return VK_SUCCESS;
}
