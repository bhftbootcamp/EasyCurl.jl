module EasyCurl

export curl_open,
    curl_request,
    curl_get,
    curl_patch,
    curl_post,
    curl_put,
    curl_head,
    curl_delete

export curl_body,
    curl_status,
    curl_headers,
    curl_request_time,
    curl_iserror

export CurlClient,
    CurlRequest,
    CurlResponse,
    CurlError,
    CurlStatusError

using LibCURL

"""
    DEFAULT_CONNECT_TIMEOUT = 60

The default connection timeout for an Curl Client in seconds.
"""
const DEFAULT_CONNECT_TIMEOUT = 60

"""
    DEFAULT_READ_TIMEOUT = 300

The default read timeout for an Curl Client in seconds.
"""
const DEFAULT_READ_TIMEOUT = 300

"""
    MAX_REDIRECTIONS = 5

The maximum number of redirections allowed for a request.
"""
const MAX_REDIRECTIONS = 5

include("Static.jl")
include("Utils.jl")

"""
    CurlClient

Represents a client for making HTTP requests using libcurl. Allows for connection reuse.

## Fields

- `curl_handle::Ptr{CURL}`: The libcurl easy handle.
- `multi_handle::Ptr{CURL}`: The libcurl multi handle.
"""
struct CurlClient
    curl_handle::Ptr{CURL}
    multi_handle::Ptr{CURL}

    CurlClient() = new(curl_easy_init(), curl_multi_init())
end

function Base.close(c::CurlClient)
    curl_multi_cleanup(c.multi_handle)
    curl_easy_cleanup(c.curl_handle)
end

"""
    CurlError{code} <: Exception

Type wrapping LibCURL error codes. Returned from [`curl_request`](@ref) when a libcurl error occurs.

## Fields
- `code::UInt32`: The LibCURL error code (see [libcurl error codes](https://curl.se/libcurl/c/libcurl-errors.html)).
- `message::String`: The error message.

## Examples
```julia-repl
julia> curl_request("GET", "http://httpbin.org/status/400", interface = "9.9.9.9")
ERROR: CurlError{45}(Failed binding local connection end)
[...]

julia> curl_request("GET", "http://httpbin.org/status/400", interface = "")
ERROR: CurlError{7}(Couldn't connect to server)
[...]
```
"""
struct CurlError{code} <: Exception
    code::UInt64
    message::String

    function CurlError(code::Integer, message::String)
        return new{code}(code, message)
    end
end

function Base.showerror(io::IO, e::CurlError)
    print(io, "CurlError{$(Int64(e.code))}(", e.message, ")")
end

mutable struct CurlContext
    curl_slist_ptr::Ptr{Nothing}
    curl_status::Vector{Clong}
    curl_total_time::Vector{Cdouble}
    curl_active::Vector{Cint}
    byte_received::UInt64
    headers::IOBuffer
    body::IOBuffer

    function CurlContext()
        ctx = new(
            C_NULL,
            Vector{Clong}(undef, 1),
            Vector{Cdouble}(undef, 1),
            Cint[1],
            0x0,
            IOBuffer(),
            IOBuffer(),
        )
        finalizer(close, ctx)
        return ctx
    end
end

function Base.close(x::CurlContext)
    close(x.headers)
    close(x.body)
end

"""
    CurlResponse(x::CurlContext)

An HTTP response object returned on a request completion.

## Fields

- `status::Int64`: The HTTP status code of the response.
- `request_time::Float64`: The time taken for the HTTP request in seconds.
- `headers::Vector{Pair{String,String}}`: Headers received in the HTTP response.
- `body::Vector{UInt8}`: The response body as a vector of bytes.

## Accessors

- `curl_status(x::CurlResponse)` -> `Int64`: Returns the HTTP status code.
- `curl_request_time(x::CurlResponse)` -> `Float64`: Returns the request time.
- `curl_headers(x::CurlResponse)` -> `Vector{Pair{String,String}}`: Returns the headers.
- `curl_body(x::CurlResponse)` -> `Vector{UInt8}`: Returns the response body.
"""
struct CurlResponse
    status::Int64
    request_time::Float64
    headers::Vector{Pair{String,String}}
    body::Vector{UInt8}

    function CurlResponse(x::CurlContext)
        return new(
            x.curl_status[1],
            x.curl_total_time[1],
            parse_headers(take!(x.headers)),
            take!(x.body),
        )
    end
