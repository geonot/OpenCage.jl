using JSON3

@testset "Types" begin
    @testset "Basic Types" begin
        # Test RateInfo
        rate_info = OpenCage.RateInfo(2500, 2000, 1609459200)
        @test rate_info.limit == 2500
        @test rate_info.remaining == 2000
        @test rate_info.reset == 1609459200
        
        # Test Status
        status = OpenCage.Status(200, "OK")
        @test status.code == 200
        @test status.message == "OK"
        
        # Test Geometry
        geometry = OpenCage.Geometry(51.5074, -0.1278)
        @test geometry.lat == 51.5074
        @test geometry.lng == -0.1278
        
        # Test Bounds
        northeast = OpenCage.Geometry(51.6, -0.1)
        southwest = OpenCage.Geometry(51.4, -0.2)
        bounds = OpenCage.Bounds(northeast, southwest)
        @test bounds.northeast.lat == 51.6
        @test bounds.northeast.lng == -0.1
        @test bounds.southwest.lat == 51.4
        @test bounds.southwest.lng == -0.2
    end
    
    @testset "Components" begin
        # Test Components with all fields
        components = OpenCage.Components(
            "GB", "GBR", ["GB-LND"], "place", "London", "city",
            "London", "Westminster", "Europe", "United Kingdom",
            "gb", "Greater London", missing, missing, missing,
            missing, "SW1A 0AA", "England", "Downing Street", "street",
            "England", "ENG", missing, missing, missing, missing
        )
        
        @test components.ISO_3166_1_alpha_2 == "GB"
        @test components.ISO_3166_1_alpha_3 == "GBR"
        @test components.ISO_3166_2 == ["GB-LND"]
        @test components._category == "place"
        @test components._normalized_city == "London"
        @test components._type == "city"
        @test components.city == "London"
        @test components.city_district == "Westminster"
        @test components.continent == "Europe"
        @test components.country == "United Kingdom"
        @test components.country_code == "gb"
        @test components.county == "Greater London"
        @test ismissing(components.hamlet)
        @test ismissing(components.house_number)
        @test ismissing(components.municipality)
        @test ismissing(components.neighbourhood)
        @test components.postcode == "SW1A 0AA"
        @test components.region == "England"
        @test components.road == "Downing Street"
        @test components.road_type == "street"
        @test components.state == "England"
        @test components.state_code == "ENG"
        @test ismissing(components.state_district)
        @test ismissing(components.suburb)
        @test ismissing(components.village)
        @test ismissing(components.town)
    end
    
    @testset "Annotations" begin
        # Test DMS
        dms = OpenCage.AnnotationsDMS("51° 30' 26.64\" N", "0° 7' 40.08\" W")
        @test dms.lat == "51° 30' 26.64\" N"
        @test dms.lng == "0° 7' 40.08\" W"
        
        # Test Currency
        currency = OpenCage.AnnotationsCurrency(
            ["£"], ".", "GBP", "£#,###.##", "&#x00A3;", "GBP", "826",
            "British Pound", 1, "penny", 100, "£", 1, ","
        )
        @test currency.alternate_symbols == ["£"]
        @test currency.decimal_mark == "."
        @test currency.disambiguate_symbol == "GBP"
        @test currency.format == "£#,###.##"
        @test currency.html_entity == "&#x00A3;"
        @test currency.iso_code == "GBP"
        @test currency.iso_numeric == "826"
        @test currency.name == "British Pound"
        @test currency.smallest_denomination == 1
        @test currency.subunit == "penny"
        @test currency.subunit_to_unit == 100
        @test currency.symbol == "£"
        @test currency.symbol_first == 1
        @test currency.thousands_separator == ","
        
        # Test Timezone
        timezone = OpenCage.AnnotationsTimezone(
            "Europe/London", 0, 0, "+00:00", "GMT"
        )
        @test timezone.name == "Europe/London"
        @test timezone.now_in_dst == 0
        @test timezone.offset_sec == 0
        @test timezone.offset_string == "+00:00"
        @test timezone.short_name == "GMT"
    end
    
    @testset "Result" begin
        # Create a minimal Result
        geometry = OpenCage.Geometry(51.5074, -0.1278)
        result = OpenCage.Result(
            missing, missing, missing, 10, missing,
            "10 Downing Street, London, SW1A 0AA, United Kingdom",
            geometry
        )
        
        @test ismissing(result.annotations)
        @test ismissing(result.bounds)
        @test ismissing(result.components)
        @test result.confidence == 10
        @test ismissing(result.distance_from_q)
        @test result.formatted == "10 Downing Street, London, SW1A 0AA, United Kingdom"
        @test result.geometry.lat == 51.5074
        @test result.geometry.lng == -0.1278
    end
    
    @testset "Response" begin
        # Create a minimal Response
        geometry = OpenCage.Geometry(51.5074, -0.1278)
        result = OpenCage.Result(
            missing, missing, missing, 10, missing,
            "10 Downing Street, London, SW1A 0AA, United Kingdom",
            geometry
        )
        status = OpenCage.Status(200, "OK")
        rate_info = OpenCage.RateInfo(2500, 2000, 1609459200)
        
        response = OpenCage.Response(
            "https://opencagedata.com/api",
            [Dict("name" => "CC BY-SA 4.0", "url" => "https://creativecommons.org/licenses/by-sa/4.0/")],
            rate_info,
            [result],
            status,
            Dict("blog" => "https://blog.opencagedata.com"),
            "Thanks for using OpenCage",
            Dict("created_unix" => 1609459200, "created_http" => "Thu, 31 Dec 2020 12:00:00 GMT"),
            1
        )
        
        @test response.documentation == "https://opencagedata.com/api"
        @test length(response.licenses) == 1
        @test response.licenses[1]["name"] == "CC BY-SA 4.0"
        @test !ismissing(response.rate)
        @test response.rate.limit == 2500
        @test length(response.results) == 1
        @test response.results[1].formatted == "10 Downing Street, London, SW1A 0AA, United Kingdom"
        @test response.status.code == 200
        @test response.status.message == "OK"
        @test response.stay_informed["blog"] == "https://blog.opencagedata.com"
        @test response.thanks == "Thanks for using OpenCage"
        @test response.timestamp["created_unix"] == 1609459200
        @test response.total_results == 1
    end
    
    @testset "BatchOptions" begin
        # Test default options
        opts = OpenCage.BatchOptions()
        @test opts.workers == 4
        @test opts.retries == 5
        @test opts.timeout == 60.0
        @test isnothing(opts.input_columns)
        @test opts.add_columns == ["formatted", "geometry.lat", "geometry.lng", "confidence", "components._type", "status_message"]
        @test opts.on_error == :log
        @test opts.ordered == false
        @test opts.progress == true
        @test isnothing(opts.limit)
        @test opts.optional_api_params isa Dict{Symbol, Any}
        @test isnothing(opts.rate_limit_semaphore)
        @test isnothing(opts.command)
        
        # Test custom options
        opts = OpenCage.BatchOptions(
            workers=2,
            retries=3,
            timeout=30.0,
            input_columns=[1, 2],
            add_columns=["formatted"],
            on_error=:skip,
            ordered=true,
            progress=false,
            limit=100,
            optional_api_params=Dict(:language => "en"),
            rate_limit_semaphore=Base.Semaphore(1),
            command=:forward
        )
        
        @test opts.workers == 2
        @test opts.retries == 3
        @test opts.timeout == 30.0
        @test opts.input_columns == [1, 2]
        @test opts.add_columns == ["formatted"]
        @test opts.on_error == :skip
        @test opts.ordered == true
        @test opts.progress == false
        @test opts.limit == 100
        @test opts.optional_api_params[:language] == "en"
        @test opts.rate_limit_semaphore isa Base.Semaphore
        @test opts.command == :forward
    end
    
    @testset "Job and BatchResult" begin
        # Test Job
        job = OpenCage.Job(1, "London", ["London", "UK"], :forward)
        @test job.row_id == 1
        @test job.query_or_coords == "London"
        @test job.original_data == ["London", "UK"]
        @test job.command == :forward
        
        # Test BatchResult with success
        geometry = OpenCage.Geometry(51.5074, -0.1278)
        result = OpenCage.Result(
            missing, missing, missing, 10, missing,
            "London, UK",
            geometry
        )
        
        batch_result = OpenCage.BatchResult(1, true, result, ["London", "UK"])
        @test batch_result.row_id == 1
        @test batch_result.success == true
        @test batch_result.data isa OpenCage.Result
        @test batch_result.data.formatted == "London, UK"
        @test batch_result.original_data == ["London", "UK"]
        
        # Test BatchResult with error
        error = OpenCage.InvalidInputError("Invalid input")
        batch_result = OpenCage.BatchResult(2, false, error, ["Invalid", "Data"])
        @test batch_result.row_id == 2
        @test batch_result.success == false
        @test batch_result.data isa OpenCage.InvalidInputError
        @test batch_result.data.msg == "Invalid input"
        @test batch_result.original_data == ["Invalid", "Data"]
    end
    
    @testset "JSON Parsing" begin
        # Test parsing a simple response
        json_str = """
        {
            "documentation": "https://opencagedata.com/api",
            "licenses": [
                {
                    "name": "CC BY-SA 4.0",
                    "url": "https://creativecommons.org/licenses/by-sa/4.0/"
                }
            ],
            "rate": {
                "limit": 2500,
                "remaining": 2000,
                "reset": 1609459200
            },
            "results": [
                {
                    "formatted": "London, UK",
                    "geometry": {
                        "lat": 51.5074,
                        "lng": -0.1278
                    },
                    "confidence": 10
                }
            ],
            "status": {
                "code": 200,
                "message": "OK"
            },
            "stay_informed": {
                "blog": "https://blog.opencagedata.com"
            },
            "thanks": "Thanks for using OpenCage",
            "timestamp": {
                "created_unix": 1609459200,
                "created_http": "Thu, 31 Dec 2020 12:00:00 GMT"
            },
            "total_results": 1
        }
        """
        
        response = JSON3.read(json_str, OpenCage.Response)
        
        @test response.documentation == "https://opencagedata.com/api"
        @test length(response.licenses) == 1
        @test response.licenses[1]["name"] == "CC BY-SA 4.0"
        @test !ismissing(response.rate)
        @test response.rate.limit == 2500
        @test length(response.results) == 1
        @test response.results[1].formatted == "London, UK"
        @test response.results[1].geometry.lat == 51.5074
        @test response.results[1].geometry.lng == -0.1278
        @test response.results[1].confidence == 10
        @test response.status.code == 200
        @test response.status.message == "OK"
        @test response.stay_informed["blog"] == "https://blog.opencagedata.com"
        @test response.thanks == "Thanks for using OpenCage"
        @test response.timestamp["created_unix"] == 1609459200
        @test response.total_results == 1
    end
end