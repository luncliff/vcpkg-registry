#include <cstdio>

import wgpu;

int main() {
    wgpu::InstanceDescriptor desc{};
    wgpu::Instance instance = wgpu::CreateInstance(&desc);
    std::printf("instance: %p\n", static_cast<void*>(instance.Get()));
    return instance == nullptr;
}
