module Serialize

export @serialize

using Revise
using JSON
using Mongoc

TYPE_MAP = Dict{Symbol, DataType}()
typemap!(d::Dict{Symbol, DataType}) = TYPE_MAP = d

include("adapters/MongoDB.jl")

end # module
