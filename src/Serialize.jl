module Serialize

export @serialize

using Revise
using JSON
using Mongoc

TYPE_MAP = Dict{Symbol, DataType}()
function typemap!(d::Dict{Symbol, DataType})
  global TYPE_MAP = d
end
typemap() = TYPE_MAP

include("adapters/MongoDB.jl")

end # module
