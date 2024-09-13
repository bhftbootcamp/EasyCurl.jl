#__ Utils

"""
    curl_joinurl(basepart::String, parts::String...) -> String

Construct a URL by concatenating a `basepart` with one or more path `parts`.
This function ensures that each segment is separated by a single forward slash (`/`),
regardless of whether the `basepart` or `parts` already contain slashes at their boundaries.

## Examples

```julia-repl
julia> curl_joinurl("http://example.com", "path")
"http://example.com/path"

julia> curl_joinurl("http://example.com/", "/path/to/resource")
"http://example.com/path/to/resource"
```
"""
function curl_joinurl(basepart::AbstractString, parts::AbstractString...)
    basepart = strip(basepart, '/')
    cleaned_parts = [strip(part, '/') for part in parts if !isempty(part)]
    return join([basepart, cleaned_parts...], "/")
end

function urlencode(c::CurlClient, s::AbstractString)
    b_arr = curl_easy_escape(c, s, 0)
    try
        return unsafe_string(b_arr)
    finally
        curl_free(b_arr)
    end
end

function urldecode(c::CurlClient, s::AbstractString)
    b_arr = curl_easy_unescape(c, s, 0, C_NULL)
    try
        return unsafe_string(b_arr)
    finally
        curl_free(b_arr)
    end
end

function to_query(c::CurlClient, params::AbstractDict{String,<:Any})
    pairs = String[]
    for (k, v) in params
        if v !== ""
            push!(pairs, urlencode(c, k) * "=" * urlencode(c, string(v)))
        else
            push!(pairs, urlencode(c, k))
        end
    end
    return join(pairs, "&")
end

to_query(c::CurlClient, ::Nothing) = ""
to_query(c::CurlClient, x::S) where {S<:AbstractString} = x

function build_http_url(c::CurlClient, url::AbstractString, query)
    q = to_query(c, query)
    return isempty(q) ? url : url * "?" * q
end

function build_imap_url(
    url::AbstractString,
    mailbox::Union{AbstractString,Nothing},
    path::Union{AbstractString,Nothing},
)
    return url *
           (mailbox === nothing ? "" : "/$mailbox") *
           (path    === nothing ? "" : ";$path")
end

function split_header(x::AbstractString)
    m = match(r"^(.*?):\s*(.*?)\r?\n?$", x)
    isnothing(m) && return nothing
    k, v = m
    return lowercase(k) => v
end

function with_retry(f::Function, retry::Int, retry_delay::Real)
    while true
        try
            return f()
        catch
            retry -= 1
            retry <= 0 && rethrow()
            sleep(retry_delay)
        end
        retry < 0 && break
    end
end