end

function Base.show(io::IO, x::CurlResponse)
    println(io, CurlResponse)
    println(io, "\"\"\"")
    println(io, "HTTP/1.1 $(x.status) $(Base.get(HTTP_STATUS_CODES, x.status, ""))")
    for (k, v) in x.headers
        println(io, "$k: '$v'")
    end
    println(io, "\"\"\"")
    if length(x.body) > 1000
        v = view(x.body, 1:1000)
        print(io, "    ", strip(String(v)))
        println(io, "\n    ⋮")
    else
        v = view(x.body, 1:length(x.body))
        println(io, "    ", strip(String(v)))
    end
end

curl_status(x::CurlResponse) = status(x)
status(x::CurlResponse) = x.status

curl_request_time(x::CurlResponse) = request_time(x)
request_time(x::CurlResponse) = x.request_time

curl_headers(x::CurlResponse) = headers(x)
headers(x::CurlResponse) = x.headers

function headers(x::CurlResponse, key::AbstractString)
    h = String[]
    for (k, v) in x.headers
        lowercase(key) == lowercase(k) && push!(h, v)
    end
    return h
end

curl_body(x::CurlResponse) = body(x)
body(x::CurlResponse) = x.body

curl_iserror(x::CurlResponse) = iserror(x.status)
iserror(x::CurlResponse) = x.status >= 400

"""
    CurlRequest

Represents an HTTP request object.

## Fields

- `method::String`: The HTTP method for the request (e.g., `"GET"`, `"POST"`).
- `url::String`: The target URL for the HTTP request.
- `method::String`: Specifies the HTTP method for the request (e.g., `"GET"`, `"POST"`).
- `url::String`: The target URL for the HTTP request.
- `headers::Vector{Pair{String, String}}`: A list of header key-value pairs to include in the request.
- `body::Vector{UInt8}`: The body of the request, represented as a vector of bytes.
- `connect_timeout::Real`: Timeout in seconds for establishing a connection.
- `read_timeout::Real`: Timeout in seconds for reading the response.
- `interface::Union{String,Nothing}`: Specifies a particular network interface to use for the request, or `nothing` to use the default.
- `proxy::Union{String,Nothing}`: Specifies a proxy server to use for the request, or `nothing` to bypass proxy settings.
- `accept_encoding::Union{String,Nothing}`: Specifies the accepted encodings for the response, such as `"gzip"`. Defaults to `nothing` if not set.
- `ssl_verifypeer::Bool`: Indicates whether SSL certificates should be verified (`true`) or not (`false`).
- `verbose::Bool`: When `true`, enables detailed output from Curl, useful for debugging purposes.
"""
struct CurlRequest
    method::String
    url::String
    headers::Vector{Pair{String,String}}
    body::Vector{UInt8}
    connect_timeout::Real
    read_timeout::Real
    interface::Union{String,Nothing}
    proxy::Union{String,Nothing}
    accept_encoding::Union{String,Nothing}
    ssl_verifypeer::Bool
    verbose::Bool
    ctx::CurlContext

    function CurlRequest(
        method::AbstractString,
        url::AbstractString;
        headers::Vector{Pair{String,String}} = Pair{String,String}[],
        body::Vector{UInt8} = UInt8[],
        connect_timeout::Real = DEFAULT_CONNECT_TIMEOUT,
        read_timeout::Real = DEFAULT_READ_TIMEOUT,
        interface::Union{String,Nothing} = nothing,
        proxy::Union{String,Nothing} = nothing,
        accept_encoding::Union{String,Nothing} = nothing,
        ssl_verifypeer::Bool = true,
        verbose::Bool = false,
    )
        return new(
            method,
            url,
            headers,
            body,
            connect_timeout,
            read_timeout,
            interface,
            proxy,
            accept_encoding,
            ssl_verifypeer,
            verbose,
            CurlContext(),
        )
    end
