module EasyCurl

export CurlClient,
    AbstractCurlError,
    CurlEasyError,
    CurlMultiError

export curl_session,
    curl_joinurl

export curl_total_time,
    curl_body

using LibCURL

"""
    CurlResponse

Common response interface for all supported protocols.

## Interface accessors
- `curl_total_time(x)`: Total time spent receiving a response in seconds.
- `curl_body(x)`: The response body.
"""
abstract type CurlResponse end
abstract type CurlRequest end
abstract type CurlOptions end

function curl_total_time end
function curl_body end

"""
    AbstractCurlError <: Exception

Abstract base type for exceptions related to LibCURL errors.

Concrete subtypes:
- `CurlEasyError`: Errors from the libcurl easy interface.
- `CurlMultiError`: Errors from the libcurl multi interface.

All subtypes provide:
- `code::Int`: Numeric libcurl error code.
- `message::String`: Human-readable libcurl error message.

See [libcurl error codes](https://curl.se/libcurl/c/libcurl-errors.html) for more details.
"""
abstract type AbstractCurlError <: Exception end

# COV_EXCL_START
function Base.showerror(io::IO, e::AbstractCurlError)
    print(io, nameof(typeof(e)), "{", e.code, "}: ", e.message)
end
# COV_EXCL_STOP

"""
    CurlEasyError <: AbstractCurlError

Represents an error from a libcurl easy interface call.

## Fields
- `code::Int`: The libcurl error code.
- `message::String`: The corresponding error message from libcurl.

## Examples

```julia-repl
julia> curl_easy_setopt(c, 1, 1)
ERROR: CurlEasyError{48}: An unknown option was passed in to libcurl
```
"""
struct CurlEasyError{code} <: AbstractCurlError
    code::Int
    message::String

    function CurlEasyError(c::Integer)
        new{Int(c)}(c, unsafe_string(LibCURL.curl_easy_strerror(UInt32(c))))
    end
end

"""
    CurlMultiError <: AbstractCurlError

Represents an error from a libcurl multi interface call.

## Fields
- `code::Int`: The libcurl multi error code.
- `message::String`: The corresponding error message from libcurl.

## Examples

```julia-repl
julia> curl_multi_add_handle(c)
ERROR: CurlMultiError{1}: Invalid multi handle
```
"""
struct CurlMultiError{code} <: AbstractCurlError
    code::Int
    message::String

    function CurlMultiError(c::Integer)
        new{Int(c)}(c, unsafe_string(LibCURL.curl_multi_strerror(UInt32(c))))
    end
end

"""
    CurlClient

Represents a client for making HTTP requests using libcurl. Allows for connection reuse.

## Fields
- `easy_handle::Ptr{Cvoid}`: The libcurl easy handle.
- `multi_handle::Ptr{Cvoid}`: The libcurl multi handle.
"""
mutable struct CurlClient
    easy_handle::Ptr{Cvoid}
    multi_handle::Ptr{Cvoid}

    function CurlClient()
        easy_handle = LibCURL.curl_easy_init()
        easy_handle != C_NULL || throw(CurlEasyError(CURLE_FAILED_INIT))
        multi_handle = LibCURL.curl_multi_init()
        multi_handle != C_NULL || throw(CurlMultiError(CURLM_BAD_HANDLE))
        c = new(easy_handle,multi_handle)
        finalizer(close, c)
        return c
    end
end

function curl_cleanup(c::CurlClient)
    c.easy_handle == C_NULL && return nothing
    LibCURL.curl_easy_cleanup(c.easy_handle)
    c.easy_handle = C_NULL
    c.multi_handle == C_NULL && return nothing
    LibCURL.curl_multi_cleanup(c.multi_handle)
    c.multi_handle = C_NULL
    return nothing
end

"""
    close(client::CurlClient)

Closes the `client` instance by cleaning up the associated libcurl easy handle.
"""
Base.close(c::CurlClient) = curl_cleanup(c)

"""
    isopen(client::CurlClient)

Checks if the `client` instance is open by verifying the internal libcurl handle.
"""
Base.isopen(c::CurlClient) = c.multi_handle != C_NULL

"""
    curl_session(f::Function, x...; kw...)

A helper function for executing a batch of curl requests, using the same client.
Optionally configure the client (see [`CurlClient`](@ref) for more details).

## Examples

```julia-repl
julia> curl_session() do client
           response = http_request(client, "GET", "http://httpbin.org/get")
           http_status(response)
       end
200
```
"""
function curl_session(f::Function, x...; kw...)
    c = CurlClient(x...; kw...)
    try
        f(c)
    finally
        close(c)
    end
end

function curl_easy_escape(c::CurlClient, str::AbstractString, len::Int)
    r = LibCURL.curl_easy_escape(c.easy_handle, str, len)
    r == C_NULL && throw(CurlEasyError(CURLE_FAILED_INIT))
    return r
end

