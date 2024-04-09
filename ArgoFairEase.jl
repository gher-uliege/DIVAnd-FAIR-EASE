module ArgoFairEase

using HTTP
using JSON
using JSON3
using Dates
using NCDatasets
using OrderedCollections

"""
    prepare_query(parameter, unit, datestart, dateend, mindepth, maxdept, minlon, maxlon, minlat, maxlat)

Prepare the JSON query that will be passed to the API.
"""
function prepare_query(parameter::String, unit::String, datestart::Date, dateend::Date, 
        mindepth::Float64, maxdepth::Float64, minlon::Float64, maxlon::Float64, minlat::Float64, maxlat::Float64;
        dateref::Date=Dates.Date(1950, 1, 1)
        )

    mintemporal = (datestart - dateref).value
    maxtemporal = (dateend - dateref).value

    
    # Start with an ordered dictionary, then convert to JSON
    paramdict = OrderedDict(
    "query_parameters" => [
    OrderedDict("data_parameter" => parameter,
        "unit"=> unit,
        "skip_fill_values" => true,
        "alias"=> "sea_water_temperature"),
    OrderedDict("data_parameter"=> "time",
        "unit"=> "days since 1950-01-01 00:00:00 UTC",
        "skip_fill_values"=> false,
        "alias"=> "TEMPORAL"),
    OrderedDict("data_parameter"=> "sea_water_pressure",
        "unit"=> "decibar",
        "include_original_data"=> false,
        "alias"=> "DEPTH"),
    OrderedDict("data_parameter"=> "longitude",
        "unit"=> "degree_east",
        "skip_fill_values"=> false,
        "alias"=> "LONGITUDE"),
    OrderedDict("data_parameter"=> "latitude",
        "unit"=> "degree_north",
        "skip_fill_values"=> false,
        "alias"=> "LATITUDE")],
    "filters"=> [
        OrderedDict("for_query_parameter" => Dict("alias"=> "TEMPORAL"), "min"=> mintemporal, "max"=> maxtemporal),
        OrderedDict("for_query_parameter" => Dict("alias"=> "DEPTH"), "min"=> mindepth, "max"=> maxdepth),
        OrderedDict("for_query_parameter" => Dict("alias"=> "LONGITUDE"), "min"=> minlon, "max"=> maxlon),
        OrderedDict("for_query_parameter" => Dict("alias"=> "LATITUDE"), "min"=> minlat, "max"=> maxlat)
    ],
    "output" => Dict("format"=> "netcdf")
    )

    body = JSON3.write(paramdict)
    return body::String
end

"""
    read_netcdf(datafile)

Read the netCDF obtained from the API call.
"""
function read_netcdf(datafile::AbstractString)
    NCDataset(datafile, "r") do df
        lon = df["LONGITUDE"][:] 
        lat = df["LATITUDE"][:] 
        depth = df["DEPTH"][:]
        time = df["TEMPORAL"][:]
        field = df["sea_water_temperature"][:];
        return lon::Vector{Float64}, lat::Vector{Float64}, depth::Vector{Float64}, 
            time::Vector{Dates.DateTime}, field::Vector{Float64}
    end
end

end