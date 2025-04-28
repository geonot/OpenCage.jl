using HTTP
using JSON3
using Retry
using Logging
using Base: @kwdef

include("exceptions.jl")
include("types.jl")
include("utils.jl")

# Define await function for async operations
await(x) = fetch(x)

const DEFAULT_API_BASE_URL = "https://api.opencagedata.com/geocode/v1/json"
const DEFAULT_TIMEOUT = 60.0
const DEFAULT_RETRIES = 5

"""
    Geocoder

A client for the OpenCage Geocoding API.

The `Geocoder` struct holds the API key and configuration options for making requests
to the OpenCage Geocoding API.

# Fields
- `api_key::String`: The OpenCage API key
- `api_base_url::String`: The base URL for the OpenCage API
- `user_agent::String`: The User-Agent string to use in requests
- `timeout::Float64`: Request timeout in seconds
- `retries::Int`: Number of retries for failed requests
- `retry_options::Dict{Symbol, Any}`: Options for retry behavior
- `extra_http_options::Dict{Symbol, Any}`: Additional HTTP options

# Constructors

```julia
Geocoder(
    api_key::AbstractString;
    api_base_url::AbstractString = "https://api.opencagedata.com/geocode/v1/json",
    user_agent_comment::Union{AbstractString, Nothing} = nothing,
    timeout::Real = 60.0,
    retries::Integer = 5,
    retry_options::Dict = Dict{Symbol, Any}(:max_delay => 60.0, :factor => 1.0, :jitter => 0.1),
    extra_http_options::Dict = Dict{Symbol, Any}()
)
```

Creates a new `Geocoder` with the specified API key and options.

```julia
Geocoder(; kwargs...)
```

Creates a new `Geocoder` using the API key from the `OPENCAGE_API_KEY` environment variable.

# Examples

```julia
# Using an explicit API key
geocoder = Geocoder("your-api-key")

# Using the environment variable
ENV["OPENCAGE_API_KEY"] = "your-api-key"
geocoder = Geocoder()

# With custom options
geocoder = Geocoder(
    "your-api-key",
    timeout=30.0,
    retries=3,
    user_agent_comment="MyApp/1.0"
)
```
"""
struct Geocoder
    api_key::String
    api_base_url::String
    user_agent::String
    timeout::Float64
    retries::Int
    retry_options::Dict{Symbol, Any}
    extra_http_options::Dict{Symbol, Any}

    function Geocoder(
        api_key::AbstractString;
        api_base_url::AbstractString = DEFAULT_API_BASE_URL,
        user_agent_comment::Union{AbstractString, Nothing} = nothing,
        timeout::Real = DEFAULT_TIMEOUT,
        retries::Integer = DEFAULT_RETRIES,
        retry_options::Dict = Dict{Symbol, Any}(:max_delay => 60.0, :factor => 1.0, :jitter => 0.1),
        extra_http_options::Dict = Dict{Symbol, Any}()
    )
        if isempty(strip(api_key))
            throw(InvalidInputError("API key cannot be empty."))
        end
        user_agent = _generate_user_agent(user_agent_comment)
        new(string(api_key), string(api_base_url), user_agent, Float64(timeout), Int(retries), retry_options, extra_http_options)
    end

    function Geocoder(; kwargs...)
        api_key = get(ENV, "OPENCAGE_API_KEY", "")
        if isempty(api_key)
            throw(InvalidInputError("API key not found. Please set the OPENCAGE_API_KEY environment variable or pass the key explicitly."))
        end
        Geocoder(api_key; kwargs...)
    end
end

function _prepare_http_options(geocoder::Geocoder)::Dict{Symbol, Any}
    return merge(
        Dict(:connect_timeout => Int(geocoder.timeout), :readtimeout => Int(geocoder.timeout)),
        geocoder.extra_http_options
    )
end

