module Curl

export curl_request,
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

using LibCURL

const MAX_REDIRECTIONS = 5
const DEFAULT_CONNECT_TIMEOUT = 60  # seconds
const DEFAULT_READ_TIMEOUT = 300  # seconds

include("Static.jl")
include("Utils.jl")

struct CurlError <: Exception
    message::String
end

Base.show(io::IO, e::CurlError) = print(io, "CurlError: ", e.message)

abstract type HttpMessage end

const Header = Pair{String,String}

#__ struct

mutable struct CurlResponse
    curl_slist::Ptr{Nothing}
    curl_status::Vector{Clong}
    curl_total_time::Vector{Cdouble}
    curl_active::Vector{Cint}
    rx_count::UInt64
    b_data::IOBuffer
    h_data::IOBuffer

    function CurlResponse()
        return new(
            C_NULL,
            Vector{Clong}(undef, 1),
            Vector{Cdouble}(undef, 1),
            Cint[1],
            0x0,
            IOBuffer(),
            IOBuffer(),
        )
    end
end

status(x::CurlResponse) = x.curl_status[1]
request_time(x::CurlResponse) = x.curl_total_time[1]
headers(x::CurlResponse) = parse_headers(String(take!(x.h_data)))
body(x::CurlResponse) = take!(x.b_data)

"""
    Curl.Response(x::CurlResponse)

Represents an HTTP response object that can be received from a `CurlResponse`.

## Fields

- `status::Int64`: The HTTP status code of the response.
- `request_time::Float64`: The time taken for the HTTP request in seconds.
- `headers::Vector{Pair{String,String}}`: Headers received in the HTTP response.
- `body::Vector{UInt8}`: The response body as a vector of bytes.

See also: [`curl_status`](@ref), [`curl_request_time`](@ref), [`curl_headers`](@ref), [`curl_body`](@ref), [`curl_iserror`](@ref)
"""
struct Response
    status::Int64
    request_time::Float64
    headers::Vector{Pair{String,String}}
    body::Vector{UInt8}

    function Response(x::CurlResponse)
        return new(status(x), request_time(x), headers(x), body(x))
    end
end

"""
    curl_status(x::Response) -> Int64

Extracts the HTTP status code from a [`Curl.Response`](@ref) object.
"""
curl_status(x::Response) = status(x)
status(x::Response) = x.status

"""
    curl_request_time(x::Response) -> Float64

Extracts the request time from a [`Curl.Response`](@ref) object.
"""
curl_request_time(x::Response) = request_time(x)
request_time(x::Response) = x.request_time

"""
    curl_headers(x::Response) -> Vector{Pair{String,String}}

Parses the HTTP headers from a [`Curl.Response`](@ref) object.
"""
curl_headers(x::Response) = headers(x)
headers(x::Response) = x.headers

"""
    curl_body(x::Response) -> Vector{UInt8}

Extracts the response body from a [`Curl.Response`](@ref) object.
"""
curl_body(x::Response) = body(x)
body(x::Response) = x.body

"""
    curl_iserror(x::Response) -> Bool

Check that [`Curl.Response`](@ref) have an error status
"""
curl_iserror(x::Response) = iserror(x)
iserror(x::Response) = x.status >= 300

function headers(x::Response, key::AbstractString)
    hdrs = String[]
    for (k, v) in x.headers
        key == k && push!(hdrs, v)
    end
    return hdrs
end

function Base.show(io::IO, x::Response)
    println(io, Response)
    println(io, "\"\"\"")
    println(io, "HTTP/1.1 $(x.status) $(get(HTTP_STATUS_CODES, x.status, ""))")
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

"""
    Request <: HttpMessage

Represents an HTTP request object.

## Fields

- `method::String`: The HTTP request method (e.g. `"GET"`, `"POST"`, etc.).
- `url::String`: The URL to which the request is sent.
- `headers::Vector{Pair{String, String}}`: Headers for the HTTP request.
- `body::Vector{UInt8}`: The request body as a vector of bytes.
- `connect_timeout::Real`: The connection timeout for the request in seconds.
- `read_timeout::Real`: The read timeout for the response in seconds.
- `interface::Union{String, Nothing}`: The network interface to use (or `nothing` for the default).
- `proxy::Union{String, Nothing}`: The proxy server to use (or `nothing` for no proxy).
- `accept_encoding::String`: The accepted encoding for the response (e.g., "gzip").
- `ssl_verifypeer::Bool`: Whether to verify SSL certificates.
- `verbose::Bool`: Enables verbose output from Curl for debugging.
- `rq_curl::Ptr{CURL}`: A pointer to a Curl handle for the request.
- `rq_multi::Ptr{CURL}`: A pointer to a Curl multi handle for the request.
- `response::CurlResponse`: The HTTP response associated with this request.
"""
struct Request <: HttpMessage
    method::String
    url::String
    headers::Vector{Pair{String,String}}
    body::Vector{UInt8}
    connect_timeout::Real
    read_timeout::Real
    interface::Union{String,Nothing}
    proxy::Union{String,Nothing}
    accept_encoding::String
    ssl_verifypeer::Bool
    verbose::Bool
    rq_curl::Ptr{CURL}
    rq_multi::Ptr{CURL}
    response::CurlResponse
