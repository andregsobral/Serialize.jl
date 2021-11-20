getparamtype(::Type{Array}, obj, f) = eltype(typeof(getfield(obj,f)))
getparamtype(::Type{Dict},  obj, f) = eltype(fieldtype(typeof(obj), f)).types
abstract_bson(item)  = merge!(Mongoc.BSON("_type" => string(typeof(item))), Mongoc.BSON(item))
isgenerictype(ftype) = (isabstracttype(ftype) && ftype != Any) || ftype isa Union

abstract type GenericType end

function bson(::Type{GenericType}, obj, f::Symbol)
    concrete_type = typeof(getfield(obj,f))
    if !isprimitivetype(concrete_type) && !isnothing(getfield(obj,f)) && !(concrete_type <: String)
        return abstract_bson(getfield(obj,f))
    end
    return getfield(obj, f)
end

function bson(::Type{Array}, obj, f::Symbol)
    paramtype = getparamtype(Array, obj, f)
    if isgenerictype(paramtype)
        return [abstract_bson(item) for item in getfield(obj,f)]
    end
    return getfield(obj, f)
end

function bson(::Type{Dict}, obj, f::Symbol)
    
    if !isempty(getparamtype(Dict, obj, f))
        parameter_type = getparamtype(Dict, obj, f)[2]
        if isabstracttype(parameter_type) || parameter_type isa Union
            return Mongoc.BSON(Dict(k => abstract_bson(v) for (k,v) in getfield(obj,f)))
        elseif !isprimitivetype(parameter_type) && !(parameter_type <: String)
            return Mongoc.BSON(Dict(k => Mongoc.BSON(v) for (k,v) in getfield(obj,f)))
        end
    else # {Any, Any}
        fvalue = Mongoc.BSON()
        for (k,v) in getfield(obj,f)
            parameter_type = typeof(v)
            if !isprimitivetype(parameter_type) && !(parameter_type <: String)
                fvalue[k] = abstract_bson(v)
            else
                fvalue[k] = v
            end
        end
        return fvalue
    end
    return getfield(obj, f)
end

function gettype(m::Module , strtype::String) ::DataType
    evaltype = occursin(".", strtype) ? last(split(strtype, ".")) : strtype
    return getfield(m, Symbol(evaltype))
end


function toType(::Type{GenericType}, m::Module, ftype::String, obj)
    return convert(gettype(m, ftype), obj)
end

function toType(::Type{Array}, m::Module, ftype, obj)
    paramtype = eltype(ftype) # --- Gets T of Vector{T}
    if isgenerictype(paramtype) || paramtype == Any
        arr = []
        for item in obj
            if typeof(item) <: Dict && haskey(item, "_type")
                push!(arr, toType(GenericType, m, item["_type"], item))
            elseif typeof(item) <: Array
                push!(arr, toType(Array, m, typeof(item), item))
            else
                push!(arr, item)
            end
        end
        return arr
    end
    return obj
end

function toType(::Type{Dict}, m::Module, ftype, obj)
    if !isempty(eltype(ftype).types) # -- isempty on {Any, Any}
        keyparamtype = eltype(ftype).types[1] # -- From {String, T} get type 'String'
        valparamtype = eltype(ftype).types[2] # -- From {String, T} get type 'T'

        if !isprimitivetype(valparamtype) || !(valparamtype <: String)
            if isgenerictype(valparamtype)
                return Dict{keyparamtype, valparamtype}([k => toType(GenericType, m, v["_type"], v) for (k,v) in obj])
            else
                return Dict{keyparamtype, valparamtype}([k => convert(valparamtype, v) for (k,v) in obj])
            end
        end
    end 
    # -- Dict{Any, Any}
    return Dict([k => (v isa Dict && haskey(v, "_type")) ? toType(GenericType, m, v["_type"], v) : v for (k,v) in obj])
end

# ---- bson & toType driver functions

function bson(ftype, obj, f)
    
    # ---- Abstract or Union type
    if isgenerictype(ftype)
        return bson(GenericType, obj, f)
    # ---- Array types
    elseif ftype <: Array
        return bson(Array, obj, f)
    # ---- Dict types
    elseif ftype <: Dict
        return bson(Dict, obj, f)
    end
    return getfield(obj,f) #= default value =#
end

function toType(m::Module, ftype, data, f)
    fvalue = data[string(f)] # default value
    # ---- Abstract or Union type
    if isgenerictype(ftype) && typeof(fvalue) <: Dict # -- filters out cases of Union{String, SomeType}
        return toType(GenericType, m, fvalue["_type"], fvalue)
    # ---- Array types
    elseif ftype <: Array
        return toType(Array, m, ftype, fvalue)
    # ---- Dict types
    elseif ftype <: Dict 
        return toType(Dict, m, ftype, fvalue)
    end
    return fvalue
end
