# src/batch.jl

using CSV
using ProgressMeter
using Logging
using Base: @kwdef

include("exceptions.jl")
include("types.jl")
include("utils.jl")
include("core.jl")

const DEFAULT_INPUT_BUFFER = 1000
const DEFAULT_OUTPUT_BUFFER = 1000

"""
    batch_geocode(
        geocoder::Geocoder,
        input::Union{AbstractString, IO},
        output::Union{AbstractString, IO};
        workers::Int = 4,
        retries::Int = 5,
        timeout::Float64 = 60.0,
        input_columns::Union{Vector{Int}, Nothing} = nothing,
        add_columns::Vector{<:AbstractString} = ["formatted", "geometry.lat", "geometry.lng", "confidence", "components._type", "status_message"],
        on_error::Symbol = :log,
        ordered::Bool = false,
        progress::Bool = true,
        limit::Union{Int, Nothing} = nothing,
        optional_api_params::Dict{Symbol, Any} = Dict{Symbol, Any}(),
        rate_limit_semaphore::Union{Base.Semaphore, Nothing} = nothing,
        command::Union{Symbol, Nothing} = nothing
    )

Process a batch of geocoding requests from a CSV file or IO stream.

This function efficiently processes large datasets by using multiple worker tasks
to perform geocoding operations concurrently. It reads from the input CSV, geocodes
each row, and writes the results to the output CSV.

# Arguments
- `geocoder::Geocoder`: The geocoder instance to use for the requests
- `input::Union{AbstractString, IO}`: The input CSV file path or IO stream
- `output::Union{AbstractString, IO}`: The output CSV file path or IO stream

# Optional Parameters
- `workers::Int = 4`: Number of concurrent worker tasks
- `retries::Int = 5`: Number of retries for failed requests
- `timeout::Float64 = 60.0`: Request timeout in seconds
- `input_columns::Union{Vector{Int}, Nothing} = nothing`: Specific columns to use for geocoding (1-based indexing)
  - If `nothing`, all columns are used to form the query
  - If a single column is specified, it's used as the address for forward geocoding
  - If two columns are specified, they're used as latitude and longitude for reverse geocoding
- `add_columns::Vector{<:AbstractString} = ["formatted", "geometry.lat", "geometry.lng", "confidence", "components._type", "status_message"]`:
  Fields from the geocoding result to add as output columns
- `on_error::Symbol = :log`: How to handle errors during processing
  - `:log`: Log errors and continue processing (default)
  - `:skip`: Skip rows with errors
  - `:fail`: Stop processing on any error
- `ordered::Bool = false`: Whether to preserve the input row order in the output
- `progress::Bool = true`: Whether to display a progress bar
- `limit::Union{Int, Nothing} = nothing`: Maximum number of rows to process
- `optional_api_params::Dict{Symbol, Any} = Dict{Symbol, Any}()`: Additional parameters to pass to the API
- `rate_limit_semaphore::Union{Base.Semaphore, Nothing} = nothing`: Optional semaphore for rate limiting
- `command::Union{Symbol, Nothing} = nothing`: Force a specific geocoding command
  - `:forward`: Force forward geocoding
  - `:reverse`: Force reverse geocoding
  - `nothing`: Auto-detect based on input columns

# Returns
- `nothing`: The function writes results to the output file/stream

# Throws
- `BatchProcessingError`: If an error occurs during batch processing
- `InvalidInputError`: If the input parameters are invalid

# Examples
```julia
# Basic usage with file paths
batch_geocode(
    geocoder,
    "input.csv",
    "output.csv"
)

# With custom options
batch_geocode(
    geocoder,
    "input.csv",
    "output.csv",
    workers=8,
    input_columns=[2],  # Use the second column for geocoding
    add_columns=["formatted", "geometry.lat", "geometry.lng", "components.country"],
    on_error=:skip,
    ordered=true,
    progress=true
)

# Reverse geocoding with coordinates in columns 1 and 2
batch_geocode(
    geocoder,
    "coordinates.csv",
    "addresses.csv",
    input_columns=[1, 2],  # Latitude and longitude columns
    command=:reverse
)
```
"""
function batch_geocode(
    geocoder::Geocoder,
    input::Union{AbstractString, IO},
    output::Union{AbstractString, IO};
    workers::Int = 4,
    retries::Int = 5,
    timeout::Float64 = 60.0,
    input_columns::Union{Vector{Int}, Nothing} = nothing,
    add_columns::Vector{<:AbstractString} = ["formatted", "geometry.lat", "geometry.lng", "confidence", "components._type", "status_message"],
    on_error::Symbol = :log,
    ordered::Bool = false,
    progress::Bool = true,
    limit::Union{Int, Nothing} = nothing,
    optional_api_params::Dict{Symbol, Any} = Dict{Symbol, Any}(),
    rate_limit_semaphore::Union{Base.Semaphore, Nothing} = nothing,
    command::Union{Symbol, Nothing} = nothing
    )

    if on_error ∉ (:log, :skip, :fail)
        throw(BatchProcessingError("Invalid 'on_error' option: '$on_error'. Must be :log, :skip, or :fail."))
    end
    if !isnothing(command) && command ∉ (:forward, :reverse)
         throw(BatchProcessingError("Invalid 'command' option: '$command'. Must be :forward or :reverse."))
    end

    opts = BatchOptions(;
        workers=workers, retries=retries, timeout=timeout,
        input_columns=input_columns, add_columns=add_columns, on_error=on_error,
        ordered=ordered, progress=progress, limit=limit,
        optional_api_params=optional_api_params,
        rate_limit_semaphore=rate_limit_semaphore, command=command
    )

    worker_count = opts.workers
    preflight_task = @async _preflight_check(geocoder) # Start check concurrently
    try
        is_free, check_msg = fetch(preflight_task)
        if is_free === true && worker_count > 1
            @warn "Free trial API key detected. Reducing worker count to 1 to comply with rate limits."
            worker_count = 1
            opts = BatchOptions(opts; workers=1)
        elseif !isnothing(check_msg)
            throw(BatchProcessingError("API key pre-flight check failed: $check_msg"))
        end
    catch e
        throw(BatchProcessingError("API key pre-flight check failed: $e"))
    end

    input_stream = input isa IO ? input : open(input, "r")
    output_stream = output isa IO ? output : open(output, "w")
    try
        input_channel = Channel{Job}(DEFAULT_INPUT_BUFFER)
        output_channel = Channel{BatchResult}(DEFAULT_OUTPUT_BUFFER)
        total_items = Ref{Union{Int, Nothing}}(nothing)
        output_headers = Ref{Union{Vector{String}, Nothing}}(nothing)

        prog = opts.progress ? Progress(1; desc="Geocoding: ", dt=0.5, barglyphs=BarGlyphs("[=> ]")) : nothing

        reader_task = @async _batch_reader(input_stream, input_channel, opts, total_items, prog)
        writer_task = @async _batch_writer(output_stream, output_channel, opts, output_headers, prog)

        worker_tasks = Vector{Task}(undef, worker_count)
        for i in 1:worker_count
            worker_tasks[i] = @async _batch_worker(geocoder, input_channel, output_channel, opts, i)
        end

        wait(reader_task)
        @debug "Reader task finished."

        try
            @sync for task in worker_tasks
                wait(task)
            end
        catch e
            @error "A worker task failed, stopping batch processing." exception=(e, catch_backtrace())
            close(input_channel)
            close(output_channel)
            throw(BatchProcessingError("Worker task failed: $e"))
        end
        @debug "All worker tasks finished."

        close(output_channel)

        wait(writer_task)
        @debug "Writer task finished."

        if opts.progress && !isnothing(prog)
            final_count = !isnothing(total_items[]) ? total_items[] : (isnothing(prog.n) || prog.n==1 ? 0 : prog.counter)
            ProgressMeter.update!(prog, final_count, force=true)
            finish!(prog)
        end
        @info "Batch geocoding completed."

    catch e
        @error "Batch geocoding failed." exception=(e, catch_backtrace())
        if e isa BatchProcessingError
            rethrow()
        else
            throw(BatchProcessingError("An unexpected error occurred during batch processing: $e"))
        end
    finally
        input isa AbstractString && isopen(input_stream) && close(input_stream)
        output isa AbstractString && isopen(output_stream) && close(output_stream)
        @debug "Input/Output streams closed."
    end

    return nothing
