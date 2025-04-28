module TestHTTP
    using HTTP
    using Mocking

    export MockResponse, mock_http_request, mock_http_request_async, reset_mocks

    struct MockResponse
        status::Int
        headers::Vector{Pair{String, String}}
        body::String
    end

    # Global registry of mock responses
    const MOCK_RESPONSES = Dict{String, Union{MockResponse, Function}}()
    
    # Clear all registered mock responses
    function reset_mocks()
        empty!(MOCK_RESPONSES)
    end

    # Register a mock response for a specific query
    function register_response(query::String, response::Union{MockResponse, Function})
        MOCK_RESPONSES[query] = response
    end

    # Get a mock response for a query
    function get_mock_response(query::String)
        if haskey(MOCK_RESPONSES, query)
            response = MOCK_RESPONSES[query]
            if response isa Function
                return response()
            else
                return response
            end
        end
        error("No mock response registered for query: $query")
    end

    # Mock for HTTP.get
    function mock_http_get(url::String, headers::Dict; query=nothing, status_exception=true, kwargs...)
        query_str = get(query, "q", "")
        mock_response = get_mock_response(query_str)
        return HTTP.Response(mock_response.status, mock_response.headers, body=mock_response.body)
    end

    # Mock for HTTP.request and async operations
    function mock_request(method::String, url::String, headers::Dict, body; query=nothing, kwargs...)
        query_str = get(query, "q", "")
        mock_response = get_mock_response(query_str)
        return HTTP.Response(mock_response.status, mock_response.headers, body=mock_response.body)
    end

    # Mock for async read
    function mock_read_body(body)
        return copy(body)
    end

    # Create patches for HTTP functions
    const HTTP_GET_PATCH = @patch HTTP.get(url::String, headers::Dict; kwargs...) =
        TestHTTP.mock_http_get(url, headers; kwargs...)

    const HTTP_REQUEST_PATCH = @patch HTTP.request(method::String, url::String, headers::Dict, body; kwargs...) =
        TestHTTP.mock_request(method, url, headers, body; kwargs...)

    const HTTP_READ_PATCH = @patch read(body) =
        TestHTTP.mock_read_body(body)

    # Helper function to apply all HTTP mocks
    function mock_http_request(f::Function)
        apply([HTTP_GET_PATCH]) do
            f()
        end
    end

    # Helper function to apply all HTTP mocks for async requests
    function mock_http_request_async(f::Function)
        apply([HTTP_GET_PATCH, HTTP_REQUEST_PATCH, HTTP_READ_PATCH]) do
            f()
        end
    end
end