end

struct StatusError <: Exception
    message::String
    response::Response

    function StatusError(x::Response)
        return new(get(HTTP_STATUS_CODES, status(x), HTTP_STATUS_CODES[500]), x)
    end
end

Base.show(io::IO, e::StatusError) = print(io, StatusError, "(", status(e.response), " ,", "\"", e.message, "\"", ")")

#__ libcurl

function curl_write_cb(curlbuf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    response = unsafe_pointer_to_objref(p_ctxt)
    sz = s * n
    response.rx_count += sz
    unsafe_write(response.b_data, curlbuf, sz)
    return sz::Csize_t
end

function curl_header_cb(curlbuf::Ptr{UInt8}, s::Csize_t, n::Csize_t, p_ctxt::Ptr{Cvoid})
    response = unsafe_pointer_to_objref(p_ctxt)
    sz = s * n
    unsafe_write(response.h_data, curlbuf, sz)
    return sz::Csize_t
end

function curl_setup_rq(request::Request)
    curl_easy_setopt(request.rq_curl, CURLOPT_URL, request.url)
    curl_easy_setopt(request.rq_curl, CURLOPT_CAINFO, LibCURL.cacert)
    curl_easy_setopt(request.rq_curl, CURLOPT_FOLLOWLOCATION, 1)
    curl_easy_setopt(request.rq_curl, CURLOPT_MAXREDIRS, MAX_REDIRECTIONS)
    curl_easy_setopt(request.rq_curl, CURLOPT_CONNECTTIMEOUT, request.connect_timeout)
    curl_easy_setopt(request.rq_curl, CURLOPT_TIMEOUT, request.read_timeout)
    curl_easy_setopt(request.rq_curl, CURLOPT_WRITEFUNCTION, curl_write_cb)
    curl_easy_setopt(request.rq_curl, CURLOPT_INTERFACE, something(request.interface, C_NULL))
    curl_easy_setopt(request.rq_curl, CURLOPT_ACCEPT_ENCODING, request.accept_encoding)
    curl_easy_setopt(request.rq_curl, CURLOPT_SSL_VERIFYPEER, request.ssl_verifypeer)
    curl_easy_setopt(request.rq_curl, CURLOPT_USERAGENT, "Curl/1.2.0")
    curl_easy_setopt(request.rq_curl, CURLOPT_PROXY, something(request.proxy, C_NULL))
    curl_easy_setopt(request.rq_curl, CURLOPT_VERBOSE, request.verbose)

    c_curl_write_cb =
        @cfunction(curl_write_cb, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))

    c_curl_header_cb =
        @cfunction(curl_header_cb, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))

    curl_easy_setopt(request.rq_curl, CURLOPT_WRITEFUNCTION, c_curl_write_cb)
    curl_easy_setopt(request.rq_curl, CURLOPT_WRITEDATA, pointer_from_objref(request.response))

    curl_easy_setopt(request.rq_curl, CURLOPT_HEADERFUNCTION, c_curl_header_cb)
    curl_easy_setopt(request.rq_curl, CURLOPT_HEADERDATA, pointer_from_objref(request.response))

    for (k,v) in request.headers
        request.response.curl_slist =
            curl_slist_append(request.response.curl_slist, k * ": " * v)
    end

    curl_easy_setopt(request.rq_curl, CURLOPT_HTTPHEADER, request.response.curl_slist)
end

mutable struct CurlMsg
    msg::CURLMSG
    easy_handle::Ptr{CURL}
    data::Ptr{Any}
end