function curl_easy_unescape(c::CurlClient, url::AbstractString, inlength::Int, outlength::Ptr)
    r = LibCURL.curl_easy_unescape(c.easy_handle, url, inlength, outlength)
    r == C_NULL && throw(CurlEasyError(CURLE_FAILED_INIT))
    return r
end

function curl_easy_setopt(c::CurlClient, option, value)
    r = LibCURL.curl_easy_setopt(c.easy_handle, option, value)
    r == CURLE_OK || throw(CurlEasyError(r))
    return r
end

function curl_easy_getinfo(c::CurlClient, info::CURLINFO, ptr::Ref)
    r = LibCURL.curl_easy_getinfo(c.easy_handle, info, ptr)
    r == CURLE_OK || throw(CurlEasyError(r))
    return r
end

function curl_easy_reset(c::CurlClient)
    LibCURL.curl_easy_reset(c.easy_handle)
end

function curl_easy_perform(c::CurlClient)
    r = LibCURL.curl_easy_perform(c.easy_handle)
    r == CURLE_OK || throw(CurlEasyError(r))
    return r
end

function curl_multi_add_handle(c::CurlClient)
    r = LibCURL.curl_multi_add_handle(c.multi_handle, c.easy_handle)
    r == CURLM_OK || throw(CurlMultiError(r))
    return r
end

function curl_multi_remove_handle(c::CurlClient)
    r = LibCURL.curl_multi_remove_handle(c.multi_handle, c.easy_handle)
    r == CURLM_OK || throw(CurlMultiError(r))
    return r
end

struct CurlMsg
    msg::CURLMSG
    easy::Ptr{Cvoid}
    code::CURLcode
end

function curl_multi_perform(c::CurlClient)
    r_ctx = get_private_data(c, CurlResponseContext)
    still_running = Ref{Cint}(1)

    while still_running[] > 0
        mc = LibCURL.curl_multi_perform(c.multi_handle, still_running)
        if mc == CURLM_OK
            mc = curl_multi_wait(c.multi_handle, C_NULL, 0, 100, Ref{Cint}(0))
        end
        if mc != CURLM_OK
            throw(CurlMultiError(mc))
        end
        isnothing(r_ctx.error) || throw(r_ctx.error)
    end

    while true
        p = LibCURL.curl_multi_info_read(c.multi_handle, Ref{Cint}(0))
        p == C_NULL && break
        m = unsafe_load(convert(Ptr{CurlMsg}, p))
        if m.msg == CURLMSG_DONE
            if m.code != CURLE_OK
                throw(CurlEasyError(m.code))
            end
        end
    end
end

include("Utils.jl")
include("StatusCode.jl")

function get_http_response_status(c::CurlClient)::Int
    status_ref = Ref{Clong}()
    curl_easy_getinfo(c, CURLINFO_RESPONSE_CODE, status_ref)
    return status_ref[]
end

function get_http_version(c::CurlClient)::Int
    version_ref = Ref{Clong}()
    curl_easy_getinfo(c, CURLINFO_HTTP_VERSION, version_ref)
    return version_ref[]
end

function get_total_time(c::CurlClient)::Float64
    time_ref = Ref{Cdouble}()
    curl_easy_getinfo(c, CURLINFO_TOTAL_TIME, time_ref)
    return time_ref[]
end

function get_private_data(c::CurlClient, ::Type{T})::T where {T}
    private_ref = Ref{T}()
    curl_easy_getinfo(c, CURLINFO_PRIVATE, private_ref)
    return private_ref[]
end

mutable struct CurlResponseContext
    status::Int
    version::Int
    total_time::Float64
    stream::IOBuffer
    headers::Vector{Pair{String,String}}
    on_data::Union{Nothing,Function}
    error::Union{Nothing,Exception}

    function CurlResponseContext(on_data::Union{Nothing,Function})
        return new(0, 0, 0.0, IOBuffer(; append = true), Vector{Pair{String,String}}(), on_data, nothing)
    end
end

function write_callback(buf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    r_ctx::CurlResponseContext = unsafe_pointer_to_objref(p_ctxt)
    sz = s * n
    if sz == 0 || buf == C_NULL
        return sz
    end
    data = Array{UInt8}(undef, sz)
    unsafe_copyto!(pointer(data), buf, sz)
    try
        write(r_ctx.stream, data)
        flush(r_ctx.stream)
        isnothing(r_ctx.on_data) || r_ctx.on_data(r_ctx.stream)
    catch e
        r_ctx.error = e
    end
    return sz
end

function header_callback(buf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    r_ctx::CurlResponseContext = unsafe_pointer_to_objref(p_ctxt)
    sz = s * n
    header = unsafe_string(buf, sz)
    value = split_header(header)
    isnothing(value) || push!(r_ctx.headers, value)
    return sz
end

include("protocols/HTTP.jl")
include("protocols/IMAP.jl")

end
