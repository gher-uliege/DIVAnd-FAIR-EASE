using Test
using Dates
using JSON3
using OrderedCollections


include("../src/DIVAndFairEase.jl")
APItoken = ENV["beaconAPItoken"];

domain = [12.1, 17.85, 43.12, 45.95]
datestart = Dates.Date(1990, 1, 1)
dateend = Dates.Date(1991, 1, 1)

minlon = domain[1]
maxlon = domain[2]
minlat = domain[3]
maxlat = domain[4]
mindepth = 10. #Minimum water depth
maxdepth = 400. 

const beacon_services = OrderedDict(
    "Euro-Argo" => "https://beacon-argo.maris.nl",
    "CORA Profile" => "databeacon-cora-pr.maris.nl",
    "CORA Timeseries" => "beacon-cora-ts.maris.nl",
    "EMODnet Chemistry" => "databeacon-emod-chem.maris.nl",
    "World Ocean Database" => "beacon-wod.maris.nl",
    "SeaDataNet CDI TS" => "https://beacon-cdi-ts.maris.nl",
    "CMEMS BGC" => "beacon-cmems.maris.nl",
)

parameter1 = "TEMP"
parameter2 = "PSAL"

@testset "World Ocean Database" begin
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

@testset "SeaDataNet CDI TS" begin
    datasource = "SeaDataNet CDI TS"
    parameter1 = "ITS-90 water temperature"

    query = DIVAndFairEase.prepare_query_new(datasource, parameter1, parameter2, datestart, dateend, 
            mindepth, maxdepth, minlon, maxlon, minlat, maxlat)

    jsondata = JSON3.read(query)

    @test length(keys(jsondata)) == 3
    @test length(jsondata["output"]) == 1
    @test jsondata["output"]["format"] == "netcdf"

    @test jsondata["filters"][1]["for_query_parameter"] == "TIME"
    @test jsondata["filters"][1]["min"] == Dates.format(Dates.DateTime(1990, 1, 1), "yyyymmddTHH:MM:SS")
    @test jsondata["filters"][1]["max"] == Dates.format(Dates.DateTime(1991, 1, 1), "yyyymmddTHH:MM:SS")

    @test jsondata["filters"][2]["for_query_parameter"] == "DEPTH"
    @test jsondata["filters"][2]["min"] == mindepth 
    @test jsondata["filters"][2]["max"] == maxdepth 

    @test jsondata["filters"][3]["for_query_parameter"] == "LONGITUDE"
    @test jsondata["filters"][3]["min"] == minlon
    @test jsondata["filters"][3]["max"] == maxlon
    
    @test jsondata["query_parameters"][1]["column_name"] == parameter1
    @test jsondata["query_parameters"][1]["alias"] == parameter1
    @test jsondata["query_parameters"][5]["column_name"] == "Latitude"
    @test jsondata["query_parameters"][5]["alias"] == "LATITUDE"

end

@testset "SeaDataNet CDI TS" begin
    datasource = "SeaDataNet CDI TS"
    parameter1 = "ITS-90 water temperature"

    query = DIVAndFairEase.prepare_query_new(datasource, parameter1, parameter2, datestart, dateend, 
            mindepth, maxdepth, minlon, maxlon, minlat, maxlat)

    jsondata = JSON3.read(query)

    @test length(keys(jsondata)) == 3
    @test length(jsondata["output"]) == 1
    @test jsondata["output"]["format"] == "netcdf"

    @test jsondata["filters"][1]["for_query_parameter"] == "TIME"
    @test jsondata["filters"][1]["min"] == Dates.format(Dates.DateTime(1990, 1, 1), "yyyymmddTHH:MM:SS")
    @test jsondata["filters"][1]["max"] == Dates.format(Dates.DateTime(1991, 1, 1), "yyyymmddTHH:MM:SS")

    @test jsondata["filters"][2]["for_query_parameter"] == "DEPTH"
    @test jsondata["filters"][2]["min"] == mindepth 
    @test jsondata["filters"][2]["max"] == maxdepth 

    @test jsondata["filters"][3]["for_query_parameter"] == "LONGITUDE"
    @test jsondata["filters"][3]["min"] == minlon
    @test jsondata["filters"][3]["max"] == maxlon
    
    @test jsondata["query_parameters"][1]["column_name"] == parameter1
    @test jsondata["query_parameters"][1]["alias"] == parameter1

    @test jsondata["query_parameters"][5]["column_name"] == "Latitude"
    @test jsondata["query_parameters"][5]["alias"] == "LATITUDE"



end