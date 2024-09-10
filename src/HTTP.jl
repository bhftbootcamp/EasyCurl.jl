#__ HTTP

export http_request,
    http_get,
    http_patch,
    http_post,
    http_put,
    http_head,
    http_delete

export http_body,
    http_status,
    http_headers,
    http_request_time,
    http_iserror,
    http_header,
    http_joinurl

export HTTPResponse,
    HTTPRequest,
    HTTPOptions,
    HTTPStatusError

"""
    HTTP_VERSION_MAP::Dict{UInt64,String}

Maps CURL numerical constants for HTTP versions to their string representations.

## Mappings

- `CURL_HTTP_VERSION_1_0 => "1.0"`: HTTP 1.0
- `CURL_HTTP_VERSION_1_1 => "1.1"`: HTTP 1.1
- `CURL_HTTP_VERSION_2_0 => "2.0"`: HTTP 2.0
"""
const HTTP_VERSION_MAP = Dict{UInt64,String}(
    CURL_HTTP_VERSION_1_0 => "1.0",
    CURL_HTTP_VERSION_1_1 => "1.1",
    CURL_HTTP_VERSION_2_0 => "2.0",
)

"""
    HTTPResponse()

An HTTP response object returned on a request completion.

## Fields

- `status::Ref{UInt64}`: The HTTP status code of the response as a reference to an unsigned 64-bit integer.
- `version::Ref{UInt64}`: The HTTP version received in the response as a reference to an unsigned 64-bit integer.
- `request_time::Ref{Float64}`: The time taken for the HTTP request in seconds as a reference to a floating-point number.
- `headers::Vector{Pair{String, String}}`: Headers received in the HTTP response.
- `body::Vector{UInt8}`: The response body as a vector of bytes.
"""
mutable struct HTTPResponse <: CurlResponce
    status::Int
    version::Int
    request_time::Float64
    body::Vector{UInt8}
    headers::Vector{Pair{String,String}}

    function HTTPResponse()
        return new(0, 0, 0.0, Vector{UInt8}(), Vector{Pair{String,String}}())
    end
end

function Base.show(io::IO, x::HTTPResponse)
    println(io, HTTPResponse)
    println(io, "\"\"\"")
    print(io, "HTTP/", Base.get(HTTP_VERSION_MAP, x.version, "1.1"))
    println(io, " $(x.status) $(Base.get(HTTP_STATUS_CODES, x.status, ""))")
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
    http_status(x::HTTPResponse) -> Int

Extracts the HTTP status code from a [`HTTPResponse`](@ref) object.

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get")

julia> http_status(response)
200
```
"""
http_status(x::HTTPResponse) = x.status

"""
    http_request_time(x::HTTPResponse) -> Float64

Extracts the total request time for the HTTP request that resulted in the [`HTTPResponse`](@ref).

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get")

julia> http_request_time(response)
0.384262
```
"""
http_request_time(x::HTTPResponse) = x.request_time

"""
    http_iserror(x::HTTPResponse) -> Bool

Determines if the HTTP response indicates an error (status codes 400 and above).

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get")

julia> http_iserror(response)
false
```
"""
http_iserror(x::HTTPResponse) = http_status(x) >= 400

"""
    http_body(x::HTTPResponse) -> String

Extracts the body of the HTTP response as a string.

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get")

julia> http_body(response) |> String |> print
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "httpbin.org",
    "User-Agent": "EasyCurl/3.0.0",
    "X-Amzn-Trace-Id": "Root=1-66d985f2-4f01659e569022ee4dc145a8"
  },
  "origin": "95.217.119.142",
  "url": "http://httpbin.org/get"
}
```
"""
http_body(x::HTTPResponse) = x.body

"""
    http_headers(x::HTTPResponse) -> Dict{String, String}

Extracts all headers from a [`HTTPResponse`](@ref) object as a dictionary.

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get")

