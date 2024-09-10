#__ IMAP

export imap_request,
    imap_request_time,
    imap_body

export IMAPResponse,
    IMAPRequest,
    IMAPOptions

mutable struct IMAPResponse <: CurlResponce
    request_time::Float64
    body::Vector{UInt8}

    function IMAPResponse()
        return new(0.0, Vector{UInt8}())
    end
end

"""
    imap_request_time(x::IMAPResponse) -> Float64

Extracts the total request time for the HTTP request that resulted in the [`IMAPResponse`](@ref).

## Examples

```julia-repl
julia> response = imap_request("GET", "http://httpbin.org/get")

julia> imap_request_time(response)
0.384262
```
"""
imap_request_time(x::IMAPResponse) = x.request_time

"""
    imap_body(x::IMAPResponse) -> String

Extracts the body of the IMAP response as a string.

## Examples

```julia-repl
julia> response = imap_request(
    curl_client,
    "imaps://imap.gmail.com:993/INBOX",
    "your_imap_username",
    "your_imap_password",
    command = "SEARCH SINCE 09-Sep-2024",
)

julia> imap_body(response) |> String |> print
* SEARCH 1399 1400 1401 1402 1403 1404 1405 1406 1407 1408 1409 1410 1411 1412 1413 1414 1415 1416
```
"""
imap_body(x::IMAPResponse) = x.body

struct IMAPOptions <: CurlOptions
    ssl::Bool
    starttls::Bool
    mailbox::Union{String,Nothing}
    read_timeout::Int
    connect_timeout::Int
    ssl_verifyhost::Bool
    ssl_verifypeer::Bool
    verbose::Bool
    interface::Union{String,Nothing}

    function IMAPOptions(;
        ssl = true,
        starttls = false,
        mailbox = nothing,
        read_timeout = 30,
        connect_timeout = 10,
        ssl_verifyhost = true,
        ssl_verifypeer = true,
        verbose = false,
        interface = nothing,
    )
        return new(
            ssl,
            starttls,
            mailbox,
            read_timeout,
            connect_timeout,
            ssl_verifyhost,
            ssl_verifypeer,
            verbose,
            interface,
        )
    end
end

struct IMAPRequest <: CurlRequest
    url::String
    username::String
    password::String
    command::Union{Nothing,String}
    options::IMAPOptions
    response::IMAPResponse
end

function perform_request(c::CurlClient, r::IMAPRequest)
    curl_easy_setopt(c, CURLOPT_URL, r.url)
    curl_easy_setopt(c, CURLOPT_INTERFACE, something(r.options.interface, C_NULL))
    curl_easy_setopt(c, CURLOPT_VERBOSE, r.options.verbose)
    curl_easy_setopt(c, CURLOPT_CUSTOMREQUEST, something(r.command, C_NULL))
    curl_easy_setopt(c, CURLOPT_CONNECTTIMEOUT, r.options.connect_timeout)
    curl_easy_setopt(c, CURLOPT_TIMEOUT, r.options.read_timeout)
    curl_easy_setopt(c, CURLOPT_SSL_VERIFYPEER, r.options.ssl_verifypeer)
    curl_easy_setopt(c, CURLOPT_SSL_VERIFYHOST, r.options.ssl_verifyhost ? 2 : 0)
    curl_easy_setopt(c, CURLOPT_USERNAME, r.username)
    curl_easy_setopt(c, CURLOPT_PASSWORD, r.password)

    c_write_callback =
        @cfunction(write_callback, Csize_t, (Ptr{UInt8}, Csize_t, Csize_t, Ptr{Cvoid}))

    curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, c_write_callback)
    curl_easy_setopt(c, CURLOPT_WRITEDATA, pointer_from_objref(r.response))

    curl_easy_perform(c)

    r.response.request_time = get_total_request_time(c)

    return nothing
end

function imap_request(url::String, x...; kw...)
    return curl_open(c -> imap_request(c, url, x...; kw...))
end

function imap_request(
    client::CurlClient,
    url::String,
    username::String,
    password::String;
    path::Union{Nothing,String} = nothing,
    mailbox::Union{Nothing,String} = nothing,
    command = nothing,
    retry::Int64 = 0,
    retry_delay::Real = 0.25,
    options...,
)::IMAPResponse
    with_retry(retry, retry_delay) do
        req = IMAPRequest(
            build_imap_url(url, mailbox, path),
            username,
            password,
            command,
            IMAPOptions(; options...),
            IMAPResponse(),
        )
        perform_request(client, req)
        req.response
    end
end
