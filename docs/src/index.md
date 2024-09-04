![EasyCurl.jl Logo](assets/readme_logo.svg)

# EasyCurl.jl

EasyCurl is a lightweight Julia package that provides a user-friendly wrapper for the libcurl C library, for making HTTP requests. It is useful for sending HTTP requests, especially when dealing with RESTful APIs.

## Installation

To install EasyCurl, simply use the Julia package manager:

```julia
] add EasyCurl
```

## Usage

Here is an example usage of EasyCurl:

In the example, a POST request is sent to http://httpbin.org/post using the `en0` network interface

```julia
using EasyCurl

headers = Pair{String,String}[
    "User-Agent" => "EasyCurl.jl",
    "Content-Type" => "application/json"
]

# 'interface' argument specifies the network interface to use for the request
# 'read_timeout' and 'connect_timeout' define how long to wait for a response or connection
# 'retry' argument specifies how many times to retry the request if it fails initially

response = curl_request("POST", "http://httpbin.org/post", headers = headers, query = "qry=你好嗎",
    body = "{\"data\":\"hi\"}", interface = "en0", read_timeout = 5, connect_timeout = 10, retry = 10)

julia> curl_status(response)
200

julia> String(curl_body(response))
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
  "data": "{\"data\":\"hi\"}",
  "url": "http://httpbin.org/post?qry=你好嗎",
  "form": {},
  "origin": "100.250.50.140"
}
```

For HEAD, GET, POST, PUT, and PATCH requests, a similar structure is used to invoke the `curl_request` function with the appropriate HTTP method specified

```julia
using EasyCurl

headers = [
    "User-Agent" => "EasyCurl.jl",
    "Content-Type" => "application/json"
]

# HEAD
julia> curl_request("HEAD", "http://httpbin.org/get", headers = headers,
    query = "qry=你好嗎", interface = "0.0.0.0")

# GET
julia> curl_request("GET", "http://httpbin.org/get", headers = headers,
    query = Dict{String,String}("qry" => "你好嗎"))

# POST
julia> curl_request("POST", "http://httpbin.org/post", headers = headers,
    query = "qry=你好嗎", body = "{\"data\":\"hi\"}")

# PUT
julia> curl_request("PUT", "http://httpbin.org/put", headers = headers,
    query = "qry=你好嗎", body = "{\"data\":\"hi\"}")

# PATCH
julia> curl_request("PATCH", "http://httpbin.org/patch", headers = headers,
    query = "qry=你好嗎", body = "{\"data\":\"hi\"}")
```

This example shows how to use `CurlClient` for making HTTP requests by reusing the same client instance, which can help in speeding up the requests when making multiple calls to the same server:

```julia
using EasyCurl

headers = Pair{String,String}[
    "User-Agent" => "EasyCurl.jl",
    "Content-Type" => "application/json"
]

curl_client = CurlClient()

# Perform a GET request
response = curl_request(
    curl_client,
    "GET",
    "http://httpbin.org/get",
    headers = headers
)

julia> curl_status(response)
200

julia> String(curl_body(response))
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
  ...
}

close(curl_client)
```

Example of error handling with `EasyCurl`:

```julia
using EasyCurl

headers = Pair{String,String}[
    "User-Agent" => "EasyCurl.jl",
    "Content-Type" => "application/json",
]

try
    response = curl_request("GET", "http://httpbin.org/status/400", query = "echo=你好嗎",
        headers = headers, interface = "0.0.0.0", read_timeout = 30, retry = 1)
    # If the request is successful, you can process the response here
    # ...
catch e
    if isa(e, CurlError{EasyCurl.CURLE_COULDNT_CONNECT})
        # Handle the case where the connection to the server could not be made
    elseif isa(e, CurlError{EasyCurl.CURLE_OPERATION_TIMEDOUT})
        # Handle the case where the operation timed out
    elseif isa(e, CurlStatusError{400})
        # Handle a 400 Bad Request error specifically
        rethrow(e)
    end
end
```

### Using a proxy with EasyCurl

To use a proxy for all your HTTP and HTTPS requests in `EasyCurl`, you can set the following environment variables:

- `all_proxy`: Proxy for all protocols
- `http_proxy`: Proxy for HTTP requests
- `https_proxy`: Proxy for HTTPS requests
- `no_proxy`: Domains to exclude from proxying

```julia
# 'your_proxy_username' your proxy account's username
# 'your_proxy_password' your proxy account's password
# 'your_proxy_host' the hostname or IP address of your proxy server
# 'your_proxy_port' the port number your proxy server listens on

# socks5 proxy for all protocols
ENV["all_proxy"] = "socks5://your_proxy_username:your_proxy_password@your_proxy_host:your_proxy_port"

# domains that should bypass the proxy
ENV["no_proxy"] = "localhost,.local,.mywork"
```

When executing the `curl_request` function with the `proxy` parameter, it will ignore the environment variable settings for proxies

```julia
julia> curl_request("GET", "http://httpbin.org/get",
    proxy = "socks5://your_proxy_username:your_proxy_password@your_proxy_host:your_proxy_port")
```
