using Test
using Dates
using JSON3
using OrderedCollections
using NCDatasets
using HTTP

include("../src/DIVAndFairEase.jl")
APItoken = ENV["beaconAPItoken"];

println(APItoken[1:10])

# Define period of interest and domain
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
    "CORA Profile" => "https://beacon-cora-pr.maris.nl",
    "CORA Timeseries" => "https://beacon-cora-ts.maris.nl",
    "EMODnet Chemistry" => "https://beacon-emod-chem.maris.nl",
    "World Ocean Database" => "https://beacon-wod.maris.nl",
    "SeaDataNet CDI TS" => "https://beacon-cdi-ts.maris.nl",
    "CMEMS BGC" => "https://beacon-cmems.maris.nl",
);

parameter1 = "TEMP"
parameter2 = "PSAL"

include("./test_CORA_Timeseries.jl")
include("./test_CORA_Profiles.jl")
include("./test_WOD.jl")
include("./test_SDN.jl")
include("./test_EuroArgo.jl")