end

"""
    CurlStatusError{code} <: Exception

Type wrapping HTTP error codes. Returned from [`curl_request`](@ref) when an HTTP error occurs.

## Fields
- `code::Int64`: The HTTP error code (see [`HTTP_STATUS_CODES`](@ref)).
- `message::String`: The error message.
- `response::CurlResponse`: The HTTP response object.

## Examples
```julia-repl
julia> curl_request("GET", "http://httpbin.org/status/400", interface = "0.0.0.0")
ERROR: CurlStatusError{400}(BAD_REQUEST)
[...]

julia> curl_request("GET", "http://httpbin.org/status/404", interface = "0.0.0.0")
ERROR: CurlStatusError{404}(NOT_FOUND)
[...]
```
"""
struct CurlStatusError{code} <: Exception
    code::Int64
    message::String
    response::CurlResponse

    function CurlStatusError(x::CurlResponse)
        return new{status(x)}(status(x), Base.get(HTTP_STATUS_CODES, status(x), HTTP_STATUS_CODES[500]), x)
    end
end

function Base.showerror(io::IO, e::CurlStatusError)
    print(io, "CurlStatusError{$(e.code)}(", e.message, ")")
end

#__ libcurl

function curl_write_cb(curlbuf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    result = unsafe_pointer_to_objref(p_ctxt)
    sz = s * n
    result.byte_received += sz
    unsafe_write(result.body, curlbuf, sz)
    return sz::Csize_t
end

function curl_header_cb(curlbuf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    result = unsafe_pointer_to_objref(p_ctxt)
    sz = s * n
    unsafe_write(result.headers, curlbuf, sz)
    return sz::Csize_t
end

function curl_option!(c::CurlClient, x...)
    return curl_easy_setopt(c.curl_handle, x...)
end

function curl_setup!(c::CurlClient, r::CurlRequest)
    curl_option!(c, CURLOPT_URL, r.url)
    curl_option!(c, CURLOPT_CAINFO, LibCURL.cacert)
    curl_option!(c, CURLOPT_FOLLOWLOCATION, 1)
    curl_option!(c, CURLOPT_MAXREDIRS, MAX_REDIRECTIONS)
    curl_option!(c, CURLOPT_CONNECTTIMEOUT, r.connect_timeout)
    curl_option!(c, CURLOPT_TIMEOUT, r.read_timeout)
    curl_option!(c, CURLOPT_WRITEFUNCTION, curl_write_cb)
    curl_option!(c, CURLOPT_INTERFACE, something(r.interface, C_NULL))
    curl_option!(c, CURLOPT_ACCEPT_ENCODING, something(r.accept_encoding, C_NULL))
    curl_option!(c, CURLOPT_SSL_VERIFYPEER, r.ssl_verifypeer)
    curl_option!(c, CURLOPT_USERAGENT, "EasyCurl/3.0.0")
    curl_option!(c, CURLOPT_PROXY, something(r.proxy, C_NULL))
    curl_option!(c, CURLOPT_VERBOSE, r.verbose)

    c_curl_write_cb =
        @cfunction(curl_write_cb, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))

    c_curl_header_cb =
        @cfunction(curl_header_cb, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))

    curl_option!(c, CURLOPT_WRITEFUNCTION, c_curl_write_cb)
    curl_option!(c, CURLOPT_WRITEDATA, pointer_from_objref(r.ctx))

    curl_option!(c, CURLOPT_HEADERFUNCTION, c_curl_header_cb)
    curl_option!(c, CURLOPT_HEADERDATA, pointer_from_objref(r.ctx))

    for (k,v) in r.headers
        r.ctx.curl_slist_ptr =
            curl_slist_append(r.ctx.curl_slist_ptr, k * ": " * v)
    end

    curl_option!(c, CURLOPT_HTTPHEADER, r.ctx.curl_slist_ptr)
end

mutable struct CurlMsgCtx
    msg::CURLMSG
    easy_handle::Ptr{CURL}
    data::Ptr{Any}
end

