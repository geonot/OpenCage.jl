# Batch Geocoding Example
# This example demonstrates how to perform batch geocoding operations

using OpenCage
using CSV
using DataFrames

# Create a geocoder instance
# ENV["OPENCAGE_API_KEY"] = "your-api-key"
geocoder = Geocoder()  # Uses OPENCAGE_API_KEY environment variable

println("Batch Geocoding Example:")
println("=======================")

# Create a temporary input CSV file
input_file = "batch_input.csv"
output_file = "batch_output.csv"

# Create sample data
data = DataFrame(
    address = [
        "Berlin, Germany",
        "Paris, France",
        "London, UK",
        "New York, USA",
        "Tokyo, Japan",
        "Sydney, Australia",
        "Cairo, Egypt",
        "Rio de Janeiro, Brazil",
        "Moscow, Russia",
        "Toronto, Canada"
    ]
)

# Write sample data to CSV
CSV.write(input_file, data)
println("Created input file with $(nrow(data)) addresses")

# Perform batch geocoding
println("\nStarting batch geocoding...")
batch_geocode(
    geocoder,
    input_file,
    output_file,
    workers=4,
    input_columns=[1],  # Use the first column (address) for geocoding
    add_columns=["formatted", "geometry.lat", "geometry.lng", "confidence", "components.country", "components.country_code"],
    progress=true,
    ordered=true  # Ensure output rows are in the same order as input
)
println("Batch geocoding completed!")

# Read and display results
results = CSV.read(output_file, DataFrame)
println("\nResults (first 5 rows):")
println(first(results, 5))

println("\nSummary statistics:")
println("Total rows: $(nrow(results))")

# Count successful geocodes (non-empty lat/lng)
success_count = count(!ismissing, results[:, "geometry.lat"])
println("Successful geocodes: $success_count ($(round(success_count/nrow(results)*100, digits=1))%)")

# Clean up temporary files
rm(input_file)
println("\nCleaned up temporary input file")
# Uncomment to remove output file as well
# rm(output_file)
# println("Cleaned up temporary output file")

println("\nBatch Reverse Geocoding Example:")
println("===============================")

# Create sample coordinates data
coords_data = DataFrame(
    lat = [51.5074, 48.8566, 52.5200, 40.7128, 35.6762],
    lng = [-0.1278, 2.3522, 13.4050, -74.0060, 139.6503]
)

# Write sample coordinates to CSV
coords_input_file = "batch_coords_input.csv"
coords_output_file = "batch_coords_output.csv"
CSV.write(coords_input_file, coords_data)
println("Created input file with $(nrow(coords_data)) coordinate pairs")

# Perform batch reverse geocoding
println("\nStarting batch reverse geocoding...")
batch_geocode(
    geocoder,
    coords_input_file,
    coords_output_file,
    workers=4,
    input_columns=[1, 2],  # Use the first two columns (lat, lng) for reverse geocoding
    add_columns=["formatted", "components.country", "components.city", "components.road"],
    progress=true,
    ordered=true  # Ensure output rows are in the same order as input
)
println("Batch reverse geocoding completed!")

# Read and display results
reverse_results = CSV.read(coords_output_file, DataFrame)
println("\nReverse geocoding results:")
println(reverse_results)

# Clean up temporary files
rm(coords_input_file)
println("\nCleaned up temporary input file")
# Uncomment to remove output file as well
# rm(coords_output_file)
# println("Cleaned up temporary output file")

println("\nAdvanced Batch Geocoding Example:")
println("================================")
println("This example shows how to handle errors and customize batch processing")

# Create sample data with some problematic entries
advanced_data = DataFrame(
    address = [
        "Berlin, Germany",
        "",  # Empty address
        "NOWHERE-INTERESTING",  # Will return zero results
        "London, UK",
        "123456789012345678901234567890123456789012345678901234567890",  # Very long query
        "New York, USA"
    ]
)

# Write sample data to CSV
advanced_input_file = "batch_advanced_input.csv"
advanced_output_file = "batch_advanced_output.csv"
CSV.write(advanced_input_file, advanced_data)

println("\nStarting advanced batch geocoding...")
batch_geocode(
    geocoder,
    advanced_input_file,
    advanced_output_file,
    workers=2,
    input_columns=[1],
    add_columns=["formatted", "geometry.lat", "geometry.lng", "status_message"],
    on_error=:log,  # Log errors but continue processing
    progress=true,
    ordered=true,
    optional_api_params=Dict(
        :language => "en",
        :limit => 1,
        :no_annotations => true
    )
)
println("Advanced batch geocoding completed!")

# Read and display results
advanced_results = CSV.read(advanced_output_file, DataFrame)
println("\nAdvanced batch results:")
println(advanced_results)

# Clean up temporary files
rm(advanced_input_file)
println("\nCleaned up temporary files")
# Uncomment to remove output file as well
# rm(advanced_output_file)