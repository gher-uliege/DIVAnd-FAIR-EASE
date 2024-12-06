@testset "CORA time series download" begin
    datasource = "CORA Timeseries"

    query = DIVAndFairEase.prepare_query_new(datasource, parameter1, parameter2, datestart, dateend, 
            mindepth, maxdepth, minlon, maxlon, minlat, maxlat)

    query = DIVAndFairEase.prepare_query_new(datasource, parameter1, parameter2, Dates.Date(datestart), Dates.Date(dateend), mindepth,maxdepth, minlon, maxlon, minlat, maxlat)

    outputfile = tempname() * ".nc"

    @time open(outputfile, "w") do io
        r = HTTP.request("POST", joinpath(beacon_services[datasource], "api/query"), 
            ["Content-type"=> "application/json",
            "Authorization" => "Bearer $(APItoken)"
            ],
            query, 
            response_stream=io);
        @info(r.status)
    end

    NCDataset(outputfile) do nc
        @test length(nc["TEMP"][:]) == 50
        @test sort(nc["TEMP"][:])[10] == 10.319f0
        @test sort(nc["TIME"][:])[end] == DateTime(1990, 11, 12, 0, 12, 1)
        @test sort(nc["LONGITUDE"][:])[1] == 13.3494
        @test sort(nc["dataset_id"][:])[5] == 19931
    end
end