end

"""
    _preflight_check(geocoder::Geocoder)::Tuple{Union{Bool, Nothing}, Union{String, Nothing}}

Perform a pre-flight check to validate the API key and detect free-tier accounts.

This function makes a test request to the OpenCage API to verify that the API key is valid
and to detect if it's a free-tier account (which has a lower rate limit).

# Arguments
- `geocoder::Geocoder`: The geocoder instance to use for the test request

# Returns
- `Tuple{Union{Bool, Nothing}, Union{String, Nothing}}`: A tuple containing:
  - First element: `true` if free-tier account detected, `false` if paid account, `nothing` if error
  - Second element: Error message if an error occurred, `nothing` otherwise

# Implementation Details
- Makes a test request to the API with a known location
- Checks the rate limit information to determine if it's a free-tier account (limit == 2500)
- Returns appropriate error messages for different types of failures
"""
function _preflight_check(geocoder::Geocoder)::Tuple{Union{Bool, Nothing}, Union{String, Nothing}}
    try
        test_query = "51.5074, -0.1278"
        response = await(geocode_async(geocoder, test_query; limit=1, no_annotations=true))
        if !ismissing(response.rate) && !ismissing(response.rate.limit) && response.rate.limit == 2500
            return true, nothing
        else
             return false, nothing
        end
    catch e
        if e isa NotAuthorizedError || e isa ForbiddenError
            return nothing, "API key is invalid or blocked: $(e.msg)"
        elseif e isa OpenCageError
             return nothing, "API test request failed: $(e.msg)"
        else
             return nothing, "Unexpected error during API test request: $e"
        end
    end
