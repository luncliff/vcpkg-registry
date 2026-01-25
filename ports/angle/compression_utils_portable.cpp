// Minimal gzip helpers derived from Chromium's compression_utils_portable.
// Uses system zlib to match ANGLE's USE_SYSTEM_ZLIB define.

#include "compression_utils_portable.h"

#include <algorithm>
#include <cstring>

namespace zlib_internal
{

uLong GzipExpectedCompressedSize(uLong input_size)
{
    // gzip adds a small header/trailer on top of deflate data.
    return compressBound(input_size) + 18u;
}

int GzipCompressHelper(Bytef *dest,
                       uLongf *dest_len,
                       const Bytef *source,
                       uLong source_len,
                       void *(* /*alloc_func*/)(void *, unsigned int, unsigned int),
                       void (* /*free_func*/)(void *, void *))
{
    z_stream stream{};
    stream.next_in   = const_cast<Bytef *>(source);
    stream.avail_in  = static_cast<uInt>(source_len);
    stream.next_out  = dest;
    stream.avail_out = static_cast<uInt>(*dest_len);

    // windowBits + 16 instructs zlib to write a gzip header/footer.
    int result = deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS + 16, 8,
                              Z_DEFAULT_STRATEGY);
    if (result != Z_OK)
    {
        return result;
    }

    result = deflate(&stream, Z_FINISH);
    if (result == Z_STREAM_END)
    {
        *dest_len = stream.total_out;
        result    = Z_OK;
    }

    deflateEnd(&stream);
    return result;
}

uint32_t GetGzipUncompressedSize(const Bytef *source, size_t source_len)
{
    // The last four bytes of a gzip stream store the original size modulo 2^32.
    if (source_len < 4)
    {
        return 0;
    }

    const size_t size_index = source_len - 4;
    uint32_t value          = static_cast<uint32_t>(source[size_index]) |
                     (static_cast<uint32_t>(source[size_index + 1]) << 8) |
                     (static_cast<uint32_t>(source[size_index + 2]) << 16) |
                     (static_cast<uint32_t>(source[size_index + 3]) << 24);
    return value;
}

int GzipUncompressHelper(Bytef *dest,
                         uLongf *dest_len,
                         const Bytef *source,
                         uLong source_len)
{
    z_stream stream{};
    stream.next_in   = const_cast<Bytef *>(source);
    stream.avail_in  = static_cast<uInt>(source_len);
    stream.next_out  = dest;
    stream.avail_out = static_cast<uInt>(*dest_len);

    // Enable gzip header/footer handling.
    int result = inflateInit2(&stream, MAX_WBITS + 16);
    if (result != Z_OK)
    {
        return result;
    }

    result = inflate(&stream, Z_FINISH);
    if (result == Z_STREAM_END)
    {
        *dest_len = stream.total_out;
        result    = Z_OK;
    }

    inflateEnd(&stream);
    return result;
}

}  // namespace zlib_internal
