module ArgoFairEase

using HTTP
using JSON3
using GeoJSON
using Colors
using Contour
using Dates
using NCDatasets
using OrderedCollections
using NaNStatistics
using PyPlot
const plt = PyPlot
using PyCall
mpl = pyimport("matplotlib")


"""
    prepare_query(parameter, unit, datestart, dateend, mindepth, maxdept, minlon, maxlon, minlat, maxlat)

Prepare the JSON query that will be passed to the API, based on the data, depth and coordinate ranges.
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
    prepare_query(parameter, unit, datestart, dateend, mindepth, maxdepth, regionpoly)

Prepare the JSON query that will be passed to the API, based on the date and depth ranges, and the 
coordinate polygon.
"""
function prepare_query(parameter::String, unit::String, datestart::Date, dateend::Date, 
        mindepth::Float64, maxdepth::Float64, regionpoly::Vector{Any};
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
        OrderedDict("longitude_query_parameter" => Dict("alias"=> "LONGITUDE"), 
                    "latitude_query_parameter" => Dict("alias"=> "LATITUDE"),
                    "geometry" => Dict("coordinates" => regionpoly, "type" => "Polygon")
                    )
    ],
    "output" => Dict("format"=> "netcdf")
    )

    body = JSON3.write(paramdict)
    return body::String
end


"""
    read_netcdf(datafile)

Read the netCDF containing the observations and obtained with the API
"""
function read_netcdf(datafile::AbstractString, varname::AbstractString)
    NCDataset(datafile, "r") do df
        lon = df["LONGITUDE"][:] 
        lat = df["LATITUDE"][:] 
        depth = df["DEPTH"][:]
        time = df["TEMPORAL"][:]
        field = df[varname][:];
        return lon::Vector{Float64}, lat::Vector{Float64}, depth::Vector{Float64}, 
            time::Vector{Dates.DateTime}, field::Vector{Float64}
    end
end

"""
    get_results(outputfile)

Read the results obtained with DIVAnd
"""
function get_results(outputfile::AbstractString, parameter::AbstractString)
    NCDataset(outputfile, "r") do ds
        lon = ds["lon"][:]
        lat = ds["lat"][:]
        depth = ds["depth"][:]
        time = ds["time"][:]
        field = coalesce.(ds[parameter][:,:,:,:], NaN)
        
        return lon::Vector{Float64}, lat::Vector{Float64}, depth::Vector{Float64}, 				   
        time::Vector{DateTime}, field::Array{AbstractFloat, 4}
    end
end

"""
    field2json(lonr, latr, field2D, thelevels)

Convert the 2D array `field2D` to a JSON string.

# Example
```julia-repl
julia> field2json(lonr, latr, field[:,:,1,2], 5.:0.25:12.5)
```
"""
function field2json(lonr, latr, field2D, thelevels; valex=-999.)
    
    # Replace NaN's by exclusion valueµ
    field2D[isnan.(field2D)] .= valex

    # Compute the contours from the results
    contoursfield = Contour.contours(lonr, latr, field2D, thelevels)
    
    # Create the geoJSON starting from a dictionary
    geojsonfield = Dict(
    "type" => "FeatureCollection",
    "features" => [
        Dict(
            "type" => "Feature",
            "geometry" => Dict(
                "type" => "MultiPolygon",
                "coordinates" => [[[[lon, lat] for (lon, lat) in zip(coordinates(line)[1], coordinates(line)[2])] for line in lines(cl)]]),
            "properties" => Dict("field" => cl.level)
        ) for cl in levels(contoursfield)]
    )
    
    return JSON3.write(geojsonfield)
end

"""
    write_field_json(field2D, Δvar; cmap=cmap, resfile, funfile)

Prepare a geoJSON file containing the contour of `field2D` and a file containing the
color function in Javascript.
"""
function write_field_json(lon, lat, field2D::Matrix{AbstractFloat}, Δvar::Float64; cmap=plt.cm.RdYlBu_r,
                         resfile::AbstractString="./field.js", funfile::AbstractString="./colorfunction.js")

    vmin = nanminimum(field2D)
    vmax = nanmaximum(field2D)
    @info("vmin = $vmin, vmax = $vmax")
    values = collect(floor(vmin / Δvar ) * Δvar : Δvar : floor(vmax / Δvar ) * Δvar)
    norm = mpl.colors.Normalize(vmin=values[1], vmax=vmax[end])

    fieldjson = field2json(lon, lat, field2D, values)

    # Write the contours in the geoJSON file
    open(resfile, "w") do df
        write(df, "var field = ")
        write(df, fieldjson)
    end
    
    # Prepare the color function
    colorlistrgb = cmap.(norm.(values))
    colorlisthex = [hex(RGB(thecolor[1], thecolor[2], thecolor[3])) for thecolor in colorlistrgb];
    
    # Write the color function (Javascript)
    open(funfile, "w") do df
        write(df, "function getMoreColor(d) {")
        write(df, "return ")
        for (vv, cc) in zip(values[1:end-1], colorlisthex[1:end-1])
           write(df, "d < $(vv) ? '#$(cc)' :")
        end
        write(df, "'#$(colorlisthex[end])'; ")
        write(df, "}")
    end
                
    return nothing
    
end


"""
    read_polygon_json(contourfile)

Read the coordinates as a list of tuples stored in the geoJSON file `contourfile`,
as downloaded from https://geojson.io

# Example
```julia-repl
julia> coordlist = read_polygon_json(contourfile)
```
"""
function read_polygon_json(contourfile::AbstractString)
    coordlist = []
    jsonbytes = read(contourfile);
    fc = GeoJSON.read(jsonbytes)
    for poly in fc
        coordinates = poly.geometry[1]
        push!(coordlist, coordinates)
    end
    return coordlist
end


end