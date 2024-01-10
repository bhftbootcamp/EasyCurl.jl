using Test, Random, Sockets, JSON

include("../src/EasyCurl.jl")
using .EasyCurl

include("unit.jl")
include("integration.jl")
