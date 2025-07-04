@testset "Euro-Argo query" begin
    datasource = "Euro-Argo"
    parameter1 = "PSAL"
    parameter1QF = "PSAL_QC"
    
    dateref = Dates.Date(1950, 1, 1)

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

    @test jsondata["query_parameters"][6]["column_name"] == "LATITUDE"
    @test jsondata["query_parameters"][6]["alias"] == "latitude"

end 

@testset "Euro-Argo download" begin
    datasource = "Euro-Argo"
    parameter1 = "PSAL"
    parameter1QF = "PSAL_QC"

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
        maxlat;
        varname = "sea_water_salinity"
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
        @test length(nc["sea_water_salinity"][:]) == 87
        @test sort(nc["sea_water_salinity"][:])[3] == 38.247f0
        @test sort(nc["datetime"][:])[end] == DateTime("2010-03-30T11:32:44")
        @test sort(nc["longitude"][:])[1] == 15.39
        # @test sort(nc["dataset_id"][:])[5] == 2288342 # → variable no present anymore
    end
end
