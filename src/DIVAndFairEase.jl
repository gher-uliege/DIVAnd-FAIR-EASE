module DIVAndFairEase

using HTTP
using JSON
using JSON3
using GeoJSON
using Colors
using Contour
using Dates
using NCDatasets
using OrderedCollections
using NaNStatistics


"""
    varbyunits(footprintfile, units)

Return a list of variables (Strings) which have the units specified in the vector `units` from the file `footprintfile`.

# Example
```julia-repl
julia> temperature_variables = varbyunits("Footprint_CMEMS_BGC.json", ["degree_Celsius", "degrees_C"])
8-element Vector{Any}:
 "PHTX"
 "TEMP_DOXY"
 "TEMP_ADJUSTED_ERROR"
 "TEMP_ADJUSTED"
 "POTENTIAL_TEMP"
 "TEMP_ERROR"
 "TEMP"
 "TEMP_CNDC"
```
"""
function varbyunits(footprintfile::String, units::Vector{String})
    # Read the footprintfile
    data = JSON.parsefile(footprintfile);

    varlist = []
    for (key, value) in data["unique_column_attributes"]
        if haskey(value, "units")
            theunits = value["units"][1]
            @debug(theunits)
            if theunits in units
               push!(varlist, key)
            end
        end
    end
    return varlist
end

