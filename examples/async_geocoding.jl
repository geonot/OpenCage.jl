# Asynchronous Geocoding Example
# This example demonstrates how to perform asynchronous geocoding operations

using OpenCage

# Create a geocoder instance
# ENV["OPENCAGE_API_KEY"] = "your-api-key"
geocoder = Geocoder()  # Uses OPENCAGE_API_KEY environment variable

println("Asynchronous Geocoding Example:")
println("===============================")

# Create a list of locations to geocode
locations = [
    "Berlin, Germany",
    "Paris, France",
    "London, UK",
    "New York, USA",
    "Tokyo, Japan"
]

println("Starting asynchronous geocoding for $(length(locations)) locations...")

# Start asynchronous geocoding tasks for all locations
tasks = [geocode_async(geocoder, location) for location in locations]

# Process results as they complete
for (i, task) in enumerate(tasks)
    try
        response = fetch(task)
        
        if !isempty(response.results)
            result = response.results[1]
            println("\nLocation $(i): $(locations[i])")
            println("  Coordinates: $(result.geometry.lat), $(result.geometry.lng)")
            println("  Formatted: $(result.formatted)")
        else
            println("\nLocation $(i): $(locations[i]) - No results found")
        end
    catch e
        println("\nLocation $(i): $(locations[i]) - Error: $(e)")
    end
end

println("\nAsynchronous Reverse Geocoding Example:")
println("=======================================")

# Create a list of coordinates to reverse geocode
coordinates = [
    (51.5074, -0.1278),  # London
    (48.8566, 2.3522),   # Paris
    (52.5200, 13.4050),  # Berlin
    (40.7128, -74.0060), # New York
    (35.6762, 139.6503)  # Tokyo
]

println("Starting asynchronous reverse geocoding for $(length(coordinates)) coordinates...")

# Start asynchronous reverse geocoding tasks for all coordinates
tasks = [reverse_geocode_async(geocoder, lat, lng) for (lat, lng) in coordinates]

# Process results as they complete
for (i, task) in enumerate(tasks)
    try
        response = fetch(task)
        
        if !isempty(response.results)
            result = response.results[1]
            println("\nCoordinates $(i): $(coordinates[i])")
            println("  Formatted: $(result.formatted)")
            
            if !ismissing(result.components) && !ismissing(result.components.country)
                println("  Country: $(result.components.country)")
            end
        else
            println("\nCoordinates $(i): $(coordinates[i]) - No results found")
        end
    catch e
        println("\nCoordinates $(i): $(coordinates[i]) - Error: $(e)")
    end
end

# Example of using @sync to wait for all tasks to complete
println("\nUsing @sync to wait for all tasks:")
println("=================================")

@sync begin
    for location in locations
        @async begin
            try
                response = fetch(geocode_async(geocoder, location))
                if !isempty(response.results)
                    result = response.results[1]
                    println("$location: $(result.geometry.lat), $(result.geometry.lng)")
                else
                    println("$location: No results found")
                end
            catch e
                println("$location: Error: $(e)")
            end
        end
    end
end

println("\nAll asynchronous operations completed!")