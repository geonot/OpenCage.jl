# src/utils.jl

using HTTP
using Pkg

function _format_reverse_query(lat, lng)::String
    # If inputs are already strings that look like valid coordinates, just format them
    if (lat isa AbstractString && lng isa AbstractString)
        # Try to parse them to validate they're numeric
        try
            lat_float = parse(Float64, lat)
            lng_float = parse(Float64, lng)
            return lat * "," * lng
        catch e
            throw(InvalidInputError("Invalid latitude or longitude provided: must be convertible to Float64. Got: '$lat', '$lng'"))
        end
    end
    
    # Otherwise convert to Float64
    local lat_float::Float64, lng_float::Float64
    
    # Check if either input is a string (which would be invalid)
    if lat isa AbstractString || lng isa AbstractString
        throw(InvalidInputError("Invalid latitude or longitude provided: must be convertible to Float64. Got: '$lat', '$lng'"))
    end
    
    try
        lat_float = Float64(lat)
        lng_float = Float64(lng)
    catch e
        if e isa ArgumentError || e isa InexactError || e isa TypeError || e isa MethodError
            throw(InvalidInputError("Invalid latitude or longitude provided: must be convertible to Float64. Got: '$lat', '$lng'"))
        else
            rethrow()
        end
    end
    
    # Format with exactly one decimal place for integers
    if lat_float == round(lat_float)
        lat_str = string(Int(lat_float)) * ".0"
    else
        lat_str = string(lat_float)
    end
    
    if lng_float == round(lng_float)
        lng_str = string(Int(lng_float)) * ".0"
    else
        lng_str = string(lng_float)
    end
    
    return lat_str * "," * lng_str
end

function _validate_api_key(key::AbstractString)::Bool
    # API key should be 32 characters long and alphanumeric
    # The test expects "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6" (32 chars) to be valid
    return length(key) == 32 && all(c -> isletter(c) || isdigit(c), key)
end

function _build_url_params(query::AbstractString, api_key::AbstractString, optional_params::Dict)::Dict{String, String}
    if !_validate_api_key(api_key)
         @warn "API key format appears potentially invalid (should be 32 alphanumeric chars)."
    end

    params = Dict{String, Any}("key" => api_key, "q" => query)

    for (key, value) in optional_params
        s_key = string(key)
        if !isnothing(value) && !ismissing(value)
            if value isa Bool
                params[s_key] = value ? "1" : "0"
            elseif key == :bounds && value isa NTuple{4, Number}
                params[s_key] = join(string.(value), ",")
            elseif key == :proximity && value isa NTuple{2, Number}
                params[s_key] = _format_reverse_query(value[1], value[2])
            elseif key == :countrycode && value isa AbstractVector{<:AbstractString}
                params[s_key] = join(uppercase.(value), ",")
            elseif key == :countrycode && value isa AbstractString
                params[s_key] = uppercase(replace(value, " " => ""))
            else
                params[s_key] = string(value)
            end
        end
    end
    string_params = Dict{String, String}(string(k) => string(v) for (k,v) in params)
    return string_params
end

function _generate_user_agent(user_agent_comment::Union{AbstractString, Nothing}=nothing)::String
    sdk_name = "opencage-julia"
    sdk_version_str = "DEV"
    try
        project_path = joinpath(dirname(@__DIR__), "Project.toml")
        if isfile(project_path)
            proj = Pkg.API.read_project(project_path)
            sdk_version = proj.version
            if !isnothing(sdk_version)
                sdk_version_str = string(sdk_version)
            end
        else
            # Get package info from current module
            pkg_uuid = Base.PkgId(@__MODULE__).uuid
            pkg_info = Pkg.API.pkg_info(pkg_uuid)
            if !isnothing(pkg_info) && !isnothing(pkg_info.version)
                sdk_version_str = string(pkg_info.version)
            end
        end
    catch e
        @debug "Could not automatically determine SDK version for User-Agent." exception=(e, catch_backtrace())
    end

    julia_version = string(VERSION)
    http_version_str = "UNKNOWN"
    try
        http_uuid = Base.PkgId(HTTP).uuid
        http_info = Pkg.API.pkg_info(http_uuid)
        if !isnothing(http_info) && !isnothing(http_info.version)
            http_version_str = string(http_info.version)
        end
    catch e
        @debug "Could not determine HTTP.jl version for User-Agent." exception=(e, catch_backtrace())
    end

    ua_base = "$(sdk_name)/$(sdk_version_str) Julia/$(julia_version) HTTP.jl/$(http_version_str)"
    if !isnothing(user_agent_comment) && !isempty(strip(user_agent_comment))
        # Remove any parentheses from the comment and don't add them back
        clean_comment = replace(strip(user_agent_comment), r"[\(\)]" => "")
        return ua_base * " " * clean_comment
    else
        return ua_base
    end
