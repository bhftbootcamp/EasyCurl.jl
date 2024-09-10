module EasyCurl

export CurlClient,
    CurlError

using LibCURL

abstract type CurlOptions end
abstract type CurlResponce end
abstract type CurlRequest end

"""
    CurlClient

Represents a client for making HTTP requests using libcurl. Allows for connection reuse.

## Fields

- `curl_handle::Ptr{Cvoid}`: The libcurl easy handle.
"""
mutable struct CurlClient
    curl_handle::Ptr{Cvoid}

    function CurlClient()
        handle = curl_easy_init()
        handle != C_NULL || throw(CurlError(CURLE_FAILED_INIT))
        c = new(handle)
        finalizer(close, c)
        return c
    end
end

"""
    close(c::CurlClient)

Closes the `CurlClient` instance by cleaning up the associated libcurl easy handle.

## Parameters
- `c::CurlClient`: The client instance to close.

## Examples

```julia-repl
julia> client = CurlClient()

julia> close(client)
```
"""
Base.close(c::CurlClient) = curl_easy_cleanup(c)

include("Utils.jl")
include("StatusCode.jl")

"""
    CurlError{code} <: Exception

Type wrapping LibCURL error codes. Returned from [`curl_request`](@ref) when a libcurl error occurs.

## Fields
- `code::UInt64`: The LibCURL error code (see [libcurl error codes](https://curl.se/libcurl/c/libcurl-errors.html)).
- `message::String`: The error message.

## Examples

```julia-repl
julia> curl_request("GET", "http://httpbin.org/status/400", interface = "9.9.9.9")
ERROR: CurlError(Failed binding local connection end)
[...]

julia> curl_request("GET", "http://httpbin.org/status/400", interface = "")
ERROR: CurlError(Couldn't connect to server)
[...]
```
"""
struct CurlError <: Exception
    code::UInt64
    message::String

    function CurlError(code::UInt32)
        new(code, unsafe_string(curl_easy_strerror(code)))
    end
end

function Base.showerror(io::IO, e::CurlError)
    print(io, "CurlError(", e.message, ")")
end

function curl_easy_cleanup(c::CurlClient)
    LibCURL.curl_easy_cleanup(c.curl_handle)
end

function curl_easy_escape(c::CurlClient, str::Cstring, len::Cint)
    r = LibCURL.curl_easy_escape(c.curl_handle, str, len)
    r == C_NULL && throw(CurlError(CURLE_FAILED_INIT))
    return r
end

function curl_easy_unescape(c::CurlClient, url::Cstring, inlength::Cint, outlength::Ptr{Cint})
    r = LibCURL.curl_easy_unescape(c.curl_handle, url, inlength, outlength)
    r == C_NULL && throw(CurlError(CURLE_FAILED_INIT))
    return r
end

function curl_easy_setopt(c::CurlClient, option, value)
    r = LibCURL.curl_easy_setopt(c.curl_handle, option, value)
    r == CURLE_OK || throw(CurlError(r))
end

function curl_easy_getinfo(c::CurlClient, info::CURLINFO, ptr::Ref)
    r = LibCURL.curl_easy_getinfo(c.curl_handle, info, ptr)
    r == CURLE_OK || throw(CurlError(r))
end

function curl_easy_perform(c::CurlClient)
    r = LibCURL.curl_easy_perform(c.curl_handle)
    r == CURLE_OK || throw(CurlError(r))
end

function get_http_response_status(c::CurlClient)::Int
    status_ref = Ref{Clong}()
    curl_easy_getinfo(c, CURLINFO_RESPONSE_CODE, status_ref)
    return Int(status_ref[])
end

function get_http_version(c::CurlClient)::Int
    version_ref = Ref{Clong}()
    curl_easy_getinfo(c, CURLINFO_HTTP_VERSION, version_ref)
    return version_ref[]
end

function get_total_request_time(c::CurlClient)::Float64
    time_ref = Ref{Cdouble}()
    curl_easy_getinfo(c, CURLINFO_TOTAL_TIME, time_ref)
    return time_ref[]
end

function write_callback(buf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    r = unsafe_pointer_to_objref(p_ctxt)::CurlResponce
    sz = s * n
    data = Array{UInt8}(undef, sz)
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt64), data, buf, sz)
    append!(r.body, data)
    return sz
end

function header_callback(buf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    r = unsafe_pointer_to_objref(p_ctxt)::CurlResponce
    sz = s * n
    header = unsafe_string(buf, sz)
    value = split_header(header)
    value !== nothing && push!(r.headers, value)
    return sz
end

"""
    curl_open(f::Function, x...; kw...)

A helper function for executing a batch of curl requests, using the same client. Optionally
configure the client (see [`CurlClient`](@ref) for more details).

## Examples

```julia-repl
julia> curl_open() do client
           response = curl_request(client, "GET", "http://httpbin.org/get")
           curl_status(response)
       end
200
```
"""
function curl_open(f::Function, x...; kw...)
    c = CurlClient(x...; kw...)
    try
        f(c)
    finally
        close(c)
    end
end

include("HTTP.jl")
include("IMAP.jl")

end