julia> http_headers(response)
7-element Vector{Pair{String, String}}:
"date" => "Thu, 05 Sep 2024 10:24:48 GMT"
"content-type" => "application/json"
"content-length" => "258"
"connection" => "keep-alive"
"server" => "gunicorn/19.9.0"
"access-control-allow-origin" => "*"
"access-control-allow-credentials" => "true"
```
"""
http_headers(x::HTTPResponse) = x.headers

"""
    http_headers(x::HTTPResponse, key::AbstractString) -> Vector{String}

Retrieve all values for a specific header field from a [`HTTPResponse`](@ref) object. This function is case-insensitive with regard to the header field name.

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get")

julia> http_headers(response, "Content-Type")
1-element Vector{String}:
 "application/json"

julia> http_headers(response, "nonexistent-header")
 String[]
```
"""
function http_headers(x::HTTPResponse, key::AbstractString)
    h = String[]
    for (k, v) in x.headers
        lowercase(key) == lowercase(k) && push!(h, v)
    end
    return h
end

"""
    http_header(x::HTTPResponse, key::AbstractString, def = nothing) -> Union{String, Nothing}

Retrieve the first value of a specific header field from a [`HTTPResponse`](@ref) object. If the header is not found, the function returns a default value. This function is case-insensitive with regard to the header field name.

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get")

julia> http_header(response, "Content-Type")
"application/json"

julia> http_header(response, "nonexistent-header", "default-value")
"default-value"
```
"""
function http_header(x::HTTPResponse, key::AbstractString, def = nothing)
    for (k, v) in x.headers
        lowercase(key) == lowercase(k) && return v
    end
    return def
end

"""
    HTTPOptions <: CurlOptions

Represents options for configuring an HTTP request.

## Fields

- `location::Bool`: If `true`, enables following HTTP redirects.
- `max_redirs::Int`: Maximum number of redirects to follow.
- `connect_timeout::Int`: Timeout in seconds for establishing a connection.
- `read_timeout::Int`: Timeout in seconds for reading the response.
- `ssl_verifyhost::Bool`: If `true`, the SSL certificate's host will be verified.
- `ssl_verifypeer::Bool`: If `true`, the SSL certificate will be verified.
- `verbose::Bool`: If `true`, enables detailed output from Curl, useful for debugging.
- `username::Union{String,Nothing}`: Username for authentication, or `nothing` if not required.
- `password::Union{String,Nothing}`: Password for authentication, or `nothing` if not required.
- `proxy::Union{String,Nothing}`: Proxy server URL, or `nothing` to bypass proxy settings.
- `interface::Union{String,Nothing}`: Specifies a particular network interface to use for the request, or `nothing` to use the default.
- `accept_encoding::Union{String,Nothing}`: Specifies the accepted encodings for the response, such as `"gzip"`. Defaults to `nothing` if not set.
- `version::Union{UInt,Nothing}`: Specifies the CURL version to use, or `nothing` to use the default version available.
"""
struct HTTPOptions <: CurlOptions
    location::Bool
    max_redirs::Int
    connect_timeout::Real
    read_timeout::Real
    ssl_verifyhost::Bool
    ssl_verifypeer::Bool
    verbose::Bool
    username::Union{String,Nothing}
    password::Union{String,Nothing}
    proxy::Union{String,Nothing}
    interface::Union{String,Nothing}
    accept_encoding::Union{String,Nothing}
    version::Union{UInt,Nothing}

    function HTTPOptions(;
        location = true,
        max_redirs = 10,
        connect_timeout = 10,
        read_timeout = 30,
        ssl_verifyhost = true,
        ssl_verifypeer = true,
        verbose = false,
        username = nothing,
        password = nothing,
        proxy = nothing,
        interface = nothing,
        accept_encoding = "gzip",
        version = nothing,
    )
        return new(
            location,
            max_redirs,
            connect_timeout,
            read_timeout,
            ssl_verifyhost,
            ssl_verifypeer,
            verbose,
            username,
            password,
            proxy,
            interface,
            accept_encoding,
            version,
        )
    end
end

"""
    HTTPStatusError <: Exception

Type wrapping HTTP error codes. Returned from [`http_request`](@ref) when an HTTP error occurs.

## Fields

- `code::Int64`: The HTTP error code (see [`HTTP_STATUS_CODES`](@ref)).
- `message::String`: The error message.
- `response::HTTPResponse`: The HTTP response object.

## Examples

```julia-repl
julia> http_request("GET", "http://httpbin.org/status/400")
ERROR: HTTPStatusError(BAD_REQUEST)
[...]