end

"""
    _parse_input_row(row::CSV.Row, row_id::Int, opts::BatchOptions)::Tuple{Union{String, Nothing}, Symbol}

Parse a CSV row and extract the geocoding query or coordinates.

This function processes a row from the input CSV file and extracts the data needed for
geocoding, either as a query string for forward geocoding or coordinates for reverse geocoding.

# Arguments
- `row::CSV.Row`: The CSV row to parse
- `row_id::Int`: The row ID (for logging purposes)
- `opts::BatchOptions`: The batch processing options

# Returns
- `Tuple{Union{String, Nothing}, Symbol}`: A tuple containing:
  - First element: The query string or coordinates string, or `nothing` if the row should be skipped
  - Second element: The command to use (`:forward`, `:reverse`, or `:skip`)

# Implementation Details
- Extracts data from the specified columns or all columns if none specified
- Auto-detects if the data is coordinates (for reverse geocoding) or an address (for forward geocoding)
- Validates the query string and returns appropriate warnings for invalid data
- Returns `nothing, :skip` if the row should be skipped
"""
function _parse_input_row(row, row_id::Int, opts::BatchOptions)::Tuple{Union{String, Nothing}, Symbol}
    row_vec = String.(collect(row))
    query_parts = String[]
    command = opts.command

    try
        if !isnothing(opts.input_columns)
            query_parts = [strip(row_vec[idx]) for idx in opts.input_columns]
        else
            query_parts = strip.(row_vec)
        end
    catch e
        if e isa BoundsError
            @warn "L$row_id: Missing input column index in row: $row_vec. Skipping."
            return nothing, :skip
        else
            rethrow()
        end
    end

    if isnothing(command)
        if !isnothing(opts.input_columns) && length(opts.input_columns) == 2
            lat_str = query_parts[1]
            lon_str = query_parts[2]
            if tryparse(Float64, lat_str) !== nothing && tryparse(Float64, lon_str) !== nothing
                command = :reverse
            else
                command = :forward
            end
        else
            command = :forward
        end
    end

    if all(isempty, query_parts)
        @warn "L$row_id: Skipping row - no query data found in selected columns."
        return nothing, command
    end

    query_str = ""
    if command == :reverse
        if length(query_parts) == 2
            try
                query_str = _format_reverse_query(query_parts[1], query_parts[2])
            catch e
                if e isa InvalidInputError
                    @warn "L$row_id: $(e.msg). Skipping row."
                    return nothing, command
                else rethrow() end
            end
        else
            @warn "L$row_id: Expected 2 columns/parts for reverse geocoding, found $(length(query_parts)). Skipping row."
            return nothing, command
        end
    else
        query_str = join(filter(!isempty, query_parts), ", ")
    end

    if isempty(strip(query_str)) || length(strip(query_str)) < 2
        @warn "L$row_id: Query '$query_str' is too short (< 2 chars) or empty. Skipping row."
        return nothing, command
    end

    return query_str, command
