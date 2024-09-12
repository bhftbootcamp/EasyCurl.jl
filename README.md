# EasyCurl.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://bhftbootcamp.github.io/EasyCurl.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://bhftbootcamp.github.io/EasyCurl.jl/dev)
[![Build Status](https://github.com/bhftbootcamp/EasyCurl.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/bhftbootcamp/EasyCurl.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/bhftbootcamp/EasyCurl.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/bhftbootcamp/EasyCurl.jl)
[![Registry](https://img.shields.io/badge/registry-General-4063d8)](https://github.com/JuliaRegistries/General)

EasyCurl is a lightweight Julia package that provides a user-friendly wrapper for the libcurl C library, for making requests.

<html lang="en">
  <body>
      <table>
          <tr>
              <th>Protocols:</th>
              <th><div align="center">HTTP/HTTPS</div></th>
              <th><div align="center">IMAP/IMAPS</div></th>
          </tr>
          <tr>
              <th></th>
              <th><div align="center">✓</div></th>
              <th><div align="center">✓</div></th>
          </tr>
      </table>
  </body>
</html>

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

# 'interface' argument specifies the network interface to use for the request
# 'read_timeout' and 'connect_timeout' define how long to wait for a response or connection
# 'retry' argument specifies how many times to retry the request if it fails initially

response = http_request(
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
)

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
    "X-Amzn-Trace-Id": "Root=1-66e0dce3-7dbea4a9357524fb19628e26"
  },
  "json": {
    "data": "hi"
  },
  "origin": "100.250.50.140",
  "url": "http://httpbin.org/post?qry=\u4f60\u597d\u55ce"
}
```

This example shows how to use `CurlClient` for making HTTP requests by reusing the same client instance, which can help in speeding up the requests when making multiple calls to the same server:

```julia
using EasyCurl

http_client = CurlClient()

# Perform a GET request
response = http_request(
    http_client,
    "GET",
    "http://httpbin.org/get",
    headers = Pair{String,String}[
        "Content-Type" => "application/json",
        "User-Agent" => "EasyCurl.jl",
    ],
)

julia> http_body(response) |> String |> print
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Content-Type": "application/json",
    "Host": "httpbin.org",
    "User-Agent": "EasyCurl.jl",
    "X-Amzn-Trace-Id": "Root=1-66e0de99-735b60c138a5445c7f7b5c7e"
  },
  "origin": "100.250.50.140",
  "url": "http://httpbin.org/get"
}

close(http_client)
```

In addition to HTTP, you can also make IMAP requests to retrieve email from a server:

```julia
using EasyCurl

response = imap_request(
    "imaps://imap.gmail.com:993",
    "username@example.com",
    "password",
    mailbox = "INBOX",
    command = "SEARCH SINCE 09-Sep-2024",
)

julia> imap_body(response) |> String |> print
* SEARCH 610 611 612 613 614 615 616 617 618 619 620 621 622 623 624 625 626 627 628 629
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

When executing the `http_request` function with the `proxy` parameter, it will ignore the environment variable settings for proxies

```julia
julia> http_request("GET", "http://httpbin.org/get",
    proxy = "socks5://your_proxy_username:your_proxy_password@your_proxy_host:your_proxy_port")
```

## Contributing
Contributions to EasyCurl are welcome! If you encounter a bug, have a feature request, or would like to contribute code, please open an issue or a pull request on GitHub.
