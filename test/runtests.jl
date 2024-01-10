using Test, Random, Sockets, JSON

include("../src/Curl.jl")
using .Curl

include("unit.jl")
include("integration.jl")
