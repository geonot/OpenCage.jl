@testset "Utils" begin
    @testset "_format_reverse_query" begin
        # Test with valid inputs
        @test OpenCage._format_reverse_query(51.5074, -0.1278) == "51.5074,-0.1278"
        @test OpenCage._format_reverse_query("51.5074", "-0.1278") == "51.5074,-0.1278"
        
        # Test with integers
        @test OpenCage._format_reverse_query(51, -0) == "51.0,0.0"
        
        # Test with invalid inputs
        @test_throws OpenCage.InvalidInputError OpenCage._format_reverse_query("invalid", "-0.1278")
        @test_throws OpenCage.InvalidInputError OpenCage._format_reverse_query(51.5074, "invalid")
    end
    
    @testset "_validate_api_key" begin
        # Test with valid key (30 alphanumeric characters)
        @test OpenCage._validate_api_key("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6") == true
        
        # Test with invalid keys
        @test OpenCage._validate_api_key("too_short") == false
        @test OpenCage._validate_api_key("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0") == false  # too long
        @test OpenCage._validate_api_key("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p!") == false  # non-alphanumeric
    end
    
    @testset "_build_url_params" begin
        # Test with basic parameters
        params = OpenCage._build_url_params("Berlin", "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6", Dict())
        @test params["key"] == "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
        @test params["q"] == "Berlin"
        
        # Test with optional parameters
        params = OpenCage._build_url_params(
            "Berlin", 
            "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6", 
            Dict(:language => "de", :limit => 5, :no_annotations => true)
        )
        @test params["key"] == "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
        @test params["q"] == "Berlin"
        @test params["language"] == "de"
        @test params["limit"] == "5"
        @test params["no_annotations"] == "1"
        
        # Test with bounds parameter
        params = OpenCage._build_url_params(
            "Berlin", 
            "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6", 
            Dict(:bounds => (51.0, 13.0, 52.0, 14.0))
        )
        @test params["bounds"] == "51.0,13.0,52.0,14.0"
        
        # Test with proximity parameter
        params = OpenCage._build_url_params(
            "Berlin", 
            "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6", 
            Dict(:proximity => (51.0, 13.0))
        )
        @test params["proximity"] == "51.0,13.0"
        
        # Test with countrycode parameter (string)
        params = OpenCage._build_url_params(
            "Berlin", 
            "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6", 
            Dict(:countrycode => "de")
        )
        @test params["countrycode"] == "DE"
        
        # Test with countrycode parameter (array)
        params = OpenCage._build_url_params(
            "Berlin", 
            "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6", 
            Dict(:countrycode => ["de", "fr"])
        )
        @test params["countrycode"] == "DE,FR"
    end
    
    @testset "_generate_user_agent" begin
        # Test basic user agent generation
        ua = OpenCage._generate_user_agent()
        @test occursin("opencage-julia", ua)
        @test occursin("Julia/", ua)
        @test occursin("HTTP.jl/", ua)
        
        # Test with user agent comment
        ua = OpenCage._generate_user_agent("Test Comment")
        @test occursin("opencage-julia", ua)
        @test occursin("Julia/", ua)
        @test occursin("HTTP.jl/", ua)
        @test occursin("Test Comment", ua)
        
        # Test with parentheses in comment (should be removed)
        ua = OpenCage._generate_user_agent("Test (Comment)")
        @test occursin("Test Comment", ua)
        @test !occursin("(", ua)
        @test !occursin(")", ua)
    end
    
    @testset "deep_get" begin
        # Create test data
        data = Dict(
            :name => "Test",
            :location => Dict(
                :city => "Berlin",
                :country => "Germany",
                :coordinates => Dict(
                    :lat => 52.5200,
                    :lng => 13.4050
                )
            ),
            :tags => ["test", "example"],
            :active => true,
            :missing_field => missing
        )
        
        # Test simple key access
        @test OpenCage.deep_get(data, "name") == "Test"
        @test OpenCage.deep_get(data, "active") == true
        
        # Test nested key access
        @test OpenCage.deep_get(data, "location.city") == "Berlin"
        @test OpenCage.deep_get(data, "location.country") == "Germany"
        @test OpenCage.deep_get(data, "location.coordinates.lat") == 52.5200
        @test OpenCage.deep_get(data, "location.coordinates.lng") == 13.4050
        
        # Test missing keys
        @test ismissing(OpenCage.deep_get(data, "nonexistent"))
        @test ismissing(OpenCage.deep_get(data, "location.nonexistent"))
        @test ismissing(OpenCage.deep_get(data, "location.coordinates.nonexistent"))
        
        # Test with default value
        @test OpenCage.deep_get(data, "nonexistent", "default") == "default"
        @test OpenCage.deep_get(data, "location.nonexistent", 0) == 0
        
        # Test with missing value
        @test ismissing(OpenCage.deep_get(data, "missing_field"))
        
        # Test with empty key
        @test ismissing(OpenCage.deep_get(data, ""))
        @test OpenCage.deep_get(data, "", "default") == "default"
    end
    
    @testset "_parse_rate_limit" begin
        # Test with valid rate info
        response_body = Dict(
            :rate => Dict(
                :limit => 2500,
                :remaining => 2000,
                :reset => 1609459200
            )
        )
        rate_info = OpenCage._parse_rate_limit(response_body)
        @test !ismissing(rate_info)
        @test rate_info.limit == 2500
        @test rate_info.remaining == 2000
        @test rate_info.reset == 1609459200
        
        # Test with missing fields
        response_body = Dict(
            :rate => Dict(
                :limit => 2500
            )
        )
        rate_info = OpenCage._parse_rate_limit(response_body)
        @test !ismissing(rate_info)
        @test rate_info.limit == 2500
        @test ismissing(rate_info.remaining)
        @test ismissing(rate_info.reset)
        
        # Test with missing rate info
        response_body = Dict()
        rate_info = OpenCage._parse_rate_limit(response_body)
        @test ismissing(rate_info)
    end
end