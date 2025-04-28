using Dates

abstract type OpenCageError <: Exception end

struct InvalidInputError <: OpenCageError
    msg::String
end

struct NotAuthorizedError <: OpenCageError
    msg::String
end

struct RateLimitExceededError <: OpenCageError
    msg::String
    limit::Union{Int, Missing}
    remaining::Union{Int, Missing}
    reset::Union{Int, Missing}
    RateLimitExceededError(msg::String; limit=missing, remaining=missing, reset=missing) = new(msg, limit, remaining, reset)
end

struct ForbiddenError <: OpenCageError
    msg::String
end

struct BadRequestError <: OpenCageError
    msg::String
end

struct NotFoundError <: OpenCageError
    msg::String
end

struct MethodNotAllowedError <: OpenCageError
    msg::String
end

struct TimeoutError <: OpenCageError
    msg::String
end

struct RequestTooLongError <: OpenCageError
    msg::String
end

struct UpgradeRequiredError <: OpenCageError
    msg::String
end

struct TooManyRequestsError <: OpenCageError
    msg::String
end

struct ServerError <: OpenCageError
    msg::String
    status_code::Int
end

struct NetworkError <: OpenCageError
    msg::String
    original_exception::Any
end

struct BadResponseError <: OpenCageError
    msg::String
end

struct BatchProcessingError <: OpenCageError
    msg::String
end

struct UnknownError <: OpenCageError
    msg::String
end

function Base.showerror(io::IO, e::T) where T <: OpenCageError
    print(io, "$(nameof(T)): $(e.msg)")
    if e isa RateLimitExceededError && !ismissing(e.reset)
        try
            reset_time_utc = Dates.unix2datetime(e.reset)
            print(io, " (Quota resets at $(reset_time_utc) UTC)")
        catch err
            if err isa InexactError
                print(io, " (Quota reset timestamp: $(e.reset) - potentially invalid)")
            else
                rethrow(err)
            end
        end
    elseif e isa ServerError
        print(io, " (HTTP Status: $(e.status_code))")
    elseif e isa NetworkError
        if !isnothing(e.original_exception)
            print(io, "\n  Original exception: ")
            if e.original_exception isa OpenCageError
                print(io, e.original_exception)
            else
                showerror(io, e.original_exception)
            end
        end
    end
end

function Base.showerror(io::IO, e::RateLimitExceededError)
    invoke(Base.showerror, Tuple{IO, OpenCageError}, io, e)
    details = String[]
    !ismissing(e.limit) && push!(details, "limit=$(e.limit)")
    !ismissing(e.remaining) && push!(details, "remaining=$(e.remaining)")
    if !isempty(details)
        print(io, " [Details: $(join(details, ", "))]")
    end
end

function Base.showerror(io::IO, e::UnknownError)
    print(io, "UnknownError: $(e.msg)")
end
