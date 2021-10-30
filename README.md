# Serialize.jl

`Serialize.jl` is a Julia package which assists with serialization and deserialization of user-defined types.


## Motivation

I wanted to automatically generate the boilerplate code needed in order to convert between user-defined types and a database storing format.

## Example
##### Version 0.2.0

```julia

using Serialize
using Mongoc

# -- define your types
struct AType
    name::String
    count::Int
end

struct OtherType
    data::Vector{AType}
end

struct DictType
    data::Dict{String, AType}
end

# -- run macro to define serialization and deserialization functions (for MongoDB only at this time)
@serialize AType
@serialize OtherType
@serialize DictType

# serialize
println("serializing.....")
atbson = Mongoc.BSON(AType("Hello", 100))
@info atbson
otbson = Mongoc.BSON(OtherType([AType("Hello", 100), AType("World", 200)]))
@info otbson
dtbson = Mongoc.BSON(DictType(Dict("hello" => AType("World", 100))))
@info dtbson

# deserialize
println("deserializing.....")
@info AType(atbson)
@info OtherType(otbson)
@info DictType(dtbson)

```

