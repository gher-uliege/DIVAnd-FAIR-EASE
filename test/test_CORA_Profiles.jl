
@testset "CORA profile download" begin
    datasource = "CORA Profile"

    query = DIVAndFairEase.prepare_query_new(datasource, parameter1, parameter2, datestart, dateend, 
            mindepth, maxdepth, minlon, maxlon, minlat, maxlat)

    outputfile = tempname() * ".nc"

    @time open(outputfile, "w") do io
        r = HTTP.request("POST", joinpath(beacon_services[datasource], "api/query"), 
            ["Content-type"=> "application/json",
             "Authorization" => "Bearer $(APItoken)"
            ],
            query, 
            response_stream=io);
        @test r.status == 200
    end

    NCDataset(outputfile) do nc
        @test length(nc["TEMP"][:]) == 1764
        @test sort(nc["TEMP"][:])[3] == 8.839001f0
        @test sort(nc["TIME"][:])[end] == DateTime("1990-12-19T00:00:00")
        @test sort(nc["LONGITUDE"][:])[1] == 12.347
        @test sort(nc["dataset_id"][:])[5] == 42773
    end
end

@testset "CORA Profile query" begin
    datasource = "CORA Profile"
    dateref = Date(1950, 1, 1)

    query = DIVAndFairEase.prepare_query_new(datasource, parameter1, parameter2, datestart, dateend, 
            mindepth, maxdepth, minlon, maxlon, minlat, maxlat)

    jsondata = JSON3.read(query)

    @test length(keys(jsondata)) == 3
    @test length(jsondata["output"]) == 1
    @test jsondata["output"]["format"] == "netcdf"

    @test jsondata["filters"][1]["for_query_parameter"] == "TIME"
    @test jsondata["filters"][1]["min"] == "1990-01-01T00:00:00"
    @test jsondata["filters"][1]["max"] == "1991-01-01T00:00:00"

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