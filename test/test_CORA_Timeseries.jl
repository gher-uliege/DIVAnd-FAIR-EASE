@testset "CORA time series" begin
    datasource = "CORA Timeseries"
    parameter1 = "TEMP"

    query = DIVAndFairEase.prepare_query(
        datasource,
        parameter1,
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

    @test jsondata["filters"][2]["for_query_parameter"] == "DEPTH"
    @test jsondata["filters"][2]["min"] == mindepth
    @test jsondata["filters"][2]["max"] == maxdepth

    @test jsondata["filters"][3]["for_query_parameter"] == "LONGITUDE"
    @test jsondata["filters"][3]["min"] == minlon
    @test jsondata["filters"][3]["max"] == maxlon

    @test jsondata["query_parameters"][1]["column_name"] == parameter1
    @test jsondata["query_parameters"][1]["alias"] == parameter1
    @test jsondata["query_parameters"][5]["column_name"] == "LATITUDE"
    @test jsondata["query_parameters"][5]["alias"] == "LATITUDE"

end

@testset "CORA time series download" begin
    datasource = "CORA Timeseries"
    parameter1 = "TEMP"

    query = DIVAndFairEase.prepare_query(
        datasource,
        parameter1,
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

    # No data found in this case
    NCDataset(outputfile) do nc
        @test length(nc[parameter1][:]) == 0
        #     @test sort(nc[parameter1][:])[10] == 10.319f0
        #     @test sort(nc["TIME"][:])[end] == DateTime(1990, 11, 12, 0, 12, 1)
        #     @test sort(nc["LONGITUDE"][:])[1] == 13.3494
        #     @test sort(nc["dataset_id"][:])[5] == 19931
    end
end
