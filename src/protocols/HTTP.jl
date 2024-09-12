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
    http_total_time,
    http_iserror,
    http_header,
    http_joinurl

export HTTPResponse,
    HTTPRequest,
    HTTPOptions,
    HTTPStatusError

export CURL_HTTP_VERSION_NONE,
    CURL_HTTP_VERSION_1_0,
    CURL_HTTP_VERSION_1_1,
    CURL_HTTP_VERSION_2_0,
    CURL_HTTP_VERSION_2TLS,
    CURL_HTTP_VERSION_2_PRIOR_KNOWLEDGE,
    CURL_HTTP_VERSION_3,
    CURL_HTTP_VERSION_3ONLY

"""
    HTTP_VERSION_MAP::Dict{UInt64,String}

Maps CURL numerical constants for HTTP versions to their string representations.

- `0x00000001` (`CURL_HTTP_VERSION_1_0`) - `"1.0"`: HTTP 1.0
- `0x00000002` (`CURL_HTTP_VERSION_1_1`) - `"1.1"`: HTTP 1.1
- `0x00000003` (`CURL_HTTP_VERSION_2_0`) - `"2.0"`: HTTP 2.0
"""
const HTTP_VERSION_MAP = Dict{UInt64,String}(
    CURL_HTTP_VERSION_1_0 => "1.0",
    CURL_HTTP_VERSION_1_1 => "1.1",
    CURL_HTTP_VERSION_2_0 => "2.0",
)

"""
    HTTPResponse <: CurlResponse

An HTTP response object returned on a request completion.

## Fields
| Name | Description | Accessors (`get`) |
|:-----|:------------|:------------------|
| `status::Int` | The HTTP status code of the response. | `http_status(x)` |
| `version::Int` | The HTTP version received in the response. | `http_version(x)` |
| `total_time::Float64` | Total time spent receiving a response in seconds. | `http_total_time(x)`, `curl_total_time(x)` |
| `body::Vector{UInt8}` | The response body as a vector of bytes. | `http_body(x)`, `curl_body(x)`|
| `headers::Vector{Pair{String,String}}` | Headers received in the HTTP response. | `http_headers(x)` |
"""
mutable struct HTTPResponse <: CurlResponse
    status::Int
    version::Int
    total_time::Float64
    body::Vector{UInt8}
    headers::Vector{Pair{String,String}}

    function HTTPResponse()
        return new(0, 0, 0.0, Vector{UInt8}(), Vector{Pair{String,String}}())
    end
end

http_status(x::HTTPResponse) = x.status
http_version(x::HTTPResponse) = x.version
http_total_time(x::HTTPResponse) = x.total_time
http_body(x::HTTPResponse) = x.body
http_headers(x::HTTPResponse) = x.headers

curl_total_time(x::HTTPResponse) = http_total_time(x)
curl_body(x::HTTPResponse) = http_body(x)

function Base.show(io::IO, x::HTTPResponse)
    println(io, HTTPResponse)
    println(io, "\"\"\"")
    print(io, "HTTP/", Base.get(HTTP_VERSION_MAP, http_version(x), "1.1"))
    println(io, " ", http_status(x), " ", Base.get(HTTP_STATUS_CODES, x.status, ""))
    for (k, v) in http_headers(x)
        println(io, "$k: '$v'")
    end
    println(io, "\"\"\"")
    if length(http_body(x)) > 1000
        v = view(http_body(x), 1:1000)
        print(io, "    ", strip(String(v)))
        println(io, "\n    ⋮")
    else
        v = view(http_body(x), 1:length(http_body(x)))
        println(io, "    ", strip(String(v)))
    end
end

"""
    http_iserror(x::HTTPResponse) -> Bool

Determines if the HTTP response indicates an error (status codes 400 and above).

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get");

julia> http_iserror(response)
false
```
"""
http_iserror(x::HTTPResponse) = http_status(x) >= 400

