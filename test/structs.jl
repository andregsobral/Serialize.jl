struct Department
    name    ::String
end

struct Car
    brand   ::Union{Int, String}
end

struct Client
    name    ::String
    id      ::Int64
    tier    ::Float64
    dep     ::Department
    cars    ::Vector{Car}
end

struct Person
    name    ::Dict{String, Client}
    height  ::Dict{String, Int}
    items   ::Dict{String, String}
end

struct Cat
    name          ::String
    age           ::Int
    height        ::Float64
    date_of_birth ::DateTime
end

abstract type GenericType end

struct AType <: GenericType
    attr ::String
end

struct OtherType <: GenericType
    attr ::Int
end

struct FourthType
    attr::Union{AType, OtherType}
end

struct Company
    attr::Dict{String, OtherType}
end

struct GenVec
    attr::Vector{GenericType}
end

struct GenVecU
    attr::Vector{Union{AType, OtherType}}
end

struct GenDict
    attr::Dict{String, GenericType}
end

struct GenDictU
    attr::Dict{String, Union{AType, Company}}
end

struct DictWrapper
    attr::Dict
end

# TODO: Add support for these structs
# struct VecWrapper
#     attr::Array
# end

# struct All
#     attr
# end


# struct HelloGen
#     a ::Vector{GenericType}
#     b ::Vector{Union{AType, OtherType}}
#     c ::Vector{String}
#     d ::AType
#     e ::GenericType
#     f ::Union{AType, OtherType}
#     g ::Dict{String, AType}
#     h ::Dict{String, Union{AType, OtherType}}
#     i ::Dict{String, GenericType}
#     j ::Dict{String, Int}
#     l ::Dict
#     label::String
#     age::Int
# end