function curl_execute(c::CurlClient, r::CurlRequest)
    try
        curl_multi_add_handle(c.multi_handle, c.curl_handle)
        curl_multi_perform(c.multi_handle, r.ctx.curl_active)

        while (r.ctx.curl_active[1] > 0)
            byte_received_before = r.ctx.byte_received
            curl_m_code = curl_multi_perform(c.multi_handle, r.ctx.curl_active)
            byte_received_after = r.ctx.byte_received
            if curl_m_code != CURLE_OK
                throw(CurlError(curl_m_code, unsafe_string(curl_multi_strerror(curl_m_code))))
            end
            if !(byte_received_after > byte_received_before)
                sleep(0.001)
            end
        end

        msgs_in_queue = Vector{Int32}(undef, 1)
        ptr_msg::Ptr{CurlMsgCtx} = curl_multi_info_read(c.multi_handle, msgs_in_queue)

        while ptr_msg != C_NULL
            msg = unsafe_load(ptr_msg)
            ptr_msg = curl_multi_info_read(c.multi_handle, msgs_in_queue)
            msg.msg != CURLMSG_DONE && continue
            curl_code = convert(UInt32, msg.data)
            if curl_code != CURLE_OK
                throw(CurlError(curl_code, unsafe_string(curl_easy_strerror(curl_code))))
            end
        end

        curl_easy_getinfo(c.curl_handle, CURLINFO_RESPONSE_CODE, r.ctx.curl_status)
        curl_easy_getinfo(c.curl_handle, CURLINFO_TOTAL_TIME, r.ctx.curl_total_time)
    finally
        curl_multi_remove_handle(c.multi_handle, c.curl_handle)
        curl_slist_free_all(r.ctx.curl_slist_ptr)
    end
end

function curl_execute(::Val{:GET}, c::CurlClient, r::CurlRequest)
    curl_setup!(c, r)
    curl_option!(c, CURLOPT_HTTPGET, 1)
    curl_execute(c, r)
end

function curl_execute(::Val{:HEAD}, c::CurlClient, r::CurlRequest)
    curl_setup!(c, r)
    curl_option!(c, CURLOPT_NOBODY, 1);
    curl_execute(c, r)
end

function curl_execute(::Val{:POST}, c::CurlClient, r::CurlRequest)
    curl_setup!(c, r)
    curl_option!(c, CURLOPT_POST, 1)
    curl_option!(c, CURLOPT_POSTFIELDSIZE, length(r.body))
    curl_option!(c, CURLOPT_COPYPOSTFIELDS, pointer(r.body))
    curl_execute(c, r)
end

function curl_execute(::Val{:PUT}, c::CurlClient, r::CurlRequest)
    curl_setup!(c, r)
    curl_option!(c, CURLOPT_POSTFIELDS, r.body)
    curl_option!(c, CURLOPT_POSTFIELDSIZE, length(r.body))
    curl_option!(c, CURLOPT_CUSTOMREQUEST, "PUT")
    curl_execute(c, r)
end

function curl_execute(::Val{:PATCH}, c::CurlClient, r::CurlRequest)
    curl_setup!(c, r)
    curl_option!(c, CURLOPT_POSTFIELDS, r.body)
    curl_option!(c, CURLOPT_POSTFIELDSIZE, length(r.body))
    curl_option!(c, CURLOPT_CUSTOMREQUEST, "PATCH");
    curl_execute(c, r)
end

function curl_execute(::Val{:DELETE}, c::CurlClient, r::CurlRequest)
    curl_setup!(c, r)
    curl_option!(c, CURLOPT_POSTFIELDS, r.body)
    curl_option!(c, CURLOPT_CUSTOMREQUEST, "DELETE")
    curl_execute(c, r)
end

function curl_execute(::Val{x}, ::CurlClient, ::CurlRequest) where {x}
    throw(CurlError(405, "`$(x)` method not supported"))
end

function _curl_execute(c::CurlClient, r::CurlRequest)
    return curl_execute(Val(Symbol(r.method)), c, r)
end

