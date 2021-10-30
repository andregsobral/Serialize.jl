module Serialize

export @serialize

using Revise
using JSON
using Mongoc

include("adapters/MongoDB.jl")

end # module
