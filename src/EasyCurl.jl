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
    msg = !isempty(e.libcurl_message) ? e.libcurl_message : e.message
    print(io, nameof(typeof(e)), "{", e.code, "}: ", msg)
    if e.diagnostics !== nothing
        print(io, '\n')
        show(io, e.diagnostics)
    end
end
# COV_EXCL_STOP

@inline function _errorbuffer_msg(buf::Union{Nothing,Vector{UInt8}})::String
    if buf === nothing || buf[1] == 0x00
        return ""
    end
    n0 = findfirst(==(0x00), buf)
    raw = String(n0 === nothing ? buf : @view buf[1:n0-1])
    msg = chomp(strip(raw))
    return msg
end

Base.@kwdef struct ReqSnapshot
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

struct CurlDiagnostics
    req::Union{Nothing,ReqSnapshot}
    effective_url::Union{Nothing,String}
    primary_ip::Union{Nothing,String}
    local_ip::Union{Nothing,String}
    primary_port::Union{Nothing,Int}
    local_port::Union{Nothing,Int}
    time_total::Union{Nothing,Float64}
    time_connect::Union{Nothing,Float64}
    time_app_connect::Union{Nothing,Float64}
    time_name_lookup::Union{Nothing,Float64}
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

        c = new(easy_handle, multi_handle, buf)
        finalizer(close, c)
        return c
    end
end

function CurlDiagnostics(curl::CurlClient)
    ctx_ref = Ref{CurlResponseContext}()
    r = LibCURL.curl_easy_getinfo(curl.easy_handle, CURLINFO_PRIVATE, ctx_ref)
    snapshot = (r == CURLE_OK) ? ctx_ref[].req_snapshot : nothing
    return CurlDiagnostics(
        snapshot,
        _get_strinfo(curl, CURLINFO_EFFECTIVE_URL),
        _get_strinfo(curl, CURLINFO_PRIMARY_IP),
        _get_strinfo(curl, CURLINFO_LOCAL_IP),
        _get_typedinfo(Clong, curl, CURLINFO_PRIMARY_PORT),
        _get_typedinfo(Clong, curl, CURLINFO_LOCAL_PORT),
        _get_typedinfo(Cdouble, curl, CURLINFO_TOTAL_TIME),
        _get_typedinfo(Cdouble, curl, CURLINFO_CONNECT_TIME),
        _get_typedinfo(Cdouble, curl, CURLINFO_APPCONNECT_TIME),
        _get_typedinfo(Cdouble, curl, CURLINFO_NAMELOOKUP_TIME)
    )
end

function _curlfmt_split_url(u::AbstractString)
    m = match(r"^([a-zA-Z][a-zA-Z0-9+.-]*)://([^/ :]+)(?::(\d+))?(/.*)?$", u)
    if isnothing(m)
        return nothing, nothing, nothing, u
    end
    scheme = m.captures[1]
    host = m.captures[2]
    port = m.captures[3] === nothing ? nothing : tryparse(Int, m.captures[3])
    pathq = something(m.captures[4], "/")
    return scheme, host, port, pathq
end

function _curlfmt_http_version(v)
    v === nothing && return "?.?"
    try
        return Base.get(HTTP_VERSION_MAP, UInt64(v), "?.?")
    catch
        return "?.?"
    end
end

_curlfmt_time(x) = x === nothing ? "?\\" : string(round(x, digits = 3))

function _curlfmt_print_request_meta(io::IO, s::ReqSnapshot, scheme)
    println(io, "* EasyCurl diagnostics")
    println(io, "* URL: ", s.url)
    println(io, "* Method: ", s.method)
    !isnothing(scheme) && println(io, "* Protocol: ", scheme)
    s.proxy !== nothing && println(io, "* Proxy: ", s.proxy)
    s.interface !== nothing && println(io, "* Interface: ", s.interface)
    println(io, "* Connect timeout: $(s.connect_timeout) s")
    println(io, "* Read timeout: $(s.read_timeout) s")
    s.version !== nothing && println(io, "* Requested HTTP version: ", s.version)
end

function _curlfmt_print_connect_preamble(io::IO, d::CurlDiagnostics, host)
    if d.primary_ip !== nothing && d.primary_port !== nothing
        println(io, "* Trying $(d.primary_ip):$(d.primary_port)...")
    end
    if host !== nothing && d.primary_ip !== nothing && d.primary_port !== nothing && !isempty(d.primary_ip) && d.primary_port != 0
        println(io, "* Connected to $(host) ($(d.primary_ip)) port $(d.primary_port) (#0)")
    end
end

function _curlfmt_print_request(io::IO, s::ReqSnapshot, host, port, pathq)
    httpver = _curlfmt_http_version(s.version)
    path = pathq === nothing ? "/" : pathq
    println(io, "> ", s.method, " ", path, " HTTP/", httpver)
    if host !== nothing
        if port === nothing
            println(io, "> Host: ", host)
        else
            println(io, "> Host: ", host, ":", port)
        end
    end
    for (k, v) in _redact_headers(s.headers)
        println(io, "> ", k, ": ", v)
    end
    println(io, ">")