"""
    curl_request(method::AbstractString, url::AbstractString; kw...) -> CurlResponse

Send a `url` HTTP CurlRequest using as `method` one of `"GET"`, `"POST"`, etc. and return a [`CurlResponse`](@ref) object.

## Keyword arguments

- `headers = Pair{String,String}[]`: The headers for the request.
- `body = nothing`: The body for the request.
- `query = nothing`: The query string for the request.
- `interface = nothing`: The interface for the request.
- `status_exception = true`: Whether to throw an exception if the response status code indicates an error.
- `connect_timeout = 60`: The connect timeout for the request in seconds.
- `read_timeout = 300`: The read timeout for the request in seconds.
- `retry = 1`: The number of times to retry the request if an error occurs.
- `proxy = nothing`: Which proxy to use for the request.
- `accept_encoding = "gzip"`: Encoding to accept.
- `verbose::Bool = false`: Enables verbose output from Curl for debugging.
- `ssl_verifypeer = true`: Whether peer need to be verified.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = curl_request("POST", "http://httpbin.org/post", headers = headers, query = "qry=你好嗎",
    body = "{\\"data\\":\\"hi\\"}", interface = "en0", read_timeout = 5, connect_timeout = 10, retry = 10)

julia> curl_status(response)
200

julia> curl_body(response) |> String |> print
{
  "headers": {
    "X-Amzn-Trace-Id": "Root=1-6588a009-19f3dc0321bee38106226bb3",
    "Content-Length": "13",
    "Host": "httpbin.org",
    "Accept": "*/*",
    "Content-Type": "application/json",
    "Accept-Encoding": "gzip",
    "User-Agent": "EasyCurl.jl"
  },
  "json": {
    "data": "hi"
  },
  "files": {},
  "args": {
    "qry": "你好嗎"
  },
  "data": "{\\"data\\":\\"hi\\"}",
  "url": "http://httpbin.org/post?qry=你好嗎",
  "form": {},
  "origin": "100.250.50.140"
}
```
"""
function curl_request(x...; kw...)
    return request(x...; kw...)
end

function request(method::AbstractString, url::AbstractString; kw...)
    return curl_open(c -> request(c, method, url; kw...))
end

function request(
    curl_client::CurlClient,
    method::AbstractString,
    url::AbstractString;
    headers::Vector{Pair{String,String}} = Pair{String,String}[],
    query = nothing,
    body = nothing,
    status_exception::Bool = true,
    retry::Int64 = 1,
    kw...,
)::CurlResponse
    @label retry

    req = CurlRequest(
        method,
        req_url(curl_client.curl_handle, url, query);
        headers = headers,
        body = to_bytes(body),
        kw...,
    )

    try
        _curl_execute(curl_client, req)
        r = CurlResponse(req.ctx)
        status_exception && iserror(r) &&
            throw(CurlStatusError(r))
        r
    catch e
        retry = retry - 1
        sleep(0.25)
        retry >= 0 && @goto retry
        rethrow()
    end
end