function curl_rq_handle(request::Request)
    try
        curl_multi_add_handle(request.rq_multi, request.rq_curl)
        curl_multi_perform(request.rq_multi, request.response.curl_active)

        while (request.response.curl_active[1] > 0)
            rx_count_before = request.response.rx_count
            multi_perf = curl_multi_perform(request.rq_multi, request.response.curl_active)
            rx_count_after = request.response.rx_count
            if multi_perf != CURLE_OK
                throw(CurlError(unsafe_string(curl_multi_strerror(multi_perf))))
            end
            if !(rx_count_after > rx_count_before)
                sleep(0.001)
            end
        end

        msgs_in_queue = Vector{Int32}(undef, 1)
        ptr_msg::Ptr{CurlMsg} = curl_multi_info_read(request.rq_multi, msgs_in_queue)

        while ptr_msg != C_NULL
            msg = unsafe_load(ptr_msg)
            ptr_msg = curl_multi_info_read(request.rq_multi, msgs_in_queue)
            msg.msg != CURLMSG_DONE && continue
            msg_data = convert(Int64, msg.data)
            if msg_data != CURLE_OK
                throw(CurlError(unsafe_string(curl_easy_strerror(msg_data))))
            end
        end

        curl_easy_getinfo(request.rq_curl, CURLINFO_RESPONSE_CODE, request.response.curl_status)
        curl_easy_getinfo(request.rq_curl, CURLINFO_TOTAL_TIME, request.response.curl_total_time)
    finally
        curl_multi_remove_handle(request.rq_multi, request.rq_curl)
        curl_multi_cleanup(request.rq_multi)
        curl_slist_free_all(request.response.curl_slist)
        curl_easy_cleanup(request.rq_curl)
    end
end

function curl_rq_handle(::Val{:GET}, request::Request)
    try
        curl_setup_rq(request)
        curl_easy_setopt(request.rq_curl, CURLOPT_HTTPGET, 1)
        curl_rq_handle(request)
    catch ex
        rethrow(ex)
    end
end

function curl_rq_handle(::Val{:HEAD}, request::Request)
    try
        curl_setup_rq(request)
        curl_easy_setopt(request.rq_curl, CURLOPT_NOBODY, 1);
        curl_rq_handle(request)
    catch ex
        rethrow(ex)
    end
end

function curl_rq_handle(::Val{:POST}, request::Request)
    try
        curl_setup_rq(request)
        curl_easy_setopt(request.rq_curl, CURLOPT_POST, 1)
        curl_easy_setopt(request.rq_curl, CURLOPT_POSTFIELDSIZE, length(request.body))
        curl_easy_setopt(request.rq_curl, CURLOPT_COPYPOSTFIELDS, pointer(request.body))
        curl_rq_handle(request)
    catch ex
        rethrow(ex)
    end
end

function curl_rq_handle(::Val{:PUT}, request::Request)
    try
        curl_setup_rq(request)
        curl_easy_setopt(request.rq_curl, CURLOPT_POSTFIELDS, request.body)
        curl_easy_setopt(request.rq_curl, CURLOPT_POSTFIELDSIZE, length(request.body))
        curl_easy_setopt(request.rq_curl, CURLOPT_CUSTOMREQUEST, "PUT")
        curl_rq_handle(request)
    catch ex
        rethrow(ex)
    end
end

function curl_rq_handle(::Val{:PATCH}, request::Request)
    try
        curl_setup_rq(request)
        curl_easy_setopt(request.rq_curl, CURLOPT_POSTFIELDS, request.body)
        curl_easy_setopt(request.rq_curl, CURLOPT_POSTFIELDSIZE, length(request.body))
        curl_easy_setopt(request.rq_curl, CURLOPT_CUSTOMREQUEST, "PATCH");
        curl_rq_handle(request)
    catch ex
        rethrow(ex)
    end
end

function curl_rq_handle(::Val{:DELETE}, request::Request)
    try
        curl_setup_rq(request)
        curl_easy_setopt(request.rq_curl, CURLOPT_POSTFIELDS, request.body)
        curl_easy_setopt(request.rq_curl, CURLOPT_CUSTOMREQUEST, "DELETE")
        curl_rq_handle(request)
    catch ex
        rethrow(ex)
    end
end

function curl_rq_handle(::Val{x}, request::Request) where {x}
    return throw(CurlError("`$(x)` method not supported"))
end

#__ request

to_query_decode(::Nothing) = ""
to_query_decode(x::S) where {S<:AbstractString} = x
to_query_decode(x::AbstractDict) = urlencode_query_params(x)

to_bytes(::Nothing) = Vector{UInt8}()
to_bytes(x::S) where {S<:AbstractString} = Vector{UInt8}(x)
to_bytes(x::Vector{UInt8}) = x

function rq_url(url::AbstractString, query)
    kv = to_query_decode(query)
    return isempty(kv) ? url : url * "?" * kv
end

