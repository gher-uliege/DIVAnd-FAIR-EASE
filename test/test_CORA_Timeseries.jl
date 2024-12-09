@testset "CORA time series download" begin
    datasource = "CORA Timeseries"

    query = DIVAndFairEase.prepare_query_new(datasource, parameter1, parameter2, Dates.Date(datestart), Dates.Date(dateend), mindepth,maxdepth, minlon, maxlon, minlat, maxlat)

    outputfile = tempname() * ".nc"

    @info(query);
    @info(outputfile);

    #@time open(outputfile, "w") do io
    endpoint = "https://beacon-cora-ts.maris.nl/api/query"
    
    r = HTTP.request("POST", endpoint, 
        ["Content-type"=> "application/json",
        "Authorization" => "Bearer $(APItoken)"
        ],
        query);
    @test r.status == 200
    # end

    # NCDataset(outputfile) do nc
    #     @test length(nc["TEMP"][:]) == 50
    #     @test sort(nc["TEMP"][:])[10] == 10.319f0
    #     @test sort(nc["TIME"][:])[end] == DateTime(1990, 11, 12, 0, 12, 1)
    #     @test sort(nc["LONGITUDE"][:])[1] == 13.3494
    #     @test sort(nc["dataset_id"][:])[5] == 19931
    # end
end