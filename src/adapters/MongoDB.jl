import Base: convert, setindex!, convert, push!
import Mongoc: BSON

include("utils.jl")

macro serialize(type_name)
    
    return quote
        # -------------- Serialize (type -> BSON)
        # --- serialize type to BSON 
        # --- ex: Mongoc.BSON(obj::Client)
        function Mongoc.BSON(obj::$(esc(type_name)))
            res = Mongoc.BSON()
            for f in fieldnames($(esc(type_name)))
                ftype  = fieldtype($(esc(type_name)),f)
                res[string(f)] = bson(ftype, obj, f)
            end
            return res
        end

        # --- Called when setting a bson value of a key and the return type of getfield is not a primitive type
        # --- ex: Base.setindex!(bson::Mongoc.BSON, value::Client, k::AbstractString)
        function Base.setindex!(bson::Mongoc.BSON, value::$(esc(type_name)), k::AbstractString)
            bson[k] = Mongoc.BSON(value)
        end

        # -------------- Deserialize (BSON -> type)
        # --- deserialize type (BSON -> type)
        # --- ex: Client(data::Mongoc.BSON)
        function $(esc(type_name))(data::Mongoc.BSON)
            arr = []
            # -- Ensures correct order of fieldnames so that the constructor is called correctly
            for f in fieldnames($(esc(type_name)))
                ftype  = fieldtype($(esc(type_name)), f)
                push!(arr, toType(@__MODULE__, ftype, data, f))
            end
            return $(esc(type_name))(arr...)
        end

    
        # --- Called when building a composite type
        # --- Base.convert(::Type{Client}, data::Dict)
        function Base.convert(::Type{$(esc(type_name))}, data::Dict)
            return $(esc(type_name))(Mongoc.BSON(data))
        end

        # -------------- Utilities

        # --- Utility to push to Mongoc collection
        # --- Base.push!(collection::Mongoc.AbstractCollection, document::Client)
        function Base.push!(collection::Mongoc.AbstractCollection, document::$(esc(type_name)))
            Base.push!(collection, Mongoc.BSON(document))
        end

        # --- serialize type to BSON (syntax sugar)
        # --- ex: bson(t::Client)
        function $(esc(:bson))(t::$(esc(type_name)))
            return Mongoc.BSON(t)
        end

    end
end
