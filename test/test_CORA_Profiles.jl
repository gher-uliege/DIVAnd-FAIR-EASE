

@testset "CORA Profile query" begin
    datasource = "CORA Profile"
    parameter1 = "TEMP_ADJUSTED"
    parameter1QF = "TEMP_QC"
    datestart = Dates.Date(2010, 1, 1)
    dateend = Dates.Date(2012, 1, 1)

    query = DIVAndFairEase.prepare_query(
        datasource,
        parameter1,
        parameter1QF,
        datestart,
        dateend,
        mindepth,
        maxdepth,
        minlon,
        maxlon,
        minlat,
        maxlat,
    )

    jsondata = JSON3.read(query)

    @test length(keys(jsondata)) == 3
    @test length(jsondata["output"]) == 1
    @test jsondata["output"]["format"] == "netcdf"

    @test jsondata["filters"][1]["for_query_parameter"] == "datetime"
    @test jsondata["filters"][1]["min"] == Dates.format(datestart, "yyyy-mm-ddT00:00:00")
    @test jsondata["filters"][1]["max"] == Dates.format(dateend, "yyyy-mm-ddT00:00:00")

    @test jsondata["filters"][2]["for_query_parameter"] == "depth"
    @test jsondata["filters"][2]["min"] == mindepth
    @test jsondata["filters"][2]["max"] == maxdepth

    @test jsondata["filters"][3]["for_query_parameter"] == "longitude"
    @test jsondata["filters"][3]["min"] == minlon
    @test jsondata["filters"][3]["max"] == maxlon

    @test jsondata["query_parameters"][1]["column_name"] == parameter1
    @test jsondata["query_parameters"][1]["alias"] == "sea_water_temperature"
    @test jsondata["query_parameters"][5]["column_name"] == "LONGITUDE"
    @test jsondata["query_parameters"][5]["alias"] == "longitude"

end

@testset "CORA profile download" begin
    datasource = "CORA Profile"
    parameter1 = "TEMP"
    parameter1QF = "TEMP_QC"

    datestart = Dates.Date(2010, 1, 1)
    dateend = Dates.Date(2012, 1, 1)
    minlon = -40
    maxlon = -30
    minlat = 40
    maxlat = 50

    query = DIVAndFairEase.prepare_query(
        datasource,
        parameter1,
        parameter1QF,
        datestart,
        dateend,
        mindepth,
        maxdepth,
        minlon,
        maxlon,
        minlat,
        maxlat,
    )

    outputfile = tempname() * ".nc"

    @time open(outputfile, "w") do io
        r = HTTP.request(
            "POST",
            joinpath(beacon_services[datasource], "api/query"),
            ["Content-type" => "application/json", "Authorization" => "Bearer $(APItoken)"],
            query,
            response_stream = io,
        )
        @test r.status == 200
    end

    NCDataset(outputfile) do nc
        @test length(nc["sea_water_temperature"][:]) == 10653
        @test sort(nc["sea_water_temperature"][:])[3] == 5.6720004f0
        @test sort(nc["datetime"][:])[end] == DateTime("2011-10-30T20:24:00")
        @test sort(nc["longitude"][:])[1] == -39.885
        # @test sort(nc["dataset_id"][:])[5] == 78002 # → removed variable?
    end
end

