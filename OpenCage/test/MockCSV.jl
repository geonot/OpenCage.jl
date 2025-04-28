module MockCSV
    using Mocking
    using CSV

    export MockRow, mock_csv_operations

    struct MockRow
        data::Vector{String}
        names::Vector{Symbol}
    end

    function Base.getindex(row::MockRow, i::Int)
        return row.data[i]
    end
    
    function Base.getindex(row::MockRow, s::Symbol)
        idx = findfirst(==(s), row.names)
        return isnothing(idx) ? nothing : row.data[idx]
    end

    function Base.collect(row::MockRow)
        return row.data
    end

    function Base.length(row::MockRow)
        return length(row.data)
    end

    function Base.iterate(row::MockRow, state=1)
        if state > length(row.data)
            return nothing
        end
        return (row.data[state], state + 1)
    end

    # Create a MockRow that mimics a CSV.Row
    function create_mock_row(data::Vector{String}, names::Vector{Symbol}=Symbol[])
        if isempty(names)
            names = [Symbol("Column$i") for i in 1:length(data)]
        end
        return MockRow(data, names)
    end

    # Mock for CSV.Rows constructor
    function mock_csv_rows(io::IO; kwargs...)
        # Return a simple iterator that yields mock rows
        # This is a placeholder - in real tests, you'd configure this with test data
        return []
    end

    # Patch for CSV.Rows
    const CSV_ROWS_PATCH = @patch CSV.Rows(io::IO; kwargs...) =
        MockCSV.mock_csv_rows(io; kwargs...)

    # Helper function to apply all CSV mocks
    function mock_csv_operations(f::Function)
        apply([CSV_ROWS_PATCH]) do
            f()
        end
    end
end