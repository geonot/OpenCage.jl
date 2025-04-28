using Test
using OpenCage
using Mocking

# Activate Mocking
Mocking.activate()

# Include test helper modules
include("TestHTTP.jl")
include("MockCSV.jl")

# Make the modules available to all test files
using .TestHTTP
using .MockCSV

@testset "OpenCage.jl" begin
    include("test_utils.jl")
    include("test_exceptions.jl")
    include("test_types.jl")
    include("test_core.jl")
    include("test_batch.jl")
end