"""
    http_headers(x::HTTPResponse, key::String) -> Vector{String}

Retrieve all values for a specific header field from a [`HTTPResponse`](@ref) object.
This function is case-insensitive with regard to the header field name.

## Examples

```julia-repl
julia> response = http_request("GET", "http://httpbin.org/get");

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
    http_header(x::HTTPResponse, key::String, default = nothing)

Retrieve the first value of a specific header field by `key` from a [`HTTPResponse`](@ref) object.
If the header is not found, the function returns a `default` value.
This function is case-insensitive with regard to the header field name.

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
| Name | Description | Default |
|:-----|:------------|:--------|
| `location::Bool` | Allow HTTP redirects. | `true` |
| `max_redirs::Int` | Maximum number of redirects. | `10` |
| `connect_timeout::Real` | Maximum time in seconds that you allow the connection phase to take. | `10` |
| `read_timeout::Real` | Timeout in seconds for reading the response. | `30` |
| `ssl_verifyhost::Bool` | Enables SSL certificate's host verification. | `true` |
| `ssl_verifypeer::Bool` | Enables the SSL certificate verification. | `true` |
| `verbose::Bool` | Enables detailed output from Curl (useful for debugging). | `false` |
| `username::Union{String,Nothing}` | Username for authentication. | `nothing` |
| `password::Union{String,Nothing}` | Password for authentication. | `nothing` |
| `proxy::Union{String,Nothing}` | Proxy server URL, or `nothing` to bypass proxy settings. | `nothing` |
| `interface::Union{String,Nothing}` | Specifies a particular network interface to use for the request, or `nothing` to use the default. | `nothing` |
| `accept_encoding::String` | Specifies the accepted encodings for the response, such as `"gzip"`. | `"gzip"` |
| `version::Union{UInt,Nothing}` | Specifies the CURL version to use, or `nothing` to use the default version available. | `nothing` |
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
    accept_encoding::String
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
ERROR: HTTPStatusError: BAD_REQUEST
[...]

julia> http_request("GET", "http://httpbin.org/status/404")
ERROR: HTTPStatusError: NOT_FOUND
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
    print(io, "HTTPStatusError: ", e.message)
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
    # Basic request settings
    curl_easy_setopt(c, CURLOPT_URL, r.url)
    curl_easy_setopt(c, CURLOPT_CAINFO, LibCURL.cacert)

    # SSL settings
    curl_easy_setopt(c, CURLOPT_SSL_VERIFYPEER, r.options.ssl_verifypeer)
    curl_easy_setopt(c, CURLOPT_SSL_VERIFYHOST, r.options.ssl_verifyhost ? 2 : 0)

    # Timeouts
    curl_easy_setopt(c, CURLOPT_CONNECTTIMEOUT, r.options.connect_timeout)
    curl_easy_setopt(c, CURLOPT_TIMEOUT, r.options.read_timeout)

    # Set redirection
    curl_easy_setopt(c, CURLOPT_FOLLOWLOCATION, r.options.location)
    curl_easy_setopt(c, CURLOPT_MAXREDIRS, r.options.max_redirs)

    # Set proxy, interface and encoding options
    curl_easy_setopt(c, CURLOPT_PROXY, something(r.options.proxy, C_NULL))
    curl_easy_setopt(c, CURLOPT_INTERFACE, something(r.options.interface, C_NULL))
    curl_easy_setopt(c, CURLOPT_ACCEPT_ENCODING, something(r.options.accept_encoding, C_NULL))

    # Set authentication
    curl_easy_setopt(c, CURLOPT_USERNAME, something(r.options.username, C_NULL))
    curl_easy_setopt(c, CURLOPT_PASSWORD, something(r.options.password, C_NULL))

    # Set HTTP version
    curl_easy_setopt(c, CURLOPT_HTTP_VERSION, something(r.options.version, CURL_HTTP_VERSION_2TLS))

    # Verbose debug output
    curl_easy_setopt(c, CURLOPT_VERBOSE, r.options.verbose)

    # Set headers
    for (k, v) in r.headers
        r.header_list_ptr = curl_slist_append(r.header_list_ptr, "$k: $v")
    end
    curl_easy_setopt(c, CURLOPT_HTTPHEADER, r.header_list_ptr)

    # Configure HTTP method
    if r.method == "GET"
        curl_easy_setopt(c, CURLOPT_HTTPGET, 1)
    elseif r.method == "HEAD"
        curl_easy_setopt(c, CURLOPT_NOBODY, 1)
    elseif r.method == "POST"
        curl_easy_setopt(c, CURLOPT_POST, 1)
        curl_easy_setopt(c, CURLOPT_POSTFIELDSIZE, length(r.body))
        curl_easy_setopt(c, CURLOPT_COPYPOSTFIELDS, pointer(r.body))
    elseif r.method == "PUT" || r.method == "PATCH"
        curl_easy_setopt(c, CURLOPT_POSTFIELDS, r.body)
        curl_easy_setopt(c, CURLOPT_POSTFIELDSIZE, length(r.body))
        curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, r.method)
    elseif r.method == "DELETE"
        curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, r.method)
    end

    # Setup callback for response handling
    c_write_callback = @cfunction(write_callback, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))
    c_header_callback = @cfunction(header_callback, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))

    curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, c_write_callback)
    curl_easy_setopt(c, CURLOPT_WRITEDATA, pointer_from_objref(r.response))
    curl_easy_setopt(c, CURLOPT_HEADERFUNCTION, c_header_callback)
    curl_easy_setopt(c, CURLOPT_HEADERDATA, pointer_from_objref(r.response))

    # Perform request
    curl_easy_perform(c)

    # Gather response details
    r.response.version = get_http_version(c)
    r.response.status = get_http_response_status(c)
    r.response.total_time = get_total_total_time(c)

    return nothing
end

"""
    http_request(method::String, url::String; kw...) -> HTTPResponse

