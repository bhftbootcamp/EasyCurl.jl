using Test, Random, Sockets, Serde

include("../src/EasyCurl.jl")
using .EasyCurl

include("unit.jl")
include("integration.jl")
