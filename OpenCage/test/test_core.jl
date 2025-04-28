using HTTP
using Test

@testset "Core" begin
    @testset "Geocoder Construction" begin
        # Test with explicit API key
        geocoder = OpenCage.Geocoder("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6")
        @test geocoder.api_key == "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
        @test geocoder.api_base_url == OpenCage.DEFAULT_API_BASE_URL
        @test geocoder.timeout == OpenCage.DEFAULT_TIMEOUT
        @test geocoder.retries == OpenCage.DEFAULT_RETRIES
        @test occursin("opencage-julia", geocoder.user_agent)
        
        # Test with custom options
        geocoder = OpenCage.Geocoder(
            "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
            api_base_url="https://custom.api.url",
            user_agent_comment="Test Comment",
            timeout=30.0,
            retries=3,
            retry_options=Dict(:max_delay => 30.0),
            extra_http_options=Dict(:verbose => true)
        )
        
        @test geocoder.api_key == "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
        @test geocoder.api_base_url == "https://custom.api.url"
        @test geocoder.timeout == 30.0
        @test geocoder.retries == 3
        @test geocoder.retry_options[:max_delay] == 30.0
        @test geocoder.extra_http_options[:verbose] == true
        @test occursin("Test Comment", geocoder.user_agent)
        
        # Test with empty API key
        @test_throws OpenCage.InvalidInputError OpenCage.Geocoder("")
        
        # Test with environment variable (this will be mocked)
        withenv("OPENCAGE_API_KEY" => "env_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6") do
            geocoder = OpenCage.Geocoder()
            @test geocoder.api_key == "env_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
        end
        
        # Test with missing environment variable
        withenv("OPENCAGE_API_KEY" => nothing) do
            @test_throws OpenCage.InvalidInputError OpenCage.Geocoder()
        end
    end
    
    @testset "_prepare_http_options" begin
        geocoder = OpenCage.Geocoder(
            "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
            timeout=30.0,
            extra_http_options=Dict(:verbose => true)
        )
        
        options = OpenCage._prepare_http_options(geocoder)
        @test options[:connect_timeout] == 30.0
        @test options[:readtimeout] == 30.0
        @test options[:verbose] == true
    end
    
    @testset "_is_retryable_error" begin
        # Create mock HTTP exceptions for testing
        struct MockStatusError <: Exception
            status::Int
            message::String
        end
        
        struct MockConnectError <: Exception
            message::String
        end
        
        struct MockTimeoutError <: Exception
            message::String
        end
        
        # Test retryable HTTP status errors
        @test OpenCage._is_retryable_error(MockStatusError(408, "Request Timeout"))
        @test OpenCage._is_retryable_error(MockStatusError(429, "Too Many Requests"))
        @test OpenCage._is_retryable_error(MockStatusError(500, "Internal Server Error"))
        @test OpenCage._is_retryable_error(MockStatusError(502, "Bad Gateway"))
        @test OpenCage._is_retryable_error(MockStatusError(503, "Service Unavailable"))
        @test OpenCage._is_retryable_error(MockStatusError(504, "Gateway Timeout"))
        
        # Test non-retryable HTTP status errors
        @test !OpenCage._is_retryable_error(MockStatusError(400, "Bad Request"))
        @test !OpenCage._is_retryable_error(MockStatusError(401, "Unauthorized"))
        @test !OpenCage._is_retryable_error(MockStatusError(403, "Forbidden"))
        @test !OpenCage._is_retryable_error(MockStatusError(404, "Not Found"))
        
        # Test retryable OpenCage errors
        @test OpenCage._is_retryable_error(OpenCage.NetworkError("Network error", nothing))
        @test OpenCage._is_retryable_error(OpenCage.TimeoutError("Timeout error"))
        @test OpenCage._is_retryable_error(OpenCage.TooManyRequestsError("Too many requests"))
        @test OpenCage._is_retryable_error(OpenCage.ServerError("Server error", 500))
        
        # Test non-retryable OpenCage errors
        @test !OpenCage._is_retryable_error(OpenCage.InvalidInputError("Invalid input"))
        @test !OpenCage._is_retryable_error(OpenCage.NotAuthorizedError("Not authorized"))
        @test !OpenCage._is_retryable_error(OpenCage.ForbiddenError("Forbidden"))
        @test !OpenCage._is_retryable_error(OpenCage.BadRequestError("Bad request"))
        
        # Test retryable IO errors
        @test OpenCage._is_retryable_error(Base.IOError("IO error", 0))
        @test OpenCage._is_retryable_error(MockConnectError("Connection error"))
        @test OpenCage._is_retryable_error(MockTimeoutError("Timeout error"))
        
        # Test other errors
        @test !OpenCage._is_retryable_error(ArgumentError("Argument error"))
    end
    
    @testset "_map_status_code_to_exception" begin
        # Test mapping HTTP status codes to exceptions
        @test OpenCage._map_status_code_to_exception(400, "Bad Request") isa OpenCage.BadRequestError
        @test OpenCage._map_status_code_to_exception(401, "Unauthorized") isa OpenCage.NotAuthorizedError
        @test OpenCage._map_status_code_to_exception(402, "Payment Required") isa OpenCage.RateLimitExceededError
        @test OpenCage._map_status_code_to_exception(403, "Forbidden") isa OpenCage.ForbiddenError
        @test OpenCage._map_status_code_to_exception(404, "Not Found") isa OpenCage.NotFoundError
        @test OpenCage._map_status_code_to_exception(405, "Method Not Allowed") isa OpenCage.MethodNotAllowedError
        @test OpenCage._map_status_code_to_exception(408, "Request Timeout") isa OpenCage.TimeoutError
        @test OpenCage._map_status_code_to_exception(410, "Gone") isa OpenCage.RequestTooLongError
        @test OpenCage._map_status_code_to_exception(426, "Upgrade Required") isa OpenCage.UpgradeRequiredError
        @test OpenCage._map_status_code_to_exception(429, "Too Many Requests") isa OpenCage.TooManyRequestsError
        @test OpenCage._map_status_code_to_exception(500, "Internal Server Error") isa OpenCage.ServerError
        @test OpenCage._map_status_code_to_exception(502, "Bad Gateway") isa OpenCage.ServerError
        @test OpenCage._map_status_code_to_exception(503, "Service Unavailable") isa OpenCage.ServerError
        @test OpenCage._map_status_code_to_exception(504, "Gateway Timeout") isa OpenCage.ServerError
        @test OpenCage._map_status_code_to_exception(418, "I'm a teapot") isa OpenCage.UnknownError
        
        # Test with rate info
        headers = ["X-RateLimit-Limit" => "2500", "X-RateLimit-Remaining" => "2000", "X-RateLimit-Reset" => "1609459200"]
        response = HTTP.Response(429, headers, body="{}")
        err = OpenCage._map_status_code_to_exception(429, "Too Many Requests", response)
        @test err isa OpenCage.TooManyRequestsError
        
        # Test with rate info in body
        body = """
        {
            "status": {
                "code": 429,
                "message": "Too Many Requests"
            },
            "rate": {
                "limit": 2500,
                "remaining": 0,
                "reset": 1609459200
            }
        }
        """
        response = HTTP.Response(429, [], body=body)
        err = OpenCage._map_status_code_to_exception(429, "Too Many Requests", response)
        @test err isa OpenCage.TooManyRequestsError
    end
    
    @testset "Geocoding Functions (Mocked)" begin
        using Mocking
        Mocking.activate()
        
        # Create a mock for _request function
        request_patch = @patch function OpenCage._request(geocoder::OpenCage.Geocoder, params::Dict{String, String})
            if haskey(params, "q") && params["q"] == "Berlin"
                return OpenCage.Response(
                    OpenCage.Status(200, "OK"),
                    [OpenCage.Result(
                        missing, missing, missing, 9, missing,
                        "Berlin, Germany",
                        OpenCage.Geometry(52.52, 13.405)
                    )],
                    OpenCage.RateInfo(2500, 2499, 1609459200),
                    missing, missing, missing, missing, missing
                )
            elseif haskey(params, "q") && params["q"] == "51.5074,-0.1278"
                return OpenCage.Response(
                    OpenCage.Status(200, "OK"),
                    [OpenCage.Result(
                        missing, missing, missing, 10, missing,
                        "London, United Kingdom",
                        OpenCage.Geometry(51.5074, -0.1278)
                    )],
                    OpenCage.RateInfo(2500, 2498, 1609459200),
                    missing, missing, missing, missing, missing
                )
            else
                throw(OpenCage.InvalidInputError("Invalid query"))
            end
        end
        
        # Test forward geocoding with mocks
        apply([request_patch]) do
            geocoder = OpenCage.Geocoder("mock_api_key")
            response = geocode(geocoder, "Berlin")
            
            @test response isa OpenCage.Response
            @test response.status.code == 200
            @test response.status.message == "OK"
            @test length(response.results) == 1
            @test response.results[1].formatted == "Berlin, Germany"
            @test response.results[1].geometry.lat == 52.52
            @test response.results[1].geometry.lng == 13.405
            @test response.results[1].confidence == 9
        end
        
        # Test reverse geocoding with mocks
        apply([request_patch]) do
            geocoder = OpenCage.Geocoder("mock_api_key")
            response = reverse_geocode(geocoder, 51.5074, -0.1278)
            
            @test response isa OpenCage.Response
            @test response.status.code == 200
            @test response.status.message == "OK"
            @test length(response.results) == 1
            @test response.results[1].formatted == "London, United Kingdom"
            @test response.results[1].geometry.lat == 51.5074
            @test response.results[1].geometry.lng == -0.1278
            @test response.results[1].confidence == 10
        end
    end
    
    @testset "Async Geocoding Functions (Mocked)" begin
        using Mocking
        Mocking.activate()
        
        # Create a mock for geocode_async
        geocode_async_patch = @patch function OpenCage.geocode_async(geocoder::OpenCage.Geocoder, query::AbstractString; kwargs...)
            task = @async begin
                if query == "Paris"
                    return OpenCage.Response(
                        OpenCage.Status(200, "OK"),
                        [OpenCage.Result(
                            missing, missing, missing, 9, missing,
                            "Paris, France",
                            OpenCage.Geometry(48.8566, 2.3522)
                        )],
                        OpenCage.RateInfo(2500, 2497, 1609459200),
                        missing, missing, missing, missing, missing
                    )
                else
                    throw(OpenCage.InvalidInputError("Invalid query"))
                end
            end
            return task
        end
        
        # Create a mock for reverse_geocode_async
        reverse_geocode_async_patch = @patch function OpenCage.reverse_geocode_async(geocoder::OpenCage.Geocoder, lat::Number, lng::Number; kwargs...)
            task = @async begin
                if lat == 35.6762 && lng == 139.6503
                    return OpenCage.Response(
                        OpenCage.Status(200, "OK"),
                        [OpenCage.Result(
                            missing, missing, missing, 10, missing,
                            "Tokyo, Japan",
                            OpenCage.Geometry(35.6762, 139.6503)
                        )],
                        OpenCage.RateInfo(2500, 2496, 1609459200),
                        missing, missing, missing, missing, missing
                    )
                else
                    throw(OpenCage.InvalidInputError("Invalid coordinates"))
                end
            end
            return task
        end
        
        # Test async forward geocoding with mocks
        apply([geocode_async_patch]) do
            geocoder = OpenCage.Geocoder("mock_api_key")
            task = geocode_async(geocoder, "Paris")
            response = fetch(task)
            
            @test response isa OpenCage.Response
            @test response.status.code == 200
            @test response.status.message == "OK"
            @test length(response.results) == 1
            @test response.results[1].formatted == "Paris, France"
            @test response.results[1].geometry.lat == 48.8566
            @test response.results[1].geometry.lng == 2.3522
            @test response.results[1].confidence == 9
        end
        
        # Test async reverse geocoding with mocks
        apply([reverse_geocode_async_patch]) do
            geocoder = OpenCage.Geocoder("mock_api_key")
            task = reverse_geocode_async(geocoder, 35.6762, 139.6503)
            response = fetch(task)
            
            @test response isa OpenCage.Response
            @test response.status.code == 200
            @test response.status.message == "OK"
            @test length(response.results) == 1
            @test response.results[1].formatted == "Tokyo, Japan"
            @test response.results[1].geometry.lat == 35.6762
            @test response.results[1].geometry.lng == 139.6503
            @test response.results[1].confidence == 10
        end
    end
end