Send a `url` HTTP request using as `method` one of `"GET"`, `"POST"`, etc. and return a [`HTTPResponse`](@ref) object.

## Keyword arguments
| Name | Description | Default |
|:-----|:------------|:--------|
| `query` | Request query dictionary or string. | `nothing` |
| `body` | Request body. | `UInt8[]` |
| `headers::Vector{Pair{String,String}}` | Request headers. | `Pair{String,String}[]` |
| `status_exception::Bool` |  Whether to throw an exception if the response status code indicates an error. | `true` |
| `retry::Int64` | Number of retries. | `0` |
| `retry_delay::Real` | Delay after failed request. | `0.25` |
| `options...` | Another HTTP request [options](@ref HTTPOptions). |  |

## Examples

```julia-repl
julia> response = http_request(
           "POST",
           "http://httpbin.org/post",
           headers = Pair{String,String}[
               "Content-Type" => "application/json",
               "User-Agent" => "EasyCurl.jl",
           ],
           query = "qry=你好嗎",
           body = "{\"data\":\"hi\"}",
           interface = "en0",
           read_timeout = 5,
           connect_timeout = 10,
           retry = 10,
       );

julia> http_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  }, 
  "data": "{\"data\":\"hi\"}", 
  "files": {}, 
  "form": {}, 
  "headers": {
    "Accept": "*/*", 
    "Accept-Encoding": "gzip", 
    "Content-Length": "13", 
    "Content-Type": "application/json", 
    "Host": "httpbin.org", 
    "User-Agent": "EasyCurl.jl", 
    "X-Amzn-Trace-Id": "Root=1-66e0d404-7597b1921ad026293b805690"
  }, 
  "json": {
    "data": "hi"
  }, 
  "origin": "100.250.50.140", 
  "url": "http://httpbin.org/post?qry=\u4f60\u597d\u55ce"
}
```
"""
function http_request end

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
            LibCURL.curl_slist_free_all(req.header_list_ptr)
        end
    end
end

function http_request(method::AbstractString, x...; kw...)
    return curl_open(c -> http_request(c, method, x...; kw...))
end

"""
    http_get(url::AbstractString; kw...) -> HTTPResponse

