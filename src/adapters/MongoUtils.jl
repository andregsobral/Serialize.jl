getparamtype(::Type{Array}, obj, f) = eltype(typeof(getfield(obj,f)))
getparamtype(::Type{Dict},  obj, f) = eltype(fieldtype(typeof(obj), f)).types
abstract_bson(item) = merge!(Mongoc.BSON("_type" => string(typeof(item))), Mongoc.BSON(item))

function gettype(m::Module , strtype::String) ::DataType
    evaltype = occursin(".", strtype) ? last(split(strtype, ".")) : strtype
    return getfield(m, Symbol(evaltype))
end

abstract type TemplateType end
function bson(::Type{TemplateType}, obj, f::Symbol)
    concrete_type = typeof(getfield(obj,f))
    if !isprimitivetype(concrete_type) && !isnothing(getfield(obj,f)) && !(concrete_type <: String)
        return abstract_bson(getfield(obj,f))
    end
    return nothing
end

function bson(::Type{Array}, obj, f::Symbol)
    parameter_type = getparamtype(Array, obj, f)
    if isabstracttype(parameter_type) && parameter_type != Any || parameter_type isa Union
        return [abstract_bson(item) for item in getfield(obj,f)] 
    end
    return nothing
end

function bson(::Type{Dict}, obj, f::Symbol)
    
    if !isempty(getparamtype(Dict, obj, f))
        parameter_type = getparamtype(Dict, obj, f)[2]
        if isabstracttype(parameter_type) || parameter_type isa Union
            return Mongoc.BSON(Dict(k => abstract_bson(v) for (k,v) in getfield(obj,f)))
        elseif !isprimitivetype(parameter_type) && parameter_type != String
            return Mongoc.BSON(Dict(k => Mongoc.BSON(v) for (k,v) in getfield(obj,f)))
        end
    else # {Any, Any}
        fvalue = Mongoc.BSON()
        for (k,v) in getfield(obj,f)
            parameter_type = typeof(v)
            if !isprimitivetype(parameter_type) && parameter_type != String
                fvalue[k] = abstract_bson(v)
            else
                fvalue[k] = v
            end
        end
        return fvalue
    end
    return nothing
end
