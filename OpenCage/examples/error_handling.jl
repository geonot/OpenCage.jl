# Error Handling Example
# This example demonstrates how to handle different types of errors that might occur

using OpenCage

println("OpenCage Error Handling Example:")
println("===============================")

# Create a geocoder instance
# ENV["OPENCAGE_API_KEY"] = "your-api-key"
geocoder = Geocoder()  # Uses OPENCAGE_API_KEY environment variable

# Function to demonstrate error handling
function try_geocode(query)
    println("\nTrying to geocode: '$query'")
    try
        response = geocode(geocoder, query)
        println("Success! Found $(response.total_results) results.")
        
        if !isempty(response.results)
            result = response.results[1]
            println("  Formatted: $(result.formatted)")
            println("  Coordinates: $(result.geometry.lat), $(result.geometry.lng)")
        else
            println("  No results found (empty results array)")
        end
        
        return response
    catch e
        println("Error occurred: $(typeof(e))")
        println("  Message: $(e.msg)")
        
        if e isa OpenCage.RateLimitExceededError
            if !ismissing(e.reset)
                reset_time = Dates.unix2datetime(e.reset)
                println("  Rate limit will reset at: $reset_time UTC")
            end
            if !ismissing(e.limit)
                println("  Your rate limit is: $(e.limit) requests per day")
            end
            if !ismissing(e.remaining)
                println("  Remaining requests: $(e.remaining)")
            end
        elseif e isa OpenCage.ServerError
            println("  HTTP Status Code: $(e.status_code)")
        elseif e isa OpenCage.NetworkError && !isnothing(e.original_exception)
            println("  Original exception: $(e.original_exception)")
        end
        
        return e
    end
end

println("\n1. Basic Successful Query")
try_geocode("Berlin, Germany")

println("\n2. Empty Query (Should Throw InvalidInputError)")
try_geocode("")

println("\n3. Query with Zero Results")
try_geocode("NOWHERE-INTERESTING")

println("\n4. Invalid Coordinates for Reverse Geocoding")
try
    println("\nTrying reverse geocoding with invalid coordinates")
    reverse_geocode(geocoder, "invalid", -0.1278)
catch e
    println("Error occurred: $(typeof(e))")
    println("  Message: $(e.msg)")
end

println("\n5. Handling Network Errors")
println("Creating a geocoder with an invalid API URL to simulate network error")
bad_geocoder = Geocoder(
    "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",  # Dummy API key
    api_base_url="https://invalid.example.com",
    timeout=2.0,  # Short timeout to fail quickly
    retries=1     # Minimal retries for the example
)

try
    geocode(bad_geocoder, "Berlin")
catch e
    println("Error occurred: $(typeof(e))")
    println("  Message: $(e.msg)")
    if e isa OpenCage.NetworkError && !isnothing(e.original_exception)
        println("  Original exception type: $(typeof(e.original_exception))")
    end
end

println("\n6. Handling Rate Limit Errors (Simulation)")
println("Note: This is a simulation as we can't easily trigger a real rate limit error")

# Create a simulated RateLimitExceededError
rate_limit_error = OpenCage.RateLimitExceededError(
    "Rate limit exceeded. Your daily quota has been reached.",
    limit=2500,
    remaining=0,
    reset=round(Int, time()) + 3600  # Reset in 1 hour
)

# Show how to handle it
println("If you encounter a rate limit error:")
println("Error type: $(typeof(rate_limit_error))")
println("Message: $(rate_limit_error.msg)")
println("Limit: $(rate_limit_error.limit)")
println("Remaining: $(rate_limit_error.remaining)")
reset_time = Dates.unix2datetime(rate_limit_error.reset)
println("Reset time: $reset_time UTC")

println("\n7. Retry Pattern for Transient Errors")
function geocode_with_retry(geocoder, query; max_retries=3, delay=2)
    for attempt in 1:max_retries
        try
            println("Attempt $attempt of $max_retries")
            return geocode(geocoder, query)
        catch e
            if attempt == max_retries
                println("Max retries reached, re-throwing error")
                rethrow(e)
            end
            
            # Only retry on certain errors
            if e isa OpenCage.NetworkError || 
               e isa OpenCage.TimeoutError || 
               e isa OpenCage.TooManyRequestsError ||
               e isa OpenCage.ServerError
                println("Encountered retryable error: $(typeof(e))")
                println("Waiting $(delay) seconds before retry...")
                sleep(delay)
                delay *= 2  # Exponential backoff
            else
                println("Non-retryable error, re-throwing")
                rethrow(e)
            end
        end
    end
end

println("\nDemonstrating retry pattern with invalid URL (will fail after retries):")
try
    geocode_with_retry(bad_geocoder, "Berlin")
catch e
    println("Final error after retries: $(typeof(e))")
    println("  Message: $(e.msg)")
end

println("\n8. Handling Batch Processing Errors")
println("For batch processing, you can use the 'on_error' parameter:")
println("  :log - Log errors and continue (default)")
println("  :skip - Skip rows with errors")
println("  :fail - Stop processing on any error")

println("\nExample of batch processing with error handling:")
println("""
batch_geocode(
    geocoder,
    "input.csv",
    "output.csv",
    on_error=:log,  # Log errors but continue processing
    workers=4
)
""")

println("\nError handling complete!")