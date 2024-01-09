# cURL.jl

cURL is a lightweight Julia package that provides a user-friendly wrapper for the libcurl C library, for making HTTP requests. It is useful for sending HTTP requests, especially when dealing with RESTful APIs.

## Quickstart

In the example, a POST request is sent to http://httpbin.org/post using the `0.0.0.0` network interface.

```julia
using cURL

headers = Pair{String,String}[
    "User-Agent" => "cURL.jl",
    "Content-Type" => "application/json"
]

# 'interface' argument specifies the network interface to use for the request
# 'read_timeout' and 'connect_timeout' define how long to wait for a response or connection
# 'retries' argument specifies how many times to retry the request if it fails initially

response = curl_request("POST", "http://httpbin.org/post";
    headers = headers,
    query = "qry=你好嗎",
    body = "{\"data\":\"hi\"}",
    interface = "0.0.0.0",
    read_timeout = 5,
    connect_timeout = 10,
    retries = 10,
)

# Get the response 'status'
curl_status(response)

# Get and parse the response 'body' to a string
String(curl_body(response))
```
