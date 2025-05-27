
@testset "SeaDataNet CDI TS" begin
    datasource = "SeaDataNet CDI TS"
    parameter1 = "ITS-90 water temperature"
    parameter1 = "TEMPPR01"

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
    @test jsondata["query_parameters"][5]["column_name"] == "LONGITUDE"
    @test jsondata["query_parameters"][5]["alias"] == "LONGITUDE"

end


@testset "SDN download" begin
    datasource = "SeaDataNet CDI TS"
    parameter1 = "ITS-90 water temperature"
    parameter1 = "TEMPPR01"
    
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

    NCDataset(outputfile) do nc
        @test length(nc[parameter1][:]) == 9089
        @test parse(Float64, sort(nc[parameter1][:])[3]) == 10.01
        @test sort(nc["datetime"][:])[end] == DateTime("2010-12-15T22:06:00")
        @test sort(nc["LONGITUDE"][:])[1] == 12.582
        # @test sort(nc["dataset_id"][:])[5] == 1484490
    end
end