"""
    curl_request(method::AbstractString, url::AbstractString; kw...) -> Curl.Response

Send a `url` HTTP Request using as `method` one of `"GET"`, `"POST"`, etc. and return a [`Curl.Response`](@ref) object.

## Keyword arguments

- `headers = Pair{String,String}[]`: The headers for the request.
- `body = nothing`: The body for the request.
- `query = nothing`: The query string for the request.
- `interface = nothing`: The interface for the request.
- `status_exception = true`: Whether to throw an exception if the response status code indicates an error.
- `connect_timeout = 60`: The connect timeout for the request in seconds.
- `read_timeout = 300`: The read timeout for the request in seconds.
- `retries = 1`: The number of times to retry the request if an error occurs.
- `proxy = nothing`: Which proxy to use for the request.
- `accept_encoding = "gzip"`: Encoding to accept.
- `verbose::Bool = false`: Enables verbose output from Curl for debugging.
- `ssl_verifypeer = true`: Whether peer need to be verified.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
    "User-Agent" => "Curl.jl",
    "Content-Type" => "application/json"
]

julia> response = curl_request("POST", "http://httpbin.org/post", headers = headers, query = "qry=你好嗎",
    body = "{\\"data\\":\\"hi\\"}", interface = "en0", read_timeout = 5, connect_timeout = 10, retries = 10)

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
    "User-Agent": "Curl.jl"
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
function curl_request(method::AbstractString, url::AbstractString; kw...)
    return request(method, url; kw...)
end

function request(
    method::AbstractString,
    url::AbstractString;
    headers::Vector{Pair{String,String}} = Header[],
    query = nothing,
    body = nothing,
    connect_timeout::Real = DEFAULT_CONNECT_TIMEOUT,
    read_timeout::Real = DEFAULT_READ_TIMEOUT,
    interface::Union{String,Nothing} = nothing,
    proxy::Union{String,Nothing} = nothing,
    retries::Int64 = 1,
    status_exception::Bool = true,
    accept_encoding::String = "gzip",
    ssl_verifypeer::Bool = true,
    verbose::Bool = false,
)
    @label curl_request_retry

    req = Request(
        method,
        rq_url(url, query),
        headers,
        to_bytes(body),
        connect_timeout,
        read_timeout,
        interface,
        proxy,
        accept_encoding,
        ssl_verifypeer,
        verbose,
        curl_easy_init(),
        curl_multi_init(),
        CurlResponse(),
    )

    return try
        curl_rq_handle(Val(Symbol(req.method)), req)
        response = Response(req.response)
        if status_exception && iserror(response)
            throw(StatusError(response))
        end
        response
    catch e
        retries -= 1
        sleep(0.25)
        retries >= 0 && @goto curl_request_retry
        rethrow(e)
    end
end

"""
    curl_get(url::AbstractString; kw...) -> Curl.Response

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("GET", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
    "User-Agent" => "Curl.jl",
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
    "User-Agent": "Curl.jl",
    "X-Amzn-Trace-Id": "Root=1-6589e259-24815d6d62da962a06fc7edf"
  },
  "origin": "100.250.50.140",
  "url": "http://httpbin.org/get?qry=\u4f60\u597d\u55ce"
}
```
"""
curl_get(url; kw...) = get(url; kw...)
Base.get(url; kw...)::Response = request("GET", url; kw...)

"""
    curl_head(url::AbstractString; kw...) -> Curl.Response

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("HEAD", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
    "User-Agent" => "Curl.jl",
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
head(url; kw...)::Response = request("HEAD", url; kw...)

"""
    curl_post(url::AbstractString; kw...) -> Curl.Response

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("POST", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
    "User-Agent" => "Curl.jl",
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
    "User-Agent": "Curl.jl",
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
post(url; kw...)::Response = request("POST", url; kw...)

"""
    curl_put(url::AbstractString; kw...) -> Curl.Response

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("PUT", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
    "User-Agent" => "Curl.jl",
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
    "User-Agent": "Curl.jl",
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
put(url; kw...)::Response = request("PUT", url; kw...)

"""
    curl_patch(url::AbstractString; kw...) -> Curl.Response

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("PATCH", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
    "User-Agent" => "Curl.jl",
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
    "User-Agent": "Curl.jl",
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
patch(url; kw...)::Response = request("PATCH", url; kw...)

"""
    curl_delete(url::AbstractString; kw...) -> Curl.Response

Shortcut for [`curl_request`](@ref) function, work similar to `curl_request("DELETE", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
    "User-Agent" => "Curl.jl",
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
    "User-Agent": "Curl.jl",
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
delete(url; kw...)::Response = request("DELETE", url; kw...)

end