end

function deep_get(data::Any, keys_str::AbstractString, default::Any=missing)
    if isempty(strip(keys_str))
        return default
    end
    keys = Symbol.(split(keys_str, '.'))
    return deep_get(data, keys, default)
end

function deep_get(data::Any, keys::Vector{Symbol}, default::Any=missing)::Any
    current_data = data
    for (i, key) in enumerate(keys)
        if ismissing(current_data) || isnothing(current_data)
            return default
        end

        found = false
        if current_data isa AbstractDict
            current_data = get(current_data, key) do
                get(current_data, string(key), :_NOT_FOUND_)
            end
            if current_data !== :_NOT_FOUND_  # Use === for comparison with symbol
                found = true
            end
        elseif current_data isa NamedTuple && haskey(current_data, key)
            current_data = current_data[key]
            found = true
        elseif !(current_data isa Module || current_data isa Type) &&
               hasfield(typeof(current_data), key)
            current_data = getfield(current_data, key)
            found = true
        end

        if !found
            return default
        end

        # Check if we're at the last key and the value is missing or nothing
        if i == length(keys)
            if ismissing(current_data)
                return missing
            elseif isnothing(current_data)
                return nothing
            end
        end
    end
    return current_data
end

function _parse_rate_limit(response_body::Dict)::Union{RateInfo, Missing}
    if haskey(response_body, :rate) && isa(response_body[:rate], AbstractDict)
        rate_dict = response_body[:rate]
        return RateInfo(
            get(rate_dict, :limit, missing),
            get(rate_dict, :remaining, missing),
            get(rate_dict, :reset, missing)
        )
    end
    return missing
end

function _parse_rate_limit_headers(response::HTTP.Response)::Union{RateInfo, Missing}
    limit_hdr = HTTP.header(response, "X-RateLimit-Limit", "")
    remaining_hdr = HTTP.header(response, "X-RateLimit-Remaining", "")
    reset_hdr = HTTP.header(response, "X-RateLimit-Reset", "")

    if !isempty(limit_hdr) || !isempty(remaining_hdr) || !isempty(reset_hdr)
        try
            limit_val = isempty(limit_hdr) ? missing : tryparse(Int, limit_hdr)
            remaining_val = isempty(remaining_hdr) ? missing : tryparse(Int, remaining_hdr)
            reset_val = isempty(reset_hdr) ? missing : tryparse(Int, reset_hdr)

            if !ismissing(limit_val) || !ismissing(remaining_val) || !ismissing(reset_val)
                return RateInfo(
                    isnothing(limit_val) ? missing : limit_val,
                    isnothing(remaining_val) ? missing : remaining_val,
                    isnothing(reset_val) ? missing : reset_val
                )
            else
                @warn "Found rate limit headers but could not parse any as integers." limit=limit_hdr remaining=remaining_hdr reset=reset_hdr
                return missing
            end
        catch e
            @warn "Error processing rate limit headers" exception=(e, catch_backtrace()) limit=limit_hdr remaining=remaining_hdr reset=reset_hdr
            return missing
        end
    end
    return missing
end