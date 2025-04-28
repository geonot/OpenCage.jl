# Basic Geocoding Example
# This example demonstrates how to perform basic forward and reverse geocoding

using OpenCage

# Create a geocoder instance
# You can either set the OPENCAGE_API_KEY environment variable or pass the key directly
# ENV["OPENCAGE_API_KEY"] = "your-api-key"
geocoder = Geocoder()  # Uses OPENCAGE_API_KEY environment variable
# Or: geocoder = Geocoder("your-api-key")

println("Forward Geocoding Example:")
println("==========================")

# Forward geocoding (place name/address to coordinates)
query = "Berlin, Germany"
println("Geocoding query: $query")

response = geocode(geocoder, query)

println("Status: $(response.status.code) - $(response.status.message)")
println("Total results: $(response.total_results)")

if !isempty(response.results)
    result = response.results[1]
    println("\nFirst result:")
    println("Formatted address: $(result.formatted)")
    println("Coordinates: $(result.geometry.lat), $(result.geometry.lng)")
    println("Confidence: $(result.confidence)")
    
    if !ismissing(result.components) && !ismissing(result.components.country)
        println("Country: $(result.components.country)")
    end
end

println("\nReverse Geocoding Example:")
println("===========================")

# Reverse geocoding (coordinates to place name/address)
lat, lng = 51.5074, -0.1278
println("Reverse geocoding coordinates: $lat, $lng")

response = reverse_geocode(geocoder, lat, lng)

println("Status: $(response.status.code) - $(response.status.message)")
println("Total results: $(response.total_results)")

if !isempty(response.results)
    result = response.results[1]
    println("\nResult:")
    println("Formatted address: $(result.formatted)")
    
    if !ismissing(result.components)
        if !ismissing(result.components.country)
            println("Country: $(result.components.country)")
        end
        if !ismissing(result.components.city)
            println("City: $(result.components.city)")
        end
        if !ismissing(result.components.road)
            println("Road: $(result.components.road)")
        end
    end
end

# Rate limit information
if !ismissing(response.rate)
    println("\nRate Limit Information:")
    println("Limit: $(response.rate.limit)")
    println("Remaining: $(response.rate.remaining)")
    println("Reset: $(response.rate.reset)")
end