end

"""
    _batch_reader(
        input_stream::IO,
        input_channel::Channel{Job},
        opts::BatchOptions,
        total_items::Ref{Union{Int, Nothing}},
        prog::Union{Progress, Nothing})

Read rows from the input CSV file and send jobs to the worker tasks.

This function reads the input CSV file row by row, parses each row using `_parse_input_row`,
and sends valid jobs to the worker tasks through the input channel.

# Arguments
- `input_stream::IO`: The input CSV stream to read from
- `input_channel::Channel{Job}`: The channel to send jobs to
- `opts::BatchOptions`: The batch processing options
- `total_items::Ref{Union{Int, Nothing}}`: Reference to store the total number of items
- `prog::Union{Progress, Nothing}`: Progress bar (if enabled)

# Implementation Details
- Attempts to count total lines for progress reporting
- Processes each row and creates a Job for valid rows
- Updates the progress bar as rows are processed
- Closes the input channel when done
"""
function _batch_reader(
    input_stream::IO,
    input_channel::Channel{Job},
    opts::BatchOptions,
    total_items::Ref{Union{Int, Nothing}},
    prog::Union{Progress, Nothing})

    @debug "Reader task started."
    row_count = 0
    try
        has_header = isnothing(opts.input_columns)
        csv_reader = CSV.Rows(input_stream; reusebuffer=true, header=has_header)

        if input_stream isa IOStream && position(input_stream) == 0
            try
                initial_pos = position(input_stream)
                total_items[] = countlines(input_stream) - (has_header ? 1 : 0)
                seek(input_stream, initial_pos)
                if !isnothing(prog) && !isnothing(total_items[]) && total_items[] >= 0
                    ProgressMeter.update!(prog; total=total_items[])
                else
                    total_items[] = nothing # Count failed or invalid
                end
            catch e
                @warn "Could not estimate total lines for progress bar." exception=(e, catch_backtrace())
                seekstart(input_stream)
                total_items[] = nothing
            end
        else
            total_items[] = nothing
        end

        for (row_id, row) in enumerate(csv_reader)
            row_count = row_id
            if !isnothing(opts.limit) && row_id > opts.limit
                 @info "Reached input row limit ($(opts.limit)). Stopping reader."
                 break
            end

            query_str, command = _parse_input_row(row, row_id, opts)

            if isnothing(query_str) || command == :skip
                continue
            end

            job = Job(row_id, query_str, String.(collect(row)), command)
            await(put!(input_channel, job))

            if !isnothing(prog)
                if !isnothing(total_items[])
                    ProgressMeter.update!(prog, row_id)
                else
                    next!(prog; showvalues = [(:rows_queued, row_id)])
                end
            end
        end

        if isnothing(total_items[])
            total_items[] = row_count
           if !isnothing(prog)
               ProgressMeter.update!(prog; total=row_count, value=row_count, force=true)
           end
       elseif !isnothing(prog) && !isnothing(total_items[]) && total_items[] > 0 && prog.counter < total_items[]
           ProgressMeter.update!(prog, total_items[])
       end

    catch e
        @error "Error in batch reader." exception=(e, catch_backtrace())
    finally
        @debug "Reader task finished. Read $row_count rows. Closing input channel."
        close(input_channel)
    end