function _is_retryable_error(e::Exception)::Bool
    # Check if it's a status error (either HTTP.StatusError or our mock for testing)
    if (e isa HTTP.StatusError || (hasproperty(e, :status) && hasproperty(e, :message))) &&
       hasproperty(e, :status)
        return e.status in (408, 429, 500, 502, 503, 504)
    elseif e isa NetworkError || e isa TimeoutError || e isa TooManyRequestsError || e isa ServerError
        return true
    elseif e isa Base.IOError ||
           e isa HTTP.Exceptions.ConnectError ||
           e isa HTTP.Exceptions.TimeoutError ||
           (hasproperty(e, :message) && (endswith(string(typeof(e)), "MockConnectError") ||
                                         endswith(string(typeof(e)), "MockTimeoutError")))
        return true
    end
    return false
end

function _map_status_code_to_exception(status::Integer, msg::String, response::Union{HTTP.Response, Nothing}=nothing)::OpenCageError
    rate_info = missing
    if !isnothing(response)
        rate_info = _parse_rate_limit_headers(response)
        if ismissing(rate_info) && (status == 402 || status == 429)
            try
                body_data = JSON3.read(copy(response.body))
                if isa(body_data, JSON3.Object)
                    rate_info = _parse_rate_limit(body_data)
                end
            catch
            end
        end
    end

    limit, rem, res = missing, missing, missing
    if !ismissing(rate_info)
        limit = rate_info.limit
        rem = rate_info.remaining
        res = rate_info.reset
    end

    err_type = if status == 400
        BadRequestError
    elseif status == 401
        NotAuthorizedError
    elseif status == 402
        return RateLimitExceededError(msg, limit=limit, remaining=rem, reset=res)
    elseif status == 403
        ForbiddenError
    elseif status == 404
        NotFoundError
    elseif status == 405
        MethodNotAllowedError
    elseif status == 408
        TimeoutError
    elseif status == 410
        RequestTooLongError
    elseif status == 426
        UpgradeRequiredError
    elseif status == 429
        TooManyRequestsError
    elseif status >= 500
        return ServerError(msg, status)
    else
        UnknownError
    end

    return err_type(msg)
end

function _handle_response_status(response::HTTP.Response)
    status = response.status
    if status == 200
        return
    end

    msg = "API request failed with status $status"
    local body_str = ""
    try
        body_bytes = copy(response.body)
        body_str = String(body_bytes)
        json_body = JSON3.read(body_str)
        if isa(json_body, JSON3.Object) && haskey(json_body, :status) && haskey(json_body[:status], :message)
            api_msg = json_body[:status][:message]
            if !isempty(api_msg)
                msg = api_msg
            end
        end
    catch e
        if !isempty(body_str)
            msg = "$msg: $(body_str)"
        else
            msg = "$msg (Could not parse error details from empty response body)"
        end
        @debug "Failed to parse error response body as JSON" exception=(e, catch_backtrace()) status=status
    end

    throw(_map_status_code_to_exception(status, msg, response))
end

function _request(geocoder::Geocoder, params::Dict{String, String})::Response
    headers = Dict("User-Agent" => geocoder.user_agent)
    url = geocoder.api_base_url
    http_options = _prepare_http_options(geocoder)
    retry_check = (s, e) -> _is_retryable_error(e)
    local response_obj

    resp_body = try
        response_obj = HTTP.get(url, headers; query=params, status_exception=false, http_options...)
        _handle_response_status(response_obj)
        JSON3.read(response_obj.body, Response)
    catch e
        mapped_error = if e isa HTTP.StatusError
            _map_status_code_to_exception(e.status, "HTTP Status Error $(e.status)", nothing)
        elseif e isa Base.IOError || e isa HTTP.Exceptions.ConnectError || e isa HTTP.Exceptions.TimeoutError
            NetworkError("Network error during request: $(e)", e)
        elseif e isa JSON3.Error
            BadResponseError("Failed to parse successful JSON response: $(e)")
        else
            e
        end
        throw(mapped_error)
    end

    if resp_body isa Response
        if !isa(resp_body.status, Status) || !isa(resp_body.results, Vector{Result})
            throw(BadResponseError("Parsed response is missing essential fields (:status, :results)."))
        end
        return resp_body
    else
        error("Internal error: Request completed but failed to produce a Response object.")
    end
end