end

function _curlfmt_print_body_len(io::IO, s::ReqSnapshot)
    println(io, "* Body length: ", s.body_len)
end

function _curlfmt_print_endpoints(io::IO, d::CurlDiagnostics)
    lip = d.local_ip === nothing ? "?\\" : d.local_ip
    lport = d.local_port === nothing ? "?\\" : string(d.local_port)
    rip = d.primary_ip === nothing ? "?\\" : d.primary_ip
    rport = d.primary_port === nothing ? "?\\" : string(d.primary_port)

    if d.local_ip !== nothing || d.primary_ip !== nothing
        println(io, "* Local: ", lip, ":", lport)
        println(io, "* Remote: ", rip, ":", rport)
    end
    d.effective_url !== nothing && println(io, "* Effective URL: ", d.effective_url)
end

function _curlfmt_print_timings(io::IO, d::CurlDiagnostics)
    println(io, "* Namelookup: ", _curlfmt_time(d.time_name_lookup), " s")
    println(io, "* Connect: ", _curlfmt_time(d.time_connect), " s")
    println(io, "* AppConnect: ", _curlfmt_time(d.time_app_connect), " s")
    println(io, "* Total: ", _curlfmt_time(d.time_total), " s")
end

function Base.show(io::IO, d::CurlDiagnostics)
    if d.req !== nothing
        s = d.req::ReqSnapshot
        scheme, host, port, pathq = _curlfmt_split_url(s.url)
        _curlfmt_print_request_meta(io, s, scheme)
        _curlfmt_print_connect_preamble(io, d, host)
        _curlfmt_print_request(io, s, host, port, pathq)
        _curlfmt_print_body_len(io, s)
    else
        println(io, "* EasyCurl diagnostics")
        println(io, "* (no request snapshot)")
    end

    _curlfmt_print_endpoints(io, d)
    _curlfmt_print_timings(io, d)
    return nothing
end

"""
    CurlEasyError <: AbstractCurlError

Represents an error from a libcurl easy interface call.

## Fields
- `code::Int`: The libcurl error code.
- `message::String`: The corresponding error message from libcurl.
- `diagnostics::CurlDiagnostics`: diagnostic struct, that will contain virtually all context info if available

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
    diagnostics::CurlDiagnostics

    function CurlEasyError(c::Integer, curl)
        msg = unsafe_string(LibCURL.curl_easy_strerror(UInt32(c)))
        buf = _errorbuffer_msg(curl.error_buffer)
        diag = CurlDiagnostics(curl)
        return new{Int(c)}(Int(c), msg, buf, diag)
    end
end

"""
    CurlMultiError <: AbstractCurlError

Represents an error from a libcurl multi interface call.

## Fields
- `code::Int`: The libcurl multi error code.
- `message::String`: The corresponding error message from libcurl.
- `diagnostics::CurlDiagnostics`: diagnostic struct, that will contain virtually all context info if available

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
    diagnostics::CurlDiagnostics

    function CurlMultiError(c::Integer, curl)
        msg = unsafe_string(LibCURL.curl_multi_strerror(UInt32(c)))
        buf = _errorbuffer_msg(curl.error_buffer)
        diag = CurlDiagnostics(curl)
        return new{Int(c)}(Int(c), msg, buf, diag)
    end
end

@inline function _get_strinfo(c::CurlClient, info::CURLINFO)
    ref = Ref{Cstring}()
    r_code = LibCURL.curl_easy_getinfo(c.easy_handle, info, ref)
    r_code == CURLE_OK || return nothing
    p = ref[]
    return p == C_NULL ? nothing : unsafe_string(p)
end

@inline function _get_typedinfo(::Type{T}, c::CurlClient, info::CURLINFO) where {T}
    r = Ref{T}()
    r_code = LibCURL.curl_easy_getinfo(c.easy_handle, info, r)
    r_code == CURLE_OK && return r[]
    return nothing
end

function _redact_headers(h::Vector{Pair{String,String}})
    secrets = Set(["authorization", "proxy-authorization", "cookie", "set-cookie"])
    out = Pair{String,String}[]
    for (k, v) in h
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
                if m.code == CURLE_WRITE_ERROR && r_ctx !== nothing && !isopen(r_ctx.stream)
                    return
                end
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

Base.@kwdef mutable struct CurlResponseContext
    status::Int = 0
    version::Int = 0
    total_time::Float64 = 0.0
    stream::IOBuffer = IOBuffer(; append = true)
    headers::Vector{Pair{String,String}} = []
    on_data::Union{Nothing,Function} = nothing
    error::Union{Nothing,Exception} = nothing
    req_snapshot::Union{Nothing,ReqSnapshot} = nothing
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
        isopen(r_ctx.stream) || return UInt64(0)
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
