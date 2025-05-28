using Parquet2
using Tables

datasource = "Euro-Argo"
parameter1 = "TEMP"
dateref = Dates.Date(1950, 1, 1)

query = DIVAndFairEase.prepare_query(
    datasource,
    parameter1,
    datestart,
    dateend,
    mindepth,
    maxdepth,
    minlon,
    maxlon,
    minlat,
    maxlat,
    outputformat="parquet"
)

outputfile = tempname() * ".parquet"

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

@info("Results written in $(outputfile)")

ds = Parquet2.Dataset(outputfile)

obs = Tables.getcolumn(ds, :TEMP)
dates = Tables.getcolumn(ds, :datetime)
# Note: dates (in this case) are expressed as unixtimestamp

lon = Tables.getcolumn(ds, :LONGITUDE)

@test length(obs) ==  87
@test sort(obs)[3] == 12.468f0
@test unix2datetime(sort(dates)[end]) == DateTime("2010-03-30T11:32:44")
@test sort(lon)[1] == 15.39