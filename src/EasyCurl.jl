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
    msg = isempty(e.libcurl_message) ? e.message : e.libcurl_message
    print(io, nameof(typeof(e)), "{", e.code, "}: ", msg, e.diagnostic_message)
end
# COV_EXCL_STOP

@inline function _errorbuffer_msg(buf::Union{Nothing,Vector{UInt8}})::String
    if buf === nothing || buf[1] == 0x00
        return ""
    end
    n0  = findfirst(==(0x00), buf)
    raw = String(n0 === nothing ? buf : @view buf[1:n0-1])
    msg = chomp(strip(raw))
    return msg
end

"""
    CurlEasyError <: AbstractCurlError

Represents an error from a libcurl easy interface call.

## Fields
- `code::Int`: The libcurl error code.
- `message::String`: The corresponding error message from libcurl.
- `diagnostic_message::String`: diagnostic message, that will contain virtually all context info

## Examples

```julia-repl
julia> curl_easy_setopt(c, 1, 1)
ERROR: CurlEasyError{48}: An unknown option was passed in to libcurl
```
"""
struct CurlEasyError{code} <: AbstractCurlError
    code::Int
    message::String
    libcurl_message::String
    diagnostic_message::String

    function CurlEasyError(c::Integer, curl)
        msg = unsafe_string(LibCURL.curl_easy_strerror(UInt32(c)))
        buf = _errorbuffer_msg(curl.error_buffer)
        ctx = nothing
        private_ref = Ref{CurlResponseContext}()
        r = LibCURL.curl_easy_getinfo(curl.easy_handle, CURLINFO_PRIVATE, private_ref)
        if (r == CURLE_OK)
            ctx = private_ref[]
        end
        diag = _diagnostics(curl, ctx)                              
        return new{Int(c)}(Int(c), msg, buf, diag)
    end
end

"""
    CurlMultiError <: AbstractCurlError

Represents an error from a libcurl multi interface call.

## Fields
- `code::Int`: The libcurl multi error code.
- `message::String`: The corresponding error message from libcurl.
- `diagnostic_message::String`: diagnostic message, that will contain virtually all context info

## Examples

```julia-repl
julia> curl_multi_add_handle(c)
ERROR: CurlMultiError{1}: Invalid multi handle
```
"""
struct CurlMultiError{code} <: AbstractCurlError
    code::Int
    message::String
    libcurl_message::String
    diagnostic_message::String

    function CurlMultiError(c::Integer, curl)
        msg = unsafe_string(LibCURL.curl_multi_strerror(UInt32(c)))
        buf = _errorbuffer_msg(curl.error_buffer)
        ctx = nothing
        private_ref = Ref{CurlResponseContext}()
        r = LibCURL.curl_easy_getinfo(curl.easy_handle, CURLINFO_PRIVATE, private_ref)
        if (r == CURLE_OK)
            ctx = private_ref[]
        end
        diag = _diagnostics(curl, ctx)                              
        return new{Int(c)}(Int(c), msg, buf, diag)
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
    error_buffer::Vector{UInt8}

    function CurlClient()
        easy_handle = LibCURL.curl_easy_init()
        easy_handle != C_NULL || begin 
            throw(ArgumentError("curl_easy_init failed"))
        end
        multi_handle = LibCURL.curl_multi_init()
        multi_handle != C_NULL || begin 
            LibCURL.curl_easy_cleanup(easy_handle)
            throw(ArgumentError("curl_multi_init failed"))
        end
        buf = zeros(UInt8, LibCURL.CURL_ERROR_SIZE)
        r = LibCURL.curl_easy_setopt(easy_handle, CURLOPT_ERRORBUFFER, pointer(buf))
        r == CURLE_OK || begin
            LibCURL.curl_multi_cleanup(multi_handle)
            LibCURL.curl_easy_cleanup(easy_handle)
            throw(ArgumentError("failed to set CURLOPT_ERRORBUFFER"))
        end

        c = new(easy_handle,multi_handle, buf)
        finalizer(close, c)
        return c
    end