end

"""
    _batch_worker(
        geocoder::Geocoder,
        input_channel::Channel{Job},
        output_channel::Channel{BatchResult},
        opts::BatchOptions,
        worker_id::Int)

Process geocoding jobs from the input channel and send results to the output channel.

This function runs as a worker task that receives jobs from the input channel,
performs geocoding operations, and sends the results to the output channel.

# Arguments
- `geocoder::Geocoder`: The geocoder instance to use for requests
- `input_channel::Channel{Job}`: The channel to receive jobs from
- `output_channel::Channel{BatchResult}`: The channel to send results to
- `opts::BatchOptions`: The batch processing options
- `worker_id::Int`: The worker ID (for logging purposes)

# Implementation Details
- Processes jobs one by one from the input channel
- Performs forward or reverse geocoding based on the job command
- Handles errors according to the on_error option
- Uses rate limiting if a semaphore is provided
- Sends results to the output channel
"""
function _batch_worker(
    geocoder::Geocoder,
    input_channel::Channel{Job},
    output_channel::Channel{BatchResult},
    opts::BatchOptions,
    worker_id::Int)

    @debug "Worker $worker_id started."
    params = Dict{Symbol, Any}(:no_annotations => true)
    merge!(params, opts.optional_api_params)
    if !any(s -> occursin(r"results\[", s), opts.add_columns)
        params[:limit] = 1
    end

    worker_geocoder = geocoder

    for job in input_channel
        @debug "Worker $worker_id processing row $(job.row_id)"
        result_data::Union{Result, Exception, Nothing} = nothing
        success = false
        outcome = :processed

        if !isnothing(opts.rate_limit_semaphore)
            acquire(opts.rate_limit_semaphore)
        end

        try
            local response
            if job.command == :reverse
                lat_str, lon_str = split(job.query_or_coords, ',')
                lat = parse(Float64, lat_str)
                lon = parse(Float64, lon_str)
                response = await(reverse_geocode_async(worker_geocoder, lat, lon; params...))
            else
                response = await(geocode_async(worker_geocoder, job.query_or_coords; params...))
            end

            if !isempty(response.results)
                result_data = response.results[1]
                success = true
            else
                msg = "Query successful but returned 0 results."
                result_data = BadResponseError(msg)
                success = false
                @info "L$(job.row_id): $msg Query: '$(job.query_or_coords)'"
            end

        catch e
            success = false
            result_data = e
            if e isa OpenCageError
                if opts.on_error == :fail
                    outcome = :failed
                    @error "L$(job.row_id): Unrecoverable error ($(typeof(e))). Failing batch job." exception=(e, catch_backtrace())
                    throw(e)
                elseif opts.on_error == :skip
                    outcome = :skipped
                    @warn "L$(job.row_id): Skipping row due to error: $(e.msg)"
                else
                    outcome = :processed
                    @warn "L$(job.row_id): Error geocoding '$(job.query_or_coords)': $(e.msg)"
                end
            else
                outcome = :failed
                @error "L$(job.row_id): Unexpected error in worker." exception=(e, catch_backtrace())
                if opts.on_error == :fail
                    throw(e)
                end
            end
        finally
            if !isnothing(opts.rate_limit_semaphore)
                release(opts.rate_limit_semaphore)
            end
        end

        if outcome != :skipped
            batch_result = BatchResult(job.row_id, success, result_data, job.original_data)
            await(put!(output_channel, batch_result))
        end
    end
    @debug "Worker $worker_id finished."
