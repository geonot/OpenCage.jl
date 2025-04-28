using Base: @kwdef

struct RateInfo
    limit::Union{Int, Missing, Nothing}
    remaining::Union{Int, Missing, Nothing}
    reset::Union{Int, Missing, Nothing}
end

struct Status
    code::Int
    message::String
end

struct Geometry
    lat::Float64
    lng::Float64
end

struct Bounds
    northeast::Geometry
    southwest::Geometry
end

struct Components
    ISO_3166_1_alpha_2::Union{String, Missing, Nothing}
    ISO_3166_1_alpha_3::Union{String, Missing, Nothing}
    ISO_3166_2::Union{Vector{String}, Missing, Nothing}
    _category::Union{String, Missing, Nothing}
    _normalized_city::Union{String, Missing, Nothing}
    _type::Union{String, Missing, Nothing}
    city::Union{String, Missing, Nothing}
    city_district::Union{String, Missing, Nothing}
    continent::Union{String, Missing, Nothing}
    country::Union{String, Missing, Nothing}
    country_code::Union{String, Missing, Nothing}
    county::Union{String, Missing, Nothing}
    hamlet::Union{String, Missing, Nothing}
    house_number::Union{String, Missing, Nothing}
    municipality::Union{String, Missing, Nothing}
    neighbourhood::Union{String, Missing, Nothing}
    postcode::Union{String, Missing, Nothing}
    region::Union{String, Missing, Nothing}
    road::Union{String, Missing, Nothing}
    road_type::Union{String, Missing, Nothing}
    state::Union{String, Missing, Nothing}
    state_code::Union{String, Missing, Nothing}
    state_district::Union{String, Missing, Nothing}
    suburb::Union{String, Missing, Nothing}
    village::Union{String, Missing, Nothing}
    town::Union{String, Missing, Nothing}
end

struct AnnotationsDMS
    lat::Union{String, Missing, Nothing}
    lng::Union{String, Missing, Nothing}
end

struct AnnotationsCurrency
    alternate_symbols::Union{Vector{String}, Missing, Nothing}
    decimal_mark::Union{String, Missing, Nothing}
    disambiguate_symbol::Union{String, Missing, Nothing}
    format::Union{String, Missing, Nothing}
    html_entity::Union{String, Missing, Nothing}
    iso_code::Union{String, Missing, Nothing}
    iso_numeric::Union{String, Missing, Nothing}
    name::Union{String, Missing, Nothing}
    smallest_denomination::Union{Int, Missing, Nothing}
    subunit::Union{String, Missing, Nothing}
    subunit_to_unit::Union{Int, Missing, Nothing}
    symbol::Union{String, Missing, Nothing}
    symbol_first::Union{Int, Missing, Nothing}
    thousands_separator::Union{String, Missing, Nothing}
end

struct AnnotationsFIPS
    county::Union{String, Missing, Nothing}
    state::Union{String, Missing, Nothing}
end

struct AnnotationsMercator
    x::Union{Float64, Missing, Nothing}
    y::Union{Float64, Missing, Nothing}
end

struct AnnotationsNUTSLevel
    code::Union{String, Missing, Nothing}
end

struct AnnotationsNUTS
    NUTS0::Union{AnnotationsNUTSLevel, Missing, Nothing}
    NUTS1::Union{AnnotationsNUTSLevel, Missing, Nothing}
    NUTS2::Union{AnnotationsNUTSLevel, Missing, Nothing}
    NUTS3::Union{AnnotationsNUTSLevel, Missing, Nothing}
end

struct AnnotationsOSM
    edit_url::Union{String, Missing, Nothing}
    note_url::Union{String, Missing, Nothing}
    url::Union{String, Missing, Nothing}
end

struct AnnotationsRoadInfo
    drive_on::Union{String, Missing, Nothing}
    road::Union{String, Missing, Nothing}
    road_reference::Union{String, Missing, Nothing}
    road_reference_intl::Union{String, Missing, Nothing}
    road_type::Union{String, Missing, Nothing}
    speed_in::Union{String, Missing, Nothing}
    lanes::Union{Int, Missing, Nothing}
    maxheight::Union{Float64, String, Missing, Nothing}
    maxspeed::Union{Int, Missing, Nothing}
    maxweight::Union{Float64, Missing, Nothing}
    maxwidth::Union{Float64, Missing, Nothing}
    oneway::Union{String, Missing, Nothing}
    surface::Union{String, Missing, Nothing}
    toll::Union{String, Missing, Nothing}
    toll_details::Union{Dict{String, Any}, Missing, Nothing}
    width::Union{Float64, Missing, Nothing}