"""
    prepare_query(datasource, parameter1, datestart, dateend, mindepth, maxdepth, minlon, maxlon, minlat, maxlat)

Prepare the JSON query that will be passed to the API, based on the data, depth and coordinate ranges.
"""
function prepare_query(datasource::AbstractString, parameter1::String, datestart::Date, dateend::Date, 
    mindepth::Union{Int64,Float64}, maxdepth::Union{Int64,Float64}, minlon::Union{Int64,Float64}, maxlon::Union{Int64,Float64}, 
    minlat::Union{Int64,Float64}, maxlat::Union{Int64,Float64}; dateref::Date=Dates.Date(1950, 1, 1)
    )

    # The reference date can change according to the datasource!
    if datasource == "World Ocean Database"
        dateref = Dates.Date(1770, 1, 1)
    elseif datasource == "EMODnet Chemistry" 
        dateref = Dates.Date(1921, 1, 1)
    end

    mintemporal = (datestart - dateref).value
    maxtemporal = (dateend - dateref).value

    if datasource == "World Ocean Database"
        queryparams = [
            OrderedDict("column_name" => parameter1, "alias" => parameter1, "skip_fill_values" => true),
            OrderedDict("column_name" => "$(parameter1).units", "alias" => "Unit"),
            # OrderedDict("column_name" => "cf_datetime", "alias" => "datetime"),
            OrderedDict("column_name" => "time", "alias" => "datetime"),
            OrderedDict("column_name" => "z", "alias" => "DEPTH"),
            OrderedDict("column_name" => "lon", "alias" => "LONGITUDE"),
            OrderedDict("column_name" => "lat", "alias" => "LATITUDE"),
            OrderedDict("column_name" => "dataset", "alias" => "DATASET", "optional" => true),
            OrderedDict("column_name" => "WOD_cruise_identifier", "alias" => "cruise-identifier", "optional" => true),
            OrderedDict("column_name" => "wod_unique_cast", "alias" => "cast", "optional" => true),
            OrderedDict("column_name" => "WMO_ID", "alias" => "WMO_ID", "optional" => true),
            OrderedDict("column_name" => "country", "alias" => "country", "optional" => true)
        ]

    elseif datasource == "SeaDataNet CDI TS"
        queryparams = [
            OrderedDict("column_name" => parameter1, "alias" => parameter1),
            #OrderedDict("column_name" => "$(parameter1)_qc", "alias" => "$(parameter1)_qc"),
            OrderedDict("column_name" => "$(parameter1).units", "alias" => "Unit"),
            #OrderedDict("column_name" => "yyyy-mm-ddThh:mm:ss.sss", "alias" => "datetime"),
            OrderedDict("column_name" => "TIME", "alias" => "datetime"),
            OrderedDict("column_name" => "DEPTH", "alias" => "DEPTH"),
            # OrderedDict("column_name" => "Depth_qc", "alias" => "Depth_qc"), 
            OrderedDict("column_name" => "LONGITUDE", "alias" => "LONGITUDE"),
            OrderedDict("column_name" => "LATITUDE", "alias" => "LATITUDE")
        ]

    elseif occursin("CORA", datasource)
        queryparams = [
            OrderedDict("column_name" => parameter1, "alias" => parameter1, "skip_fill_values" => true),
            # OrderedDict("column_name" => "cf_datetime", "alias" => "datetime"),
            OrderedDict("column_name" => "TIME", "alias" => "datetime"),
            OrderedDict("column_name" => "DEPH", "alias" => "DEPTH"),
            OrderedDict("column_name" => "LONGITUDE", "alias" => "LONGITUDE"),
            OrderedDict("column_name" => "LATITUDE", "alias" => "LATITUDE")
        ]
    elseif occursin("CMEMS", datasource)
        queryparams = [
            OrderedDict("column_name" => parameter1, "alias" => parameter1),
            OrderedDict("column_name" => parameter1, "column_attribute" => "scale_factor", "alias" => "scale_factor"),
            OrderedDict("column_name" => "JULD", "alias" => "TIME"),
            OrderedDict("column_name" => "DEPH", "alias" => "DEPTH"),
            OrderedDict("column_name" => "LONGITUDE", "alias" => "LONGITUDE"),
            OrderedDict("column_name" => "LATITUDE", "alias" => "LATITUDE")
        ]
    elseif datasource == "EMODnet Chemistry"
        queryparams = [
            OrderedDict("column_name" => parameter1, "alias" => parameter1),
            OrderedDict("column_name" => "date_time", "alias" => "TIME"), 
            OrderedDict("column_name" => "Depth", "alias" => "DEPTH"),
            OrderedDict("column_name" => "longitude", "alias" => "LONGITUDE"),
            OrderedDict("column_name" => "latitude", "alias" => "LATITUDE")
        ]
    else
        queryparams = [
            OrderedDict("column_name" => parameter1, "alias" => parameter1, "skip_fill_values" => true),
            OrderedDict("column_name" => "$(parameter1).units", "alias" => "Unit"),
            OrderedDict("column_name" => "cf_datetime", "alias" => "datetime"),
            OrderedDict("column_name" => "PRES", "alias" => "DEPTH"),
            OrderedDict("column_name" => "LONGITUDE", "alias" => "LONGITUDE"),
            OrderedDict("column_name" => "LATITUDE", "alias" => "LATITUDE")
        ]
    end

    # Filters for the coordinates and variables
    if datasource == "SeaDataNet CDI TS"
        filters = [
            OrderedDict("for_query_parameter" =>  "datetime", "min" => Dates.format(datestart, "yyyy-mm-ddT00:00:00"), "max" => Dates.format(dateend, "yyyy-mm-ddT00:00:00"), "cast" => "timestamp"),
            OrderedDict("for_query_parameter" =>  "DEPTH", "min" => mindepth, "max" => maxdepth),
            OrderedDict("for_query_parameter" =>  "LONGITUDE", "min" => minlon, "max" => maxlon), 
            OrderedDict("for_query_parameter" =>  "LATITUDE", "min" => minlat, "max" => maxlat)
        ]
    elseif occursin("CORA", datasource)
        @info("Working with CORA dataset")
        filters = [
            OrderedDict("for_query_parameter" => "datetime", "min" => Dates.format(datestart, "yyyy-mm-ddT00:00:00"), "max" => Dates.format(dateend, "yyyy-mm-ddT00:00:00"), "cast" => "timestamp"),
            OrderedDict("for_query_parameter" => "DEPTH", "min" => mindepth, "max" => maxdepth),
            OrderedDict("for_query_parameter" => "LONGITUDE", "min" => minlon, "max" => maxlon),
            OrderedDict("for_query_parameter" => "LATITUDE", "min" => minlat, "max" => maxlat)
        ]
    else
        filters = [
            OrderedDict("for_query_parameter" => "datetime",
                "min" => Dates.format(DateTime(datestart), "yyyy-mm-dd00:00:00"),
                "max" => Dates.format(DateTime(dateend), "yyyy-mm-ddT00:00:00"),
                "cast" => "timestamp"),
            OrderedDict("for_query_parameter" => "DEPTH", "min" => mindepth, "max" => maxdepth),
            OrderedDict("for_query_parameter" => "LONGITUDE", "min" => minlon, "max" => maxlon),
            OrderedDict("for_query_parameter" => "LATITUDE", "min" => minlat, "max" => maxlat)
        ]
    end

    paramdict = OrderedDict(
        "query_parameters" => queryparams,
        "filters" => filters,
        "output" => Dict("format"=> "netcdf")
    )
    body = JSON3.write(paramdict);
    return body
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
# function write_field_json(lon, lat, field2D::Matrix{AbstractFloat}, Δvar::Float64; cmap=plt.cm.RdYlBu_r,
#                          resfile::AbstractString="./field.js", funfile::AbstractString="./colorfunction.js")

#     vmin = nanminimum(field2D)
#     vmax = nanmaximum(field2D)
#     @info("vmin = $vmin, vmax = $vmax")
#     values = collect(floor(vmin / Δvar ) * Δvar : Δvar : floor(vmax / Δvar ) * Δvar)
#     norm = mpl.colors.Normalize(vmin=values[1], vmax=vmax[end])

#     fieldjson = field2json(lon, lat, field2D, values)

#     # Write the contours in the geoJSON file
#     open(resfile, "w") do df
#         write(df, "var field = ")
#         write(df, fieldjson)
#     end
    
#     # Prepare the color function
#     colorlistrgb = cmap.(norm.(values))
#     colorlisthex = [hex(RGB(thecolor[1], thecolor[2], thecolor[3])) for thecolor in colorlistrgb];
    
#     # Write the color function (Javascript)
#     open(funfile, "w") do df
#         write(df, "function getMoreColor(d) {")
#         write(df, "return ")
#         for (vv, cc) in zip(values[1:end-1], colorlisthex[1:end-1])
#            write(df, "d < $(vv) ? '#$(cc)' :")
#         end
#         write(df, "'#$(colorlisthex[end])'; ")
#         write(df, "}")
#     end
                
#     return nothing
    
# end


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