end


function _extract_output_columns(batch_result::BatchResult, opts::BatchOptions)::Vector{String}
    output_row = copy(batch_result.original_data)
    status_msg_val = ""
    if batch_result.success
        status_msg_val = "OK"
    elseif batch_result.data isa BadResponseError && occursin("0 results", batch_result.data.msg)
        status_msg_val = "ZERO_RESULTS"
    elseif batch_result.data isa Exception
        status_msg_val = string(typeof(batch_result.data))
    else
        status_msg_val = "UNKNOWN_ERROR" # Should not happen if result_data always holds Result or Exception
    end

    for col_name in opts.add_columns
        value_str = ""
        if col_name == "status_message"
            value_str = status_msg_val
        elseif batch_result.success && batch_result.data isa Result
            result = batch_result.data
            if col_name == "raw_json"
                value_str = JSON3.write(result)
            else
                value = deep_get(result, col_name, "")
                value_str = ismissing(value) ? "" : string(value)
            end
        end
        push!(output_row, value_str)
    end
    return output_row
end

function _batch_writer(
    output_stream::IO,
    output_channel::Channel{BatchResult},
    opts::BatchOptions,
    output_headers::Ref{Union{Vector{String}, Nothing}},
    prog::Union{Progress, Nothing})

    @debug "Writer task started."
    writer = nothing
    buffer = Dict{Int, BatchResult}()
    next_row_to_write = 1
    rows_written = 0
    header_written = false
    first_result_received = false

    try
        for batch_result in output_channel
            first_result_received = true
            if !header_written
                num_original_cols = length(batch_result.original_data)
                original_placeholders = ["orig_col_$(i)" for i in 1:num_original_cols]
                output_headers[] = vcat(original_placeholders, opts.add_columns)
                try
                    CSV.println(output_stream, output_headers[])
                    Base.flush(output_stream) # Ensure header is written before creating Writer
                    writer = CSV.Writer(output_stream)
                    header_written = true
                catch e
                    @error "Failed to write header row to output." exception=(e, catch_backtrace())
                    throw(BatchProcessingError("Failed to write output header: $e"))
                end
            end

            if isnothing(writer)
                error("CSV writer not initialized in batch writer.")
            end

            if opts.ordered
                buffer[batch_result.row_id] = batch_result
                while haskey(buffer, next_row_to_write)
                    result_to_write = pop!(buffer, next_row_to_write)
                    output_row = _extract_output_columns(result_to_write, opts)
                    CSV.write(writer, output_row)
                    rows_written += 1
                    next_row_to_write += 1
                    if !isnothing(prog)
                        ProgressMeter.update!(prog, rows_written)
                    end
                end
            else
                output_row = _extract_output_columns(batch_result, opts)
                CSV.write(writer, output_row)
                rows_written += 1
                if !isnothing(prog)
                    ProgressMeter.update!(prog, rows_written)
                end
            end
        end

        if opts.ordered && !isempty(buffer)
            @debug "Writing remaining $(length(buffer)) buffered items."
            for row_id in sort(collect(keys(buffer)))
                result_to_write = buffer[row_id]
                output_row = _extract_output_columns(result_to_write, opts)
                CSV.write(writer, output_row)
                rows_written += 1
                if !isnothing(prog)
                    ProgressMeter.update!(prog, rows_written)
                end
            end
        end

        if !first_result_received && !header_written
            @warn "Batch input was empty or unreadable, output file may be empty."
        end

    catch e
        @error "Error in batch writer." exception=(e, catch_backtrace())
    finally
        if !isnothing(writer)
        end
        @debug "Writer task finished. Wrote $rows_written rows."
    end
end