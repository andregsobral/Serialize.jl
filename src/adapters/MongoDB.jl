import Base: convert, setindex!, convert, push!
import Mongoc.BSON

getparamtype(::Type{Array}, obj, f) = eltype(typeof(getfield(obj,f)))
getparamtype(::Type{Dict},  obj, f) = eltype(fieldtype(typeof(obj), f)).types
abstract_bson(item) = merge!(Mongoc.BSON("_type" => string(typeof(item))), Mongoc.BSON(item))

function bson_arr(obj, f::Symbol)
    # @show "Array"
    parameter_type = getparamtype(Array, obj, f)
    # @show parameter_type
    # @show isabstracttype(parameter_type) || parameter_type isa Union
    if isabstracttype(parameter_type) &&  parameter_type != Any || parameter_type isa Union
        return [abstract_bson(item) for item in getfield(obj,f)] 
    end
    # TODO: generic Vector
    # elseif isabstracttype(parameter_type) &&  parameter_type == Any
    #     fvalue = Vector{Any}()
    #     for item in getfield(obj,f)
    #         itype = typeof(item)
    #         @show item
    #         !isprimitivetype(itype) && itype !=String ? push!(fvalue, abstract_bson(item)) : push!(fvalue, item) 
    #     end
    #     return [fvalue]
    # end
    return nothing
end

function bson_dic(obj, f::Symbol)
    # @show "Dict"
    # @show getparamtype(Dict, obj, f)
    # @show !isempty(getparamtype(Dict, obj, f))
    
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

macro serialize(type_name)
    
    return quote
        TYPE_MAP[Symbol($(esc(type_name)))] = $(esc(type_name))
        # -------------- Serialize (type -> BSON)
        # --- serialize type to BSON 
        # --- ex: Mongoc.BSON(obj::Client)
        function Mongoc.BSON(obj::$(esc(type_name)))
            res = Mongoc.BSON()
            # println("----- input ------------")
            # @show obj
            for f in fieldnames($(esc(type_name)))
                
                fvalue = nothing
                ftype  = fieldtype($(esc(type_name)),f)
                
                # @show fvalue
                # @show ftype
                # @show f
                
                if isabstracttype(ftype) || ftype isa Union
                    # @show "generic"
                    concrete_type = typeof(getfield(obj,f))
                    # @show concrete_type
                    # @show !isprimitivetype(concrete_type) && concrete_type != String 
                    if !isprimitivetype(concrete_type) && !isnothing(getfield(obj,f)) && concrete_type != String 
                        fvalue = abstract_bson(getfield(obj,f))
                    end
                
                elseif ftype <: Array
                    fvalue = bson_arr(obj, f)
                elseif ftype <: Dict
                    fvalue = bson_dic(obj, f)
                end
                # println("----- output for field \'" * string(f) * "\'------------")
                # @show fvalue
                # @show getfield(obj,f)
                res[string(f)] = isnothing(fvalue) ? getfield(obj,f) #= default value =# : fvalue
                # println("-------")
            end
            return res
        end

        # --- Called when setting a bson value of a key and the return type of getfield is not a primitive type
        # --- ex: Base.setindex!(bson::Mongoc.BSON, value::Client, k::AbstractString)
        function Base.setindex!(bson::Mongoc.BSON, value::$(esc(type_name)), k::AbstractString)
            bson[k] = Mongoc.BSON(value)
        end

        # -------------- Deserialize (BSON -> type)
        
        # --- deserialize type (dict -> type)
        # --- ex: Client(data::Dict)
        function $(esc(type_name))(data::Mongoc.BSON)
            arr = []
    
            # -- Ensures correct order of fieldnames so that the constructor is called correctly
            for f in fieldnames($(esc(type_name)))
                fvalue = data[string(f)] # default value
                ftype  = fieldtype($(esc(type_name)), f)

                if isabstracttype(ftype) || ftype isa Union && typeof(fvalue) <: Dict  # must have "_type"
                    fvalue = convert(TYPE_MAP[Symbol(fvalue["_type"])], data[string(f)])
                    
                elseif ftype <: Array
                    parameter_type = eltype(ftype)
                    if isabstracttype(parameter_type) || parameter_type isa Union
                        fvalue = map(v -> haskey(v, "_type") ? convert(TYPE_MAP[Symbol(v["_type"])], v) : v, fvalue)
                    end

                elseif ftype <: Dict 
                    if !isempty(eltype(fieldtype($(esc(type_name)), f)).types) # -- isempty on {Any, Any}
                        first_parameter = eltype(fieldtype($(esc(type_name)), f)).types[1] # -- From {String, T} get type 'String'
                        parameter_type  = eltype(fieldtype($(esc(type_name)), f)).types[2] # -- From {String, T} get type 'T'

                        if !isprimitivetype(parameter_type) || parameter_type != String
                            if isabstracttype(parameter_type) || parameter_type isa Union
                                fvalue = Dict{first_parameter, parameter_type}([k => convert(TYPE_MAP[Symbol(v["_type"])], v) for (k,v) in fvalue])
                            else
                                fvalue = Dict{first_parameter, parameter_type}([k => convert(parameter_type, v) for (k,v) in fvalue])
                            end
                        end
                    else # -- Dict{Any, Any}
                        fvalue = Dict([k => (v isa Dict && haskey(v, "_type")) ? convert(TYPE_MAP[Symbol(v["_type"])], v) : v for (k,v) in data[string(f)]])
                    end
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