function _request_async(geocoder::Geocoder, params::Dict{String, String})
    headers = Dict("User-Agent" => geocoder.user_agent)
    url = geocoder.api_base_url
    http_options = _prepare_http_options(geocoder)
    retry_check = (e) -> _is_retryable_error(e)

    return @async begin
        current_try = 0
        backoff_calculator = if isdefined(Retry, :Backoff)
            Backoff(; n=geocoder.retries, max_delay=geocoder.retry_options[:max_delay],
                      factor=get(geocoder.retry_options, :factor, 2.0),
                      jitter=get(geocoder.retry_options, :jitter, 0.1))
        else
            (attempt) -> min(1.0 * (2.0^(attempt-1)) * (1.0 + 0.1*rand()), geocoder.retry_options[:max_delay])
        end

        while current_try <= geocoder.retries
            try
                response_obj = HTTP.request("GET", url, headers, HTTP.nobody; query=params, http_options...)
                _handle_response_status(response_obj)
                body_bytes = await(read(response_obj.body))
                resp = JSON3.read(body_bytes, Response)
                if !isa(resp.status, Status) || !isa(resp.results, Vector{Result})
                    throw(BadResponseError("Parsed async response is missing essential fields (:status, :results)."))
                end
                return resp

            catch e
                current_try += 1
                mapped_error = if e isa HTTP.StatusError
                    _map_status_code_to_exception(e.status, "HTTP Status Error $(e.status)", nothing)
                elseif e isa Base.IOError || e isa HTTP.Exceptions.ConnectError || e isa HTTP.Exceptions.TimeoutError
                    NetworkError("Network error during async request: $(e)", e)
                elseif e isa JSON3.Error
                    BadResponseError("Failed to parse successful async JSON response: $(e)")
                else
                    e
                end

                if retry_check(mapped_error) && current_try <= geocoder.retries
                    delay = if isdefined(Retry, :nextdelay)
                                nextdelay(backoff_calculator, current_try)
                            else
                                backoff_calculator(current_try)
                            end
                    @warn "Retryable error encountered ($(typeof(mapped_error))). Retrying in $(round(delay, digits=2))s... (Attempt $current_try/$(geocoder.retries))"
                    await(Timer(delay))
                    continue
                else
                    @error "Request failed after $(current_try-1) retries." exception=(mapped_error, catch_backtrace())
                    throw(mapped_error)
                end
            end
        end
        error("Exhausted retries for async request without returning a result or throwing final error.")
    end
end

"""
    geocode(geocoder::Geocoder, query::AbstractString; kwargs...)::Response

Perform forward geocoding to convert a place name or address to coordinates.

# Arguments
- `geocoder::Geocoder`: The geocoder instance to use for the request
- `query::AbstractString`: The place name or address to geocode
- `kwargs...`: Optional parameters to pass to the API

# Optional Parameters
- `language::AbstractString`: Preferred language for results
- `countrycode::Union{AbstractString, Vector{<:AbstractString}}`: Limit results to specific countries
- `bounds::NTuple{4, Number}`: Restrict results to within a bounding box (min_lng, min_lat, max_lng, max_lat)
- `proximity::NTuple{2, Number}`: Bias results towards a specific location (lat, lng)
- `limit::Integer`: Maximum number of results to return
- `no_annotations::Bool`: Exclude annotations from results
- `no_record::Bool`: Don't store the query in the OpenCage database
- And many more (see OpenCage API documentation)

# Returns
- `Response`: The API response containing geocoding results

# Throws
- `InvalidInputError`: If the query is empty
- `NotAuthorizedError`: If the API key is invalid
- `RateLimitExceededError`: If the rate limit has been exceeded
- `NetworkError`: If a network error occurs
- Other `OpenCageError` subtypes for various error conditions

# Examples
```julia
geocoder = Geocoder("your-api-key")
response = geocode(geocoder, "Berlin, Germany")

# With optional parameters
response = geocode(geocoder, "London",
    language="fr",
    countrycode="gb",
    limit=5,
    no_annotations=true
)
```
"""
function geocode(geocoder::Geocoder, query::AbstractString; kwargs...)::Response
    if isempty(strip(query))
        throw(InvalidInputError("Query cannot be empty."))
    end
    params_dict = Dict{Symbol, Any}(kwargs)
    url_params = _build_url_params(query, geocoder.api_key, params_dict)
    return _request(geocoder, url_params)
end

