# OpenCage.jl

A Julia SDK for the [OpenCage Geocoding API](https://opencagedata.com/api).

## Features

- Forward geocoding (convert place names/addresses to coordinates)
- Reverse geocoding (convert coordinates to place names/addresses)
- Asynchronous API for both forward and reverse geocoding
- Batch processing for large datasets with configurable concurrency
- Comprehensive error handling
- Rate limit detection and management
- Support for all OpenCage API parameters

## Installation

```julia
using Pkg
Pkg.add("OpenCage")
```

## Authentication

You'll need an API key from [OpenCage](https://opencagedata.com/). You can either:

1. Set the `OPENCAGE_API_KEY` environment variable:

```julia
ENV["OPENCAGE_API_KEY"] = "your-api-key"
```

2. Or provide the key directly when creating a `Geocoder` instance:

```julia
geocoder = Geocoder("your-api-key")
```

## Quick Start

### Forward Geocoding

```julia
using OpenCage

# Create a geocoder instance
geocoder = Geocoder()  # Uses OPENCAGE_API_KEY environment variable

# Forward geocoding (place name/address to coordinates)
response = geocode(geocoder, "Berlin, Germany")

# Access the first result
if !isempty(response.results)
    result = response.results[1]
    println("Coordinates: $(result.geometry.lat), $(result.geometry.lng)")
    println("Formatted address: $(result.formatted)")
end
```

### Reverse Geocoding

```julia
using OpenCage

geocoder = Geocoder()

# Reverse geocoding (coordinates to place name/address)
response = reverse_geocode(geocoder, 52.5200, 13.4050)

# Access the result
if !isempty(response.results)
    result = response.results[1]
    println("Address: $(result.formatted)")
    println("Country: $(result.components.country)")
end
```

### Asynchronous Geocoding

```julia
using OpenCage

geocoder = Geocoder()

# Asynchronous forward geocoding
task = geocode_async(geocoder, "Berlin, Germany")

# Do other work...

# Get the result when needed
response = fetch(task)
```

### Batch Processing

```julia
using OpenCage

geocoder = Geocoder()

# Batch geocode from a CSV file
batch_geocode(
    geocoder,
    "input.csv",  # Input CSV file with addresses
    "output.csv", # Output CSV file with geocoding results
    workers=4,    # Number of concurrent workers
    input_columns=[2], # Column index containing the address (1-based)
    add_columns=["formatted", "geometry.lat", "geometry.lng", "components.country"]
)
```

## API Reference

### Geocoder

```julia
Geocoder(
    api_key::AbstractString;
    api_base_url::AbstractString = "https://api.opencagedata.com/geocode/v1/json",
    user_agent_comment::Union{AbstractString, Nothing} = nothing,
    timeout::Real = 60.0,
    retries::Integer = 5,
    retry_options::Dict{Symbol, Any} = Dict(:f => expo, :max_delay => 60.0, :factor => 1.0, :jitter => 0.1),
    extra_http_options::Dict{Symbol, Any} = Dict{Symbol, Any}()
)
```

Creates a new geocoder instance with the specified API key and options.

### Geocoding Functions

```julia
geocode(geocoder::Geocoder, query::AbstractString; kwargs...)::Response
```

Performs forward geocoding (place name/address to coordinates).

```julia
geocode_async(geocoder::Geocoder, query::AbstractString; kwargs...)::Task{Response}
```

Performs asynchronous forward geocoding.

```julia
reverse_geocode(geocoder::Geocoder, latitude::Number, longitude::Number; kwargs...)::Response
```

Performs reverse geocoding (coordinates to place name/address).

```julia
reverse_geocode_async(geocoder::Geocoder, latitude::Number, longitude::Number; kwargs...)::Task{Response}
```

Performs asynchronous reverse geocoding.

### Batch Processing

```julia
batch_geocode(
    geocoder::Geocoder,
    input::Union{AbstractString, IO},
    output::Union{AbstractString, IO};
    workers::Int = 4,
    retries::Int = 5,
    timeout::Float64 = 60.0,
    input_columns::Union{Vector{Int}, Nothing} = nothing,
    add_columns::Vector{<:AbstractString} = ["formatted", "geometry.lat", "geometry.lng", "confidence", "components._type", "status_message"],
    on_error::Symbol = :log,
    ordered::Bool = false,
    progress::Bool = true,
    limit::Union{Int, Nothing} = nothing,
    optional_api_params::Dict{Symbol, Any} = Dict{Symbol, Any}(),
    rate_limit_semaphore::Union{Base.Semaphore, Nothing} = nothing,
    command::Union{Symbol, Nothing} = nothing
)
```

Processes a batch of geocoding requests from a CSV file or IO stream.

### Response Types

The SDK provides comprehensive type definitions for the OpenCage API response:

- `Response`: The top-level response object
- `Result`: A single geocoding result
- `Geometry`: Latitude and longitude coordinates
- `Bounds`: Northeast and southwest bounds of a location
- `Components`: Various components of a location (country, city, etc.)
- `Annotations`: Additional information about a location

### Error Handling

The SDK provides a hierarchy of custom exception types:

- `OpenCageError`: Base type for all OpenCage-related errors
- `InvalidInputError`: For invalid input parameters
- `NotAuthorizedError`: For authentication issues
- `RateLimitExceededError`: For rate limit exceeded errors
- `ForbiddenError`: For forbidden access
- `BadRequestError`: For bad request errors
- And many more specific error types

## Optional API Parameters

The geocoding functions support all optional parameters from the OpenCage API:

- `language`: Preferred language for results
- `countrycode`: Limit results to specific countries
- `bounds`: Restrict results to within a bounding box
- `proximity`: Bias results towards a specific location
- `limit`: Maximum number of results to return
- `no_annotations`: Exclude annotations from results
- `no_record`: Don't store the query in the OpenCage database
- And many more

Example:

```julia
response = geocode(geocoder, "London", 
    language="fr",
    countrycode="gb",
    limit=5,
    no_annotations=true
)
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.