"""
    curl_open(f::Function, x...; kw...)

A helper function for executing a batch of curl requests, using the same client. Optionally
configure the client (see [`CurlClient`](@ref) for more details).

## Examples

```julia-repl
julia> curl_open() do client
           response = curl_request(client, "GET", "http://httpbin.org/get")
           println(curl_status(response))
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

"""
    curl_get(url::AbstractString; kw...) -> CurlResponse

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("GET", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = curl_get("http://httpbin.org/get", headers = headers,
    query = Dict{String,String}("qry" => "你好嗎"))

julia> curl_status(response)
200

julia> curl_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  },
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Content-Type": "application/json",
    "Host": "httpbin.org",
    "User-Agent": "EasyCurl.jl",
    "X-Amzn-Trace-Id": "Root=1-6589e259-24815d6d62da962a06fc7edf"
  },
  "origin": "100.250.50.140",
  "url": "http://httpbin.org/get?qry=\u4f60\u597d\u55ce"
}
```
"""
curl_get(url; kw...) = get(url; kw...)
get(url; kw...)::CurlResponse = request("GET", url; kw...)

"""
    curl_head(url::AbstractString; kw...) -> CurlResponse

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("HEAD", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = curl_head("http://httpbin.org/get", headers = headers,
    query = "qry=你好嗎", interface = "0.0.0.0")

julia> curl_status(response)
200

julia> curl_body(response)
UInt8[]
```
"""
curl_head(url; kw...) = head(url; kw...)
head(url; kw...)::CurlResponse = request("HEAD", url; kw...)

"""
    curl_post(url::AbstractString; kw...) -> CurlResponse

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("POST", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = curl_post("http://httpbin.org/post", headers = headers,
    query = "qry=你好嗎", body = "{\\"data\\":\\"hi\\"}")

julia> curl_status(response)
200

julia> curl_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  },
  "data": "{\\"data\\":\\"hi\\"}",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Content-Length": "13",
    "Content-Type": "application/json",
    "Host": "httpbin.org",
    "User-Agent": "EasyCurl.jl",
    "X-Amzn-Trace-Id": "Root=1-6589e32c-7f09b85d56e11aea59cde1d6"
  },
  "json": {
    "data": "hi"
  },
  "origin": "100.250.50.140",
  "url": "http://httpbin.org/post?qry=\u4f60\u597d\u55ce"
}
```
"""
curl_post(url; kw...) = post(url; kw...)
post(url; kw...)::CurlResponse = request("POST", url; kw...)

"""
    curl_put(url::AbstractString; kw...) -> CurlResponse

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("PUT", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = curl_put("http://httpbin.org/put", headers = headers,
    query = "qry=你好嗎", body = "{\\"data\\":\\"hi\\"}")

julia> curl_status(response)
200

julia> curl_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  },
  "data": "{\\"data\\":\\"hi\\"}",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Content-Length": "13",
    "Content-Type": "application/json",
    "Host": "httpbin.org",
    "User-Agent": "EasyCurl.jl",
    "X-Amzn-Trace-Id": "Root=1-6589e3b0-58cdde84399ad8be30eb4e46"
  },
  "json": {
    "data": "hi"
  },
  "origin": "100.250.50.140",
  "url": "http://httpbin.org/put?qry=\u4f60\u597d\u55ce"
}
```
"""
curl_put(url; kw...) = put(url; kw...)
put(url; kw...)::CurlResponse = request("PUT", url; kw...)

"""
    curl_patch(url::AbstractString; kw...) -> CurlResponse

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("PATCH", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = curl_patch("http://httpbin.org/patch", headers = headers,
    query = "qry=你好嗎", body = "{\\"data\\":\\"hi\\"}")

julia> curl_status(response)
200

julia> curl_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  },
  "data": "{\\"data\\":\\"hi\\"}",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Content-Length": "13",
    "Content-Type": "application/json",
    "Host": "httpbin.org",
    "User-Agent": "EasyCurl.jl",
    "X-Amzn-Trace-Id": "Root=1-6589e410-33f8cb5a31db9fba6c0a746f"
  },
  "json": {
    "data": "hi"
  },
  "origin": "100.250.50.140",
  "url": "http://httpbin.org/patch?qry=\u4f60\u597d\u55ce"
}
```
"""
curl_patch(url; kw...) = patch(url; kw...)
patch(url; kw...)::CurlResponse = request("PATCH", url; kw...)

"""
    curl_delete(url::AbstractString; kw...) -> CurlResponse

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("DELETE", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = curl_delete("http://httpbin.org/delete", headers = headers,
    query = "qry=你好嗎", body = "{\\"data\\":\\"hi\\"}")

julia> curl_status(response)
200

julia> curl_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  },
  "data": "{\\"data\\":\\"hi\\"}",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Content-Length": "13",
    "Content-Type": "application/json",
    "Host": "httpbin.org",
    "User-Agent": "EasyCurl.jl",
    "X-Amzn-Trace-Id": "Root=1-6589e5f7-1c1ff2407f567ff17786576d"
  },
  "json": {
    "data": "hi"
  },
  "origin": "100.250.50.140",
  "url": "http://httpbin.org/delete?qry=\u4f60\u597d\u55ce"
}
```
"""
curl_delete(url; kw...) = delete(url; kw...)
delete(url; kw...)::CurlResponse = request("DELETE", url; kw...)

end