"""
    geocode_async(geocoder::Geocoder, query::AbstractString; kwargs...)::Task{Response}

Perform asynchronous forward geocoding to convert a place name or address to coordinates.

This function returns a `Task` that can be awaited or fetched to get the result.

# Arguments
- `geocoder::Geocoder`: The geocoder instance to use for the request
- `query::AbstractString`: The place name or address to geocode
- `kwargs...`: Optional parameters to pass to the API (same as `geocode`)

# Returns
- `Task{Response}`: A task that will resolve to the API response

# Throws
- `InvalidInputError`: If the query is empty
- Other exceptions may be thrown when the task is awaited/fetched

# Examples
```julia
geocoder = Geocoder("your-api-key")
task = geocode_async(geocoder, "Berlin, Germany")

# Do other work...

# Get the result when needed
response = fetch(task)
```
"""
function geocode_async(geocoder::Geocoder, query::AbstractString; kwargs...)
    if isempty(strip(query))
        throw(InvalidInputError("Query cannot be empty."))
    end
    params_dict = Dict{Symbol, Any}(kwargs)
    url_params = _build_url_params(query, geocoder.api_key, params_dict)
    return _request_async(geocoder, url_params)
end

"""
    reverse_geocode(geocoder::Geocoder, latitude::Number, longitude::Number; kwargs...)::Response

Perform reverse geocoding to convert coordinates to a place name or address.

# Arguments
- `geocoder::Geocoder`: The geocoder instance to use for the request
- `latitude::Number`: The latitude coordinate
- `longitude::Number`: The longitude coordinate
- `kwargs...`: Optional parameters to pass to the API

# Optional Parameters
- `language::AbstractString`: Preferred language for results
- `no_annotations::Bool`: Exclude annotations from results
- `no_record::Bool`: Don't store the query in the OpenCage database
- And many more (see OpenCage API documentation)

# Returns
- `Response`: The API response containing geocoding results

# Throws
- `InvalidInputError`: If the coordinates are invalid
- `NotAuthorizedError`: If the API key is invalid
- `RateLimitExceededError`: If the rate limit has been exceeded
- `NetworkError`: If a network error occurs
- Other `OpenCageError` subtypes for various error conditions

# Examples
```julia
geocoder = Geocoder("your-api-key")
response = reverse_geocode(geocoder, 52.5200, 13.4050)

# With optional parameters
response = reverse_geocode(geocoder, 51.5074, -0.1278,
    language="fr",
    no_annotations=true
)
```
"""
function reverse_geocode(geocoder::Geocoder, latitude::Number, longitude::Number; kwargs...)::Response
    query = _format_reverse_query(latitude, longitude)
    params_dict = filter(p -> p.first != :limit, Dict{Symbol, Any}(kwargs))
    url_params = _build_url_params(query, geocoder.api_key, params_dict)
    return _request(geocoder, url_params)
end

"""
    reverse_geocode_async(geocoder::Geocoder, latitude::Number, longitude::Number; kwargs...)::Task{Response}

Perform asynchronous reverse geocoding to convert coordinates to a place name or address.

This function returns a `Task` that can be awaited or fetched to get the result.

# Arguments
- `geocoder::Geocoder`: The geocoder instance to use for the request
- `latitude::Number`: The latitude coordinate
- `longitude::Number`: The longitude coordinate
- `kwargs...`: Optional parameters to pass to the API (same as `reverse_geocode`)

# Returns
- `Task{Response}`: A task that will resolve to the API response

# Throws
- `InvalidInputError`: If the coordinates are invalid
- Other exceptions may be thrown when the task is awaited/fetched

# Examples
```julia
geocoder = Geocoder("your-api-key")
task = reverse_geocode_async(geocoder, 52.5200, 13.4050)

# Do other work...

# Get the result when needed
response = fetch(task)
```
"""
function reverse_geocode_async(geocoder::Geocoder, latitude::Number, longitude::Number; kwargs...)
    query = _format_reverse_query(latitude, longitude)
    params_dict = filter(p -> p.first != :limit, Dict{Symbol, Any}(kwargs))
    url_params = _build_url_params(query, geocoder.api_key, params_dict)
    return _request_async(geocoder, url_params)
end