@testset "Exceptions" begin
    @testset "Basic Exception Types" begin
        # Test basic exception creation
        @test OpenCage.InvalidInputError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.NotAuthorizedError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.ForbiddenError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.BadRequestError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.NotFoundError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.MethodNotAllowedError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.TimeoutError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.RequestTooLongError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.UpgradeRequiredError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.TooManyRequestsError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.ServerError("Test message", 500) isa OpenCage.OpenCageError
        @test OpenCage.NetworkError("Test message", nothing) isa OpenCage.OpenCageError
        @test OpenCage.BadResponseError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.BatchProcessingError("Test message") isa OpenCage.OpenCageError
        @test OpenCage.UnknownError("Test message") isa OpenCage.OpenCageError
    end
    
    @testset "RateLimitExceededError" begin
        # Test with all fields
        err = OpenCage.RateLimitExceededError("Rate limit exceeded", 
            limit=2500, remaining=0, reset=1609459200)
        @test err isa OpenCage.OpenCageError
        @test err.msg == "Rate limit exceeded"
        @test err.limit == 2500
        @test err.remaining == 0
        @test err.reset == 1609459200
        
        # Test with missing fields
        err = OpenCage.RateLimitExceededError("Rate limit exceeded")
        @test err isa OpenCage.OpenCageError
        @test err.msg == "Rate limit exceeded"
        @test ismissing(err.limit)
        @test ismissing(err.remaining)
        @test ismissing(err.reset)
    end
    
    @testset "ServerError" begin
        err = OpenCage.ServerError("Server error", 503)
        @test err isa OpenCage.OpenCageError
        @test err.msg == "Server error"
        @test err.status_code == 503
    end
    
    @testset "NetworkError" begin
        # Test with original exception
        original = ArgumentError("Original error")
        err = OpenCage.NetworkError("Network error", original)
        @test err isa OpenCage.OpenCageError
        @test err.msg == "Network error"
        @test err.original_exception == original
        
        # Test without original exception
        err = OpenCage.NetworkError("Network error", nothing)
        @test err isa OpenCage.OpenCageError
        @test err.msg == "Network error"
        @test err.original_exception === nothing
    end
    
    @testset "Error Messages" begin
        # Test basic error message
        err = OpenCage.InvalidInputError("Invalid input")
        io = IOBuffer()
        showerror(io, err)
        @test String(take!(io)) == "InvalidInputError: Invalid input"
        
        # Test RateLimitExceededError with reset time
        err = OpenCage.RateLimitExceededError("Rate limit exceeded", 
            limit=2500, remaining=0, reset=1609459200)
        io = IOBuffer()
        showerror(io, err)
        error_msg = String(take!(io))
        @test occursin("RateLimitExceededError: Rate limit exceeded", error_msg)
        @test occursin("Quota resets at", error_msg)
        @test occursin("[Details: limit=2500, remaining=0]", error_msg)
        
        # Test ServerError
        err = OpenCage.ServerError("Server error", 503)
        io = IOBuffer()
        showerror(io, err)
        @test String(take!(io)) == "ServerError: Server error (HTTP Status: 503)"
        
        # Test NetworkError with original exception
        original = ArgumentError("Original error")
        err = OpenCage.NetworkError("Network error", original)
        io = IOBuffer()
        showerror(io, err)
        error_msg = String(take!(io))
        @test occursin("NetworkError: Network error", error_msg)
        @test occursin("Original exception: ArgumentError: Original error", error_msg)
        
        # Test UnknownError
        err = OpenCage.UnknownError("Unknown error")
        io = IOBuffer()
        showerror(io, err)
        @test String(take!(io)) == "UnknownError: Unknown error"
    end
end