Shortcut for [`http_request`](@ref) function, work similar to `http_request("GET", url; kw...)`.

## Examples

```julia-repl
julia> response = http_get(
           "http://httpbin.org/get";
           headers = Pair{String,String}[
               "Content-Type" => "application/json",
               "User-Agent" => "EasyCurl.jl",
           ],
           query = Dict("qry" => "你好嗎"),
       );

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
    "X-Amzn-Trace-Id": "Root=1-66e0e18f-0e26d7757885d0ec1966ef64"
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
julia> response = http_head(
           "http://httpbin.org/get";
           headers = Pair{String,String}[
               "Content-Type" => "application/json",
               "User-Agent" => "EasyCurl.jl",
           ],
           query = "qry=你好嗎",
           interface = "0.0.0.0",
       );

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
julia> response = http_post(
           "http://httpbin.org/post";
           headers = Pair{String,String}[
               "Content-Type" => "application/json",
               "User-Agent" => "EasyCurl.jl",
           ],
           query = "qry=你好嗎",
           body = "{\"data\":\"hi\"}",
       );

julia> http_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  }, 
  "data": "{\"data\":\"hi\"}", 
  "files": {}, 
  "form": {}, 
  "headers": {
    "Accept": "*/*", 
    "Accept-Encoding": "gzip", 
    "Content-Length": "13", 
    "Content-Type": "application/json", 
    "Host": "httpbin.org", 
    "User-Agent": "EasyCurl.jl", 
    "X-Amzn-Trace-Id": "Root=1-66e0e208-4850928003a928fd230bfd59"
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
julia> response = http_put(
           "http://httpbin.org/put";
           headers = Pair{String,String}[
               "Content-Type" => "application/json",
               "User-Agent" => "EasyCurl.jl",
           ],
           query = "qry=你好嗎",
           body = "{\"data\":\"hi\"}",
       );

julia> http_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  }, 
  "data": "{\"data\":\"hi\"}", 
  "files": {}, 
  "form": {}, 
  "headers": {
    "Accept": "*/*", 
    "Accept-Encoding": "gzip", 
    "Content-Length": "13", 
    "Content-Type": "application/json", 
    "Host": "httpbin.org", 
    "User-Agent": "EasyCurl.jl", 
    "X-Amzn-Trace-Id": "Root=1-66e0e239-34f8cfdc41164300719ce1f1"
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
julia> response = http_patch(
           "http://httpbin.org/patch";
           headers = Pair{String,String}[
               "Content-Type" => "application/json",
               "User-Agent" => "EasyCurl.jl",
           ],
           query = "qry=你好嗎",
           body = "{\"data\":\"hi\"}",
       );

julia> http_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  }, 
  "data": "{\"data\":\"hi\"}", 
  "files": {}, 
  "form": {}, 
  "headers": {
    "Accept": "*/*", 
    "Accept-Encoding": "gzip", 
    "Content-Length": "13", 
    "Content-Type": "application/json", 
    "Host": "httpbin.org", 
    "User-Agent": "EasyCurl.jl", 
    "X-Amzn-Trace-Id": "Root=1-66e0e266-5bd4762c619fbd642710bf3d"
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
julia> response = http_delete(
           "http://httpbin.org/delete";
           headers = Pair{String,String}[
               "Content-Type" => "application/json",
               "User-Agent" => "EasyCurl.jl",
           ],
           query = "qry=你好嗎",
           body = "{\"data\":\"hi\"}",
       );

julia> http_body(response) |> String |> print
{
  "args": {
    "qry": "\u4f60\u597d\u55ce"
  }, 
  "data": "{\"data\":\"hi\"}", 
  "files": {}, 
  "form": {}, 
  "headers": {
    "Accept": "*/*", 
    "Accept-Encoding": "gzip", 
    "Content-Length": "13", 
    "Content-Type": "application/json", 
    "Host": "httpbin.org", 
    "User-Agent": "EasyCurl.jl", 
    "X-Amzn-Trace-Id": "Root=1-66e0e292-34acbab950035ea1763c3aca"
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