julia> http_request("GET", "http://httpbin.org/status/404")
ERROR: HTTPStatusError(NOT_FOUND)
[...]
```
"""
struct HTTPStatusError <: Exception
    code::Int64
    message::String
    response::HTTPResponse

    function HTTPStatusError(x::HTTPResponse)
        return new(
            x.status,
            Base.get(HTTP_STATUS_CODES, x.status, HTTP_STATUS_CODES[500]),
            x,
        )
    end
end

function Base.showerror(io::IO, e::HTTPStatusError)
    print(io, "HTTPStatusError(", e.message, ")")
end

mutable struct HTTPRequest <: CurlRequest
    method::String
    url::String
    headers::Vector{Pair{String,String}}
    body::Vector{UInt8}
    options::HTTPOptions
    header_list_ptr::Ptr{Cvoid}
    response::HTTPResponse
end

#__ libcurl

function perform_request(c::CurlClient, r::HTTPRequest)
    curl_easy_setopt(c, CURLOPT_URL, r.url)
    curl_easy_setopt(c, CURLOPT_CAINFO, LibCURL.cacert)
    curl_easy_setopt(c, CURLOPT_FOLLOWLOCATION, r.options.location)
    curl_easy_setopt(c, CURLOPT_MAXREDIRS, r.options.max_redirs)
    curl_easy_setopt(c, CURLOPT_CONNECTTIMEOUT, r.options.connect_timeout)
    curl_easy_setopt(c, CURLOPT_TIMEOUT, r.options.read_timeout)
    curl_easy_setopt(c, CURLOPT_INTERFACE, something(r.options.interface, C_NULL))
    curl_easy_setopt(c, CURLOPT_ACCEPT_ENCODING, something(r.options.accept_encoding, C_NULL))
    curl_easy_setopt(c, CURLOPT_SSL_VERIFYPEER, r.options.ssl_verifypeer)
    curl_easy_setopt(c, CURLOPT_SSL_VERIFYHOST, r.options.ssl_verifyhost ? 2 : 0)
    curl_easy_setopt(c, CURLOPT_PROXY, something(r.options.proxy, C_NULL))
    curl_easy_setopt(c, CURLOPT_VERBOSE, r.options.verbose)

    if r.options.username !== nothing && r.options.password !== nothing
        curl_easy_setopt(c, CURLOPT_USERNAME, r.options.username)
        curl_easy_setopt(c, CURLOPT_PASSWORD, r.options.password)
    end

    for (k::String, v::String) in r.headers
        r.header_list_ptr = curl_slist_append(r.header_list_ptr, "$k: $v")
    end

    curl_easy_setopt(c, CURLOPT_HTTPHEADER, r.header_list_ptr)

    if r.method == "GET"
        curl_easy_setopt(c, CURLOPT_HTTPGET, 1)
    elseif r.method == "HEAD"
        curl_easy_setopt(c, CURLOPT_NOBODY, 1)
    elseif r.method == "POST"
        curl_easy_setopt(c, CURLOPT_POST, 1)
        curl_easy_setopt(c, CURLOPT_POSTFIELDSIZE, length(r.body))
        curl_easy_setopt(c, CURLOPT_COPYPOSTFIELDS, pointer(r.body))
    elseif r.method == "PUT"
        curl_easy_setopt(c, CURLOPT_POSTFIELDS, r.body)
        curl_easy_setopt(c, CURLOPT_POSTFIELDSIZE, length(r.body))
        curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, r.method)
    elseif r.method == "PATCH"
        curl_easy_setopt(c, CURLOPT_POSTFIELDS, r.body)
        curl_easy_setopt(c, CURLOPT_POSTFIELDSIZE, length(r.body))
        curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, r.method)
    elseif r.method == "DELETE"
        curl_easy_setopt(c, CURLOPT_POSTFIELDS, r.body)
        curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, r.method)
    end

    c_write_callback =
        @cfunction(write_callback, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))

    c_header_callback =
        @cfunction(header_callback, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))

    curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, c_write_callback)
    curl_easy_setopt(c, CURLOPT_WRITEDATA, pointer_from_objref(r.response))

    curl_easy_setopt(c, CURLOPT_HEADERFUNCTION, c_header_callback)
    curl_easy_setopt(c, CURLOPT_HEADERDATA, pointer_from_objref(r.response))

    curl_easy_perform(c)

    r.response.version = get_http_version(c)
    r.response.status = get_http_response_status(c)
    r.response.request_time = get_total_request_time(c)

    nothing
end

"""
    http_request(method::AbstractString, url::AbstractString; kw...) -> HTTPResponse

Send a `url` HTTP CurlRequest using as `method` one of `"GET"`, `"POST"`, etc. and return a [`HTTPResponse`](@ref) object.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = http_request("POST", "http://httpbin.org/post", headers = headers, query = "qry=你好嗎",
    body = "{\\"data\\":\\"hi\\"}", interface = "en0", read_timeout = 5, connect_timeout = 10, retry = 10)

julia> http_status(response)
200

julia> http_body(response) |> String |> print
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
function http_request(method::AbstractString, x...; kw...)
    return curl_open(c -> http_request(c, method, x...; kw...))
end

function http_request(
    client::CurlClient,
    method::AbstractString,
    url::AbstractString;
    query = nothing,
    body = UInt8[],
    headers::Vector{Pair{String,String}} = Pair{String,String}[],
    status_exception::Bool = true,
    retry::Int64 = 0,
    retry_delay::Real = 0.25,
    options...,
)::HTTPResponse
    with_retry(retry, retry_delay) do
        req = HTTPRequest(
            uppercase(method),
            build_http_url(client, url, query),
            headers,
            Vector{UInt8}(body),
            HTTPOptions(; options...),
            C_NULL,
            HTTPResponse(),
        )
        try
            perform_request(client, req)
            r = req.response
            if status_exception && http_iserror(r)
                throw(HTTPStatusError(r))
            end
            return r
        finally
            curl_slist_free_all(req.header_list_ptr)
        end
    end
end

"""
    http_get(url::AbstractString; kw...) -> HTTPResponse

Shortcut for [`http_request`](@ref) function, work similar to `http_request("GET", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = http_get("http://httpbin.org/get", headers = headers,
    query = Dict{String,String}("qry" => "你好嗎"))

julia> http_status(response)
200

julia> http_body(response) |> String |> print
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
http_get(url; kw...)::HTTPResponse = http_request("GET", url; kw...)

"""
    http_head(url::AbstractString; kw...) -> HTTPResponse

Shortcut for [`http_request`](@ref) function, work similar to `http_request("HEAD", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = http_head("http://httpbin.org/get", headers = headers,
    query = "qry=你好嗎", interface = "0.0.0.0")

julia> http_status(response)
200

julia> http_body(response)
UInt8[]
```
"""
http_head(url; kw...)::HTTPResponse = http_request("HEAD", url; kw...)

"""
    http_post(url::AbstractString; kw...) -> HTTPResponse

Shortcut for [`http_request`](@ref) function, work similar to `http_request("POST", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = http_post("http://httpbin.org/post", headers = headers,
    query = "qry=你好嗎", body = "{\\"data\\":\\"hi\\"}")

julia> http_status(response)
200

julia> http_body(response) |> String |> print
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
http_post(url; kw...)::HTTPResponse = http_request("POST", url; kw...)

"""
    http_put(url::AbstractString; kw...) -> HTTPResponse

Shortcut for [`http_request`](@ref) function, work similar to `http_request("PUT", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = http_put("http://httpbin.org/put", headers = headers,
    query = "qry=你好嗎", body = "{\\"data\\":\\"hi\\"}")

julia> http_status(response)
200

julia> http_body(response) |> String |> print
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
http_put(url; kw...)::HTTPResponse = http_request("PUT", url; kw...)

"""
    http_patch(url::AbstractString; kw...) -> HTTPResponse

Shortcut for [`http_request`](@ref) function, work similar to `http_request("PATCH", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = http_patch("http://httpbin.org/patch", headers = headers,
    query = "qry=你好嗎", body = "{\\"data\\":\\"hi\\"}")

julia> http_status(response)
200

julia> http_body(response) |> String |> print
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
http_patch(url; kw...)::HTTPResponse = http_request("PATCH", url; kw...)

"""
    http_delete(url::AbstractString; kw...) -> HTTPResponse

Shortcut for [`http_request`](@ref) function, work similar to `http_request("DELETE", url; kw...)`.

## Examples

```julia-repl
julia> headers = Pair{String,String}[
           "User-Agent" => "EasyCurl.jl",
           "Content-Type" => "application/json"
       ]

julia> response = http_delete("http://httpbin.org/delete", headers = headers,
    query = "qry=你好嗎", body = "{\\"data\\":\\"hi\\"}")

julia> http_status(response)
200

julia> http_body(response) |> String |> print
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
http_delete(url; kw...)::HTTPResponse = http_request("DELETE", url; kw...)
