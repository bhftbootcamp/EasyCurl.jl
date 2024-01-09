using Test, Random, Sockets, JSON

include("../src/cURL.jl")
using .cURL

include("unit.jl")
include("integration.jl")