end

struct AnnotationsSunTime
    apparent::Union{Int, Missing, Nothing}
    astronomical::Union{Int, Missing, Nothing}
    civil::Union{Int, Missing, Nothing}
    nautical::Union{Int, Missing, Nothing}
end

struct AnnotationsSun
    rise::Union{AnnotationsSunTime, Missing, Nothing}
    set::Union{AnnotationsSunTime, Missing, Nothing}
end

struct AnnotationsTimezone
    name::Union{String, Missing, Nothing}
    now_in_dst::Union{Int, Missing, Nothing}
    offset_sec::Union{Int, Missing, Nothing}
    offset_string::Union{String, Missing, Nothing}
    short_name::Union{String, Missing, Nothing}
end

struct AnnotationsUNLOCODEFunction
    meaning::Union{Vector{String}, Missing, Nothing}
    raw::Union{String, Missing, Nothing}
end

struct AnnotationsUNLOCODE
    code::Union{String, Missing, Nothing}
    date::Union{String, Missing, Nothing}
    func::Union{AnnotationsUNLOCODEFunction, Missing, Nothing}
    lat::Union{Float64, Missing, Nothing}
    lng::Union{Float64, Missing, Nothing}
    name::Union{String, Missing, Nothing}
    name_wo_diacritics::Union{String, Missing, Nothing}
end

struct AnnotationsUNM49
    regions::Union{Dict{String, String}, Missing, Nothing}
    statistical_groupings::Union{Vector{String}, Missing, Nothing}
end

struct AnnotationsWhat3Words
    words::Union{String, Missing, Nothing}
end

struct Annotations
    callingcode::Union{Int, Missing, Nothing}
    currency::Union{AnnotationsCurrency, Missing, Nothing}
    DMS::Union{AnnotationsDMS, Missing, Nothing}
    FIPS::Union{AnnotationsFIPS, Missing, Nothing}
    flag::Union{String, Missing, Nothing}
    geohash::Union{String, Missing, Nothing}
    Maidenhead::Union{String, Missing, Nothing}
    Mercator::Union{AnnotationsMercator, Missing, Nothing}
    MGRS::Union{String, Missing, Nothing}
    NUTS::Union{AnnotationsNUTS, Missing, Nothing}
    OSM::Union{AnnotationsOSM, Missing, Nothing}
    qibla::Union{Float64, Missing, Nothing}
    roadinfo::Union{AnnotationsRoadInfo, Missing, Nothing}
    sun::Union{AnnotationsSun, Missing, Nothing}
    timezone::Union{AnnotationsTimezone, Missing, Nothing}
    UN_M49::Union{AnnotationsUNM49, Missing, Nothing}
    UNLOCODE::Union{AnnotationsUNLOCODE, Missing, Nothing}
    what3words::Union{AnnotationsWhat3Words, Missing, Nothing}
    wikidata::Union{String, Missing, Nothing}
end

struct Result
    annotations::Union{Annotations, Missing, Nothing}
    bounds::Union{Bounds, Missing, Nothing}
    components::Union{Components, Missing, Nothing}
    confidence::Union{Int, Missing, Nothing}
    distance_from_q::Union{Dict{String, Int}, Missing, Nothing}
    formatted::Union{String, Missing, Nothing}
    geometry::Union{Geometry, Missing, Nothing}
end

struct Response
    documentation::String
    licenses::Vector{Dict{String, String}}
    rate::Union{RateInfo, Missing, Nothing}
    results::Vector{Result}
    status::Status
    stay_informed::Dict{String, String}
    thanks::String
    timestamp::Dict{String, Union{String, Int}}
    total_results::Int
end

@kwdef struct BatchOptions
    workers::Int = 4
    retries::Int = 5
    timeout::Float64 = 60.0
    input_columns::Union{Vector{Int}, Nothing} = nothing
    add_columns::Vector{String} = ["formatted", "geometry.lat", "geometry.lng", "confidence", "components._type", "status_message"]
    on_error::Symbol = :log
    ordered::Bool = false
    progress::Bool = true
    limit::Union{Int, Nothing} = nothing
    optional_api_params::Dict{Symbol, Any} = Dict{Symbol, Any}()
    rate_limit_semaphore::Union{Base.Semaphore, Nothing} = nothing
    command::Union{Symbol, Nothing} = nothing
end

struct Job
    row_id::Int
    query_or_coords::String
    original_data::Vector{String}
    command::Symbol
end

struct BatchResult
    row_id::Int
    success::Bool
    data::Union{Result, Exception, Nothing}
    original_data::Vector{String}
end