end

@inline function _get_strinfo(c::CurlClient, info::CURLINFO)
    ref = Ref{Cstring}()
    r_code = LibCURL.curl_easy_getinfo(c.easy_handle, info, ref)
    r_code == CURLE_OK || return nothing
    p = ref[]
    return p == C_NULL ? nothing : unsafe_string(p)
end

@inline function _get_longinfo(c::CurlClient, info::CURLINFO)
    r = Ref{Clong}()
    r_code = LibCURL.curl_easy_getinfo(c.easy_handle, info, r)
    r_code == CURLE_OK && return r[]
    return nothing
end

@inline function _get_doubleinfo(c::CurlClient, info::CURLINFO)
    r = Ref{Cdouble}()
    r_code = LibCURL.curl_easy_getinfo(c.easy_handle, info, r)
    r_code == CURLE_OK && return r[]
    return nothing
end

function _redact_headers(h::Vector{Pair{String,String}})
    secrets = Set(["authorization","proxy-authorization","cookie","set-cookie"])
    out = Pair{String,String}[]
    for (k,v) in h
        concealed = lowercase(k) in secrets ? "<redacted>" : v
        push!(out, k => concealed)
    end
    return out
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
    r == C_NULL && throw(CurlEasyError(CURLE_FAILED_INIT, c))
    return r
end

function curl_easy_unescape(c::CurlClient, url::AbstractString, inlength::Int, outlength::Ptr)
    r = LibCURL.curl_easy_unescape(c.easy_handle, url, inlength, outlength)
    r == C_NULL && throw(CurlEasyError(CURLE_FAILED_INIT, c))
    return r
end

function curl_easy_setopt(c::CurlClient, option, value)
    r = LibCURL.curl_easy_setopt(c.easy_handle, option, value)
    r == CURLE_OK || throw(CurlEasyError(r, c))
    return r
end

function curl_easy_getinfo(c::CurlClient, info::CURLINFO, ptr::Ref)
    r = LibCURL.curl_easy_getinfo(c.easy_handle, info, ptr)
    r == CURLE_OK || throw(CurlEasyError(r, c))
    return r
end

function curl_easy_reset(c::CurlClient)
    LibCURL.curl_easy_reset(c.easy_handle)
    fill!(c.error_buffer, 0x00)
    LibCURL.curl_easy_setopt(c.easy_handle, CURLOPT_ERRORBUFFER, pointer(c.error_buffer))
end

function curl_easy_perform(c::CurlClient)
    r = LibCURL.curl_easy_perform(c.easy_handle)
    r == CURLE_OK || throw(CurlEasyError(r, c))
    return r
end

function curl_multi_add_handle(c::CurlClient)
    r = LibCURL.curl_multi_add_handle(c.multi_handle, c.easy_handle)
    r == CURLM_OK || throw(CurlMultiError(r, c))
    return r
end

function curl_multi_remove_handle(c::CurlClient)
    r = LibCURL.curl_multi_remove_handle(c.multi_handle, c.easy_handle)
    r == CURLM_OK || throw(CurlMultiError(r, c))
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
            throw(CurlMultiError(mc, c))
        end
        if r_ctx !== nothing
            isnothing(r_ctx.error) || throw(r_ctx.error)
        end
    end

    while true
        p = LibCURL.curl_multi_info_read(c.multi_handle, Ref{Cint}(0))
        p == C_NULL && break
        m = unsafe_load(convert(Ptr{CurlMsg}, p))
        if m.msg == CURLMSG_DONE
            if m.code != CURLE_OK
                throw(CurlEasyError(m.code, c))
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
    r = LibCURL.curl_easy_getinfo(c.easy_handle, CURLINFO_PRIVATE, private_ref)
    return r == CURLE_OK ? private_ref[] : nothing
    # return unsafe_pointer_to_objref(ptr_ref[])::T
end

@kwdef struct ReqSnapshot
    method::String
    url::String
    headers::Vector{Pair{String,String}}
    proxy::Union{String,Nothing}
    interface::Union{String,Nothing}
    version::Union{UInt,Nothing}
    connect_timeout::Float64
    read_timeout::Float64
    body_len::Int
