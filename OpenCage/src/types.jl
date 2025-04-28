using Base: @kwdef

struct RateInfo
    limit::Union{Int, Missing}
    remaining::Union{Int, Missing}
    reset::Union{Int, Missing}
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
    ISO_3166_1_alpha_2::Union{String, Missing}
    ISO_3166_1_alpha_3::Union{String, Missing}
    ISO_3166_2::Union{Vector{String}, Missing}
    _category::Union{String, Missing}
    _normalized_city::Union{String, Missing}
    _type::Union{String, Missing}
    city::Union{String, Missing}
    city_district::Union{String, Missing}
    continent::Union{String, Missing}
    country::Union{String, Missing}
    country_code::Union{String, Missing}
    county::Union{String, Missing}
    hamlet::Union{String, Missing}
    house_number::Union{String, Missing}
    municipality::Union{String, Missing}
    neighbourhood::Union{String, Missing}
    postcode::Union{String, Missing}
    region::Union{String, Missing}
    road::Union{String, Missing}
    road_type::Union{String, Missing}
    state::Union{String, Missing}
    state_code::Union{String, Missing}
    state_district::Union{String, Missing}
    suburb::Union{String, Missing}
    village::Union{String, Missing}
    town::Union{String, Missing}
end

struct AnnotationsDMS
    lat::Union{String, Missing}
    lng::Union{String, Missing}
end

struct AnnotationsCurrency
    alternate_symbols::Union{Vector{String}, Missing}
    decimal_mark::Union{String, Missing}
    disambiguate_symbol::Union{String, Missing}
    format::Union{String, Missing}
    html_entity::Union{String, Missing}
    iso_code::Union{String, Missing}
    iso_numeric::Union{String, Missing}
    name::Union{String, Missing}
    smallest_denomination::Union{Int, Missing}
    subunit::Union{String, Missing}
    subunit_to_unit::Union{Int, Missing}
    symbol::Union{String, Missing}
    symbol_first::Union{Int, Missing}
    thousands_separator::Union{String, Missing}
end

struct AnnotationsFIPS
    county::Union{String, Missing}
    state::Union{String, Missing}
end

struct AnnotationsMercator
    x::Union{Float64, Missing}
    y::Union{Float64, Missing}
end

struct AnnotationsNUTSLevel
    code::Union{String, Missing}
end

struct AnnotationsNUTS
    NUTS0::Union{AnnotationsNUTSLevel, Missing}
    NUTS1::Union{AnnotationsNUTSLevel, Missing}
    NUTS2::Union{AnnotationsNUTSLevel, Missing}
    NUTS3::Union{AnnotationsNUTSLevel, Missing}
end

struct AnnotationsOSM
    edit_url::Union{String, Missing}
    note_url::Union{String, Missing}
    url::Union{String, Missing}
end

struct AnnotationsRoadInfo
    drive_on::Union{String, Missing}
    road::Union{String, Missing}
    road_reference::Union{String, Missing}
    road_reference_intl::Union{String, Missing}
    road_type::Union{String, Missing}
    speed_in::Union{String, Missing}
    lanes::Union{Int, Missing}
    maxheight::Union{Float64, String, Missing}
    maxspeed::Union{Int, Missing}
    maxweight::Union{Float64, Missing}
    maxwidth::Union{Float64, Missing}
    oneway::Union{String, Missing}
    surface::Union{String, Missing}
    toll::Union{String, Missing}
    toll_details::Union{Dict{String, Any}, Missing}
    width::Union{Float64, Missing}
end

struct AnnotationsSunTime
    apparent::Union{Int, Missing}
    astronomical::Union{Int, Missing}
    civil::Union{Int, Missing}
    nautical::Union{Int, Missing}
end

struct AnnotationsSun
    rise::Union{AnnotationsSunTime, Missing}
    set::Union{AnnotationsSunTime, Missing}
end

struct AnnotationsTimezone
    name::Union{String, Missing}
    now_in_dst::Union{Int, Missing}
    offset_sec::Union{Int, Missing}
    offset_string::Union{String, Missing}
    short_name::Union{String, Missing}
end

struct AnnotationsUNLOCODEFunction
    meaning::Union{Vector{String}, Missing}
    raw::Union{String, Missing}
end

struct AnnotationsUNLOCODE
    code::Union{String, Missing}
    date::Union{String, Missing}
    func::Union{AnnotationsUNLOCODEFunction, Missing}
    lat::Union{Float64, Missing}
    lng::Union{Float64, Missing}
    name::Union{String, Missing}
    name_wo_diacritics::Union{String, Missing}
end

struct AnnotationsUNM49
    regions::Union{Dict{String, String}, Missing}
    statistical_groupings::Union{Vector{String}, Missing}
end

struct AnnotationsWhat3Words
    words::Union{String, Missing}
end

struct Annotations
    callingcode::Union{Int, Missing}
    currency::Union{AnnotationsCurrency, Missing}
    DMS::Union{AnnotationsDMS, Missing}
    FIPS::Union{AnnotationsFIPS, Missing}
    flag::Union{String, Missing}
    geohash::Union{String, Missing}
    Maidenhead::Union{String, Missing}
    Mercator::Union{AnnotationsMercator, Missing}
    MGRS::Union{String, Missing}
    NUTS::Union{AnnotationsNUTS, Missing}
    OSM::Union{AnnotationsOSM, Missing}
    qibla::Union{Float64, Missing}
    roadinfo::Union{AnnotationsRoadInfo, Missing}
    sun::Union{AnnotationsSun, Missing}
    timezone::Union{AnnotationsTimezone, Missing}
    UN_M49::Union{AnnotationsUNM49, Missing}
    UNLOCODE::Union{AnnotationsUNLOCODE, Missing}
    what3words::Union{AnnotationsWhat3Words, Missing}
    wikidata::Union{String, Missing}
end

struct Result
    annotations::Union{Annotations, Missing, Nothing}
    bounds::Union{Bounds, Missing, Nothing}
    components::Union{Components, Missing, Nothing}
    confidence::Union{Int, Missing}
    distance_from_q::Union{Dict{String, Int}, Missing, Nothing}
    formatted::Union{String, Missing}
    geometry::Union{Geometry, Missing}
end

struct Response
    documentation::String
    licenses::Vector{Dict{String, String}}
    rate::Union{RateInfo, Missing}
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