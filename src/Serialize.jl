module Serialize

export @serialize

using Revise
using Mongoc

include("adapters/MongoDB.jl")

end # module
