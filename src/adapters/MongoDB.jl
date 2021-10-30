import Base: convert, setindex!, convert, push!
import Mongoc.BSON

include("MongoUtils.jl")

macro serialize(type_name)
    
    return quote
        # -------------- Serialize (type -> BSON)
        # --- serialize type to BSON 
        # --- ex: Mongoc.BSON(obj::Client)
        function Mongoc.BSON(obj::$(esc(type_name)))
            res = Mongoc.BSON()
            
            for f in fieldnames($(esc(type_name)))
                fvalue = nothing
                ftype  = fieldtype($(esc(type_name)),f)
                # ---- Abstract or Union type
                if isgenerictype(ftype)
                    fvalue = bson(GenericType, obj, f)
                # ---- Array types
                elseif ftype <: Array
                    fvalue = bson(Array, obj, f)
                # ---- Dict types
                elseif ftype <: Dict
                    fvalue = bson(Dict, obj, f)
                end
                res[string(f)] = isnothing(fvalue) ? getfield(obj,f) #= default value =# : fvalue
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
                fvalue = data[string(f)] # default value
                ftype  = fieldtype($(esc(type_name)), f)
                
                # ---- Abstract or Union type
                if isgenerictype(ftype) && typeof(fvalue) <: Dict # -- filters out cases of Union{String, SomeType}
                    fvalue = toType(GenericType, @__MODULE__, fvalue["_type"], fvalue)
                # ---- Array types
                elseif ftype <: Array
                    fvalue = toType(Array, @__MODULE__, ftype, fvalue)
                # ---- Dict types
                elseif ftype <: Dict 
                    fvalue = toType(Dict, @__MODULE__, ftype, fvalue)
                end
                push!(arr, fvalue)
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
