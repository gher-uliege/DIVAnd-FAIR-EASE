using STAC
using HTTP
using JSON
using JSON3
using Dates
using NCDatasets

stacendpoint = "https://catalogue.dataspace.copernicus.eu/stac/"

catalog = STAC.Catalog(stacendpoint)

# Catalog assets is empty
@show catalog.assets

# Catalog data contains some URLs
@show catalog.data["links"]


# Get the data from the search
resp = HTTP.request("GET", "https://catalogue.dataspace.copernicus.eu/stac/search")
data = JSON3.read(resp.body)

nfeatures = length(data["features"])
@info("Found $(nfeatures) features")

resp2 = HTTP.request("GET", "https://catalogue.dataspace.copernicus.eu/stac/collections")
collections = JSON3.read(resp2.body)

nfeatures2 = length(collections["collections"])
@info("Found $(nfeatures2) collections")

collections["collections"][1]["links"][end]["href"]

thecollection = nothing
for item in collections["collections"]
    @info(item["title"])
    if item["title"] == "SENTINEL-1"
        thecollection = item 
    end
end

thecollection["links"]


ccc = STAC.FeatureCollection(stacendpoint, Dict())