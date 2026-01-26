// Minimal subset of Chromium's compression_utils_portable for ANGLE.
// Provides gzip helper routines using system zlib.
#pragma once

#include <cstdint>
#include <cstddef>
#include <zlib.h>

namespace zlib_internal
{

uLong GzipExpectedCompressedSize(uLong input_size);

int GzipCompressHelper(Bytef *dest,
                       uLongf *dest_len,
                       const Bytef *source,
                       uLong source_len,
                       void *(*alloc_func)(void *, unsigned int, unsigned int) = nullptr,
                       void (*free_func)(void *, void *) = nullptr);

uint32_t GetGzipUncompressedSize(const Bytef *source, size_t source_len);

int GzipUncompressHelper(Bytef *dest,
                         uLongf *dest_len,
                         const Bytef *source,
                         uLong source_len);

}  // namespace zlib_internal
