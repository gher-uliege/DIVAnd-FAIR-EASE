
@testset "World Ocean Database query" begin
    datasource = "World Ocean Database"

    query = DIVAndFairEase.prepare_query_new(datasource, parameter1, parameter2, datestart, dateend, 
            mindepth, maxdepth, minlon, maxlon, minlat, maxlat)

    jsondata = JSON3.read(query)

    @test length(keys(jsondata)) == 3
    @test length(jsondata["output"]) == 1
    @test jsondata["output"]["format"] == "netcdf"

    @test jsondata["filters"][1]["for_query_parameter"] == "TIME"
    @test jsondata["filters"][1]["min"] == 80353
    @test jsondata["filters"][1]["max"] == 80718

    @test jsondata["filters"][2]["for_query_parameter"] == "DEPTH"
    @test jsondata["filters"][2]["min"] == mindepth 
    @test jsondata["filters"][2]["max"] == maxdepth 

    @test jsondata["filters"][3]["for_query_parameter"] == "LONGITUDE"
    @test jsondata["filters"][3]["min"] == minlon
    @test jsondata["filters"][3]["max"] == maxlon
    
    @test jsondata["query_parameters"][1]["column_name"] == parameter1
    @test jsondata["query_parameters"][1]["alias"] == parameter1
    @test jsondata["query_parameters"][5]["column_name"] == "lat"
    @test jsondata["query_parameters"][5]["alias"] == "LATITUDE"

end