end

@kwdef mutable struct CurlResponseContext
    status::Int = 0
    version::Int = 0
    total_time::Float64 = 0.0
    stream::IOBuffer = IOBuffer(; append = true)
    headers::Vector{Pair{String,String}} = Vector{Pair{String,String}}()
    on_data::Union{Nothing,Function}
    error::Union{Nothing,Exception} = nothing
    req_snapshot::Union{Nothing,ReqSnapshot} = nothing

    function CurlResponseContext(on_data::Union{Nothing,Function})
        return new(0, 0, 0.0, IOBuffer(; append = true), Pair{String,String}[], on_data, nothing, nothing)
    end

    function CurlResponseContext(status::Int, version::Int, total_time::Float64,
        stream::IOBuffer, headers::Vector{Pair{String,String}},
        on_data::Union{Nothing,Function}, error::Union{Nothing,Exception},
        req_snapshot::Union{Nothing,ReqSnapshot})
        return new(status, version, total_time, stream, headers, on_data, error, req_snapshot)
    end
end

function _diagnostics(curl::CurlClient, ctx::Union{Nothing,CurlResponseContext})
    io = IOBuffer()

    effective_url  = _get_strinfo(curl, CURLINFO_EFFECTIVE_URL)
    primary_ip     = _get_strinfo(curl, CURLINFO_PRIMARY_IP)
    local_ip       = _get_strinfo(curl, CURLINFO_LOCAL_IP)
    primary_port   = _get_longinfo(curl, CURLINFO_PRIMARY_PORT)
    local_port     = _get_longinfo(curl, CURLINFO_LOCAL_PORT)
    t_total        = _get_doubleinfo(curl, CURLINFO_TOTAL_TIME)
    t_connect      = _get_doubleinfo(curl, CURLINFO_CONNECT_TIME)
    t_app          = _get_doubleinfo(curl, CURLINFO_APPCONNECT_TIME)
    t_name         = _get_doubleinfo(curl, CURLINFO_NAMELOOKUP_TIME)

    if ctx !== nothing && ctx.req_snapshot !== nothing
        snap = ctx.req_snapshot
        scheme = begin
            m = match(r"^([a-zA-Z][a-zA-Z0-9+.-]*)://", snap.url)
            isnothing(m) ? missing : m.captures[1]
        end

        println(io, "$(snap.method) $(snap.url)")
        println(io, "protocol: ", scheme)
        !isnothing(snap.proxy)     && println(io, "proxy: ", snap.proxy)
        !isnothing(snap.interface) && println(io, "interface: ", snap.interface)
        println(io, "connect_timeout=$(snap.connect_timeout)s read_timeout=$(snap.read_timeout)s")
        !isnothing(snap.version)   && println(io, "requested_http_version: ", snap.version)
        println(io, "headers:")
        for (k,v) in _redact_headers(snap.headers)
            println(io, "  $k: $v")
        end
        println(io, "body_len: ", snap.body_len)
    else
        println(io, "(no request snapshot)")
    end

    println(io, "\n=== Connection ===")
    if !isnothing(local_ip) || !isnothing(primary_ip)
        println(io, "local $(something(local_ip,"?\\")):$(something(local_port,"?\\")) remote $(something(primary_ip,"?\\")):$(something(primary_port,"?\\"))")
    end
    if !isnothing(effective_url)
        println(io, "effective_url: ", effective_url)
    end

    println(io, "\n=== Timings (s) ===")
    println(io, "namelookup=", t_name, " connect=", t_connect, " appconnect=", t_app, " total=", t_total)

    return String(take!(io))
end

function write_callback(buf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    r_ctx::CurlResponseContext = unsafe_pointer_to_objref(p_ctxt)
    sz = s * n
    if sz == 0 || buf == C_NULL
        return sz
    end
    try
        Base.unsafe_write(r_ctx.stream, buf, sz)
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


