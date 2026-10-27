#include <webgpu/webgpu.h>
#include <webgpu/webgpu_cpp.h>

#include <cstdio>

int main() {
    wgpu::InstanceDescriptor desc{};
    wgpu::Instance instance = wgpu::CreateInstance(&desc);
    WGPUInstance handle = instance.Get();
    std::printf("instance: %p\n", static_cast<void*>(handle));
    return handle == nullptr;
}
