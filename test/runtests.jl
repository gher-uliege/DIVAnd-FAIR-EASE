using Test
using Dates
using JSON3
using OrderedCollections
using NCDatasets
using HTTP

include("../src/DIVAndFairEase.jl")
APItoken = ENV["beaconAPItoken"];

# Define period of interest and domain
domain = [12.1, 17.85, 43.12, 45.95]
datestart = Dates.Date(2010, 1, 1)
dateend = Dates.Date(2011, 1, 1)

minlon = domain[1]
maxlon = domain[2]
minlat = domain[3]
maxlat = domain[4]
mindepth = 10.0 #Minimum water depth
maxdepth = 400.0

const beacon_services = OrderedDict(
    "Euro-Argo" => "https://beacon-argo.maris.nl",
    "CORA Profile" => "https://beacon-cora-pr.maris.nl",
    "CORA Timeseries" => "https://beacon-cora-ts.maris.nl",
    "EMODnet Chemistry" => "https://beacon-emod-chem.maris.nl",
    "World Ocean Database" => "https://beacon-wod.maris.nl",
    "SeaDataNet CDI TS" => "https://beacon-cdi.maris.nl",
    "CMEMS BGC" => "https://beacon-cmems.maris.nl",
);

parameter1 = "TEMP"

# include("./test_CORA_Timeseries.jl")
# include("./test_CORA_Profiles.jl")
include("./test_WOD.jl")
include("./test_SDN.jl")
# include("./test_EuroArgo.jl")
# include("./test_parquet.jl")