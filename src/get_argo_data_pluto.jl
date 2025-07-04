### A Pluto.jl notebook ###
# v0.20.9

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 557eda82-f679-11ee-274e-37137b03fb0f
begin
	using HTTP
	using JSON3
	using Dates
	using NCDatasets
	using Printf
	using OrderedCollections
	using PyPlot
	const plt = PyPlot
	using PyCall
	using Conda
	using Colors
	using PlutoUI
	using Markdown
	using Contour
	using NaNStatistics
	using InteractiveUtils
	using HypertextLiteral
	mpl = pyimport("matplotlib")
	mpl.style.use("./fairease.mplstyle")
end

# ╔═╡ d9954dc8-c243-4a95-ba50-7768db5b6a82
using DIVAnd

# ╔═╡ 8fedd67c-80b5-42bb-8c02-c14d278e4e8c
html"""
<style>
	a {
		color: #c34113;
	}
	a:active {
	  text-decoration: underline;
	}
	p {
	  color: #4D4D4D;
	}
</style>
"""

# ╔═╡ c2f31032-1a7c-4fed-9713-0dd33b02ba37
md"""
# Interpolation of Argo profilers data
In this notebook we download Argo data using the [`Beacon`](https://beacon.maris.nl/) API and then create gridded fields using the [`DIVAnd`](https://github.com/gher-uliege/DIVAnd.jl) software tool. 

!!! info "Reactivity ⚡"

	In Pluto notebooks, all the cells are run directly, then if you modify one cell, all the cells depending on the modified one will be re-run.

## 📦📦 Package installation
1. The packages will be automatically downloaded if needed.
2. They will be installed in the notebook (✓ symbol).
3. Their version and dependencies will be written in the notebook file (not visible in the interface).
"""

# ╔═╡ ba962cb7-46c5-4b6e-8963-d4ab171f8d0a
md"""
!!! tip "Beacon URL"

	If we don't want to show it explicitly, we can store it as an environment variable (other options exist). 

	Otherwise it can be explicity written in the next cell.
"""

# ╔═╡ 4a823c93-6120-4204-ba4d-3b5558fc8e8d
beaconURL = ENV["beaconURL"];

# ╔═╡ e2c7e580-9202-4b4c-a41d-f00aff0f282f
md"""
## 📁 Files and directories
We create separate directories for the data, the results and the plots.
"""

# ╔═╡ be148eac-bbba-4929-a5ca-a7735c9b77a9
begin
	datadir = "../data/"
	outputdir = "../output/"
	figdir = "../figures/"
	mkpath.([datadir, outputdir, figdir]);
end

# ╔═╡ ff528eed-305f-4f2c-bf4b-c79f3ddd0010
md"""
## Options for the plots
Plots can be produced using [`Leaflet`](https://leafletjs.com/) (interactive), [`Cartopy`](https://scitools.org.uk/cartopy/docs/latest/) and/or [`Basemap`](https://basemaptutorial.readthedocs.io/en/latest/).     

The necessary packages will installed accordingly.
"""

# ╔═╡ 31979a73-1b7f-4e84-9a18-ce8fd808d655
@bind plotoptions MultiCheckBox(["Leaflet", "Cartopy", "Basemap"])

# ╔═╡ 2d812c57-40f6-499b-972f-69be172d1365
begin
	useleaflet = "Leaflet" in plotoptions
	usecartopy = "Cartopy" in plotoptions
	usebasemap = "Basemap" in plotoptions;
	@info("Creating plots with $(plotoptions)");
end

# ╔═╡ b20b0a42-2f04-4abc-8b37-278d62a42e32
if usebasemap
	Conda.add("basemap");	
	basemap = pyimport("mpl_toolkits.basemap")
	Basemap = basemap.Basemap
end;

# ╔═╡ 05def578-6786-4713-af46-ac58b334f5c7
if usecartopy
	Conda.add("cartopy");	
	ccrs = pyimport("cartopy.crs")
	cfeature = pyimport("cartopy.feature")
	coast = cfeature.GSHHSFeature(scale="h")
	dataproj = ccrs.PlateCarree();
end;

# ╔═╡ b9c9921b-b41a-480e-b0ac-fca6e652dc22
md"""
### Domain and depth of interest
We create a dictionary with different regions and their bounding box (west, east, south, north).
"""

# ╔═╡ 3de1e314-10a2-4604-9c2d-dda5e95e01b4
domaininfo = Dict("Arctic region" => [-44.25, 70.0, 56.5, 83.0],
				  "North_East_Atlantic" => [-42.0, -0.1, 24.9, 48.0], 
			      "Baltic_Sea" => [9.4, 30.9, 53.0, 65.9],
				  "Black_Sea" => [26.5, 41.95, 40.0, 47.95],
				  "Mediterranean_Sea" => [-7.0, 36.375, 30.0, 45.875],
				  "North_Sea" => [-100., 50., -80., 80.],
				  "Canary_Islands" => [-20., -9., 25., 31.5],
				  #"World_Ocean" => [-180., 180., -90., 90.]
				  );

# ╔═╡ 7d195f6e-5308-40b3-9547-6614e96c006a
@bind regionname Select(collect(keys(domaininfo)), default="Baltic_sea")

# ╔═╡ e7ae81f3-970e-4d3f-936f-3073b1063e5c
md"""
## Select parameters
We create a dictionary with the variable names and their units.
### Variable name
"""

# ╔═╡ e57790e8-35e9-4920-b24b-0b1fe07f42ce
variableunits = Dict("sea_water_temperature" => "degree_Celsius", 
					 "sea_water_salinity" => "psu", 
					 "mass_concentration_of_chlorophyll_a_in_sea_water" => "mg/m3",   
					 "moles_of_nitrate_per_unit_mass_in_sea_water" => "micromole/kg");

# ╔═╡ 9d3aa9d8-ab25-48b3-aede-428c9d960815
@bind parameter Select(["sea_water_temperature",  "sea_water_salinity", 
        "mass_concentration_of_chlorophyll_a_in_sea_water",   	"moles_of_nitrate_per_unit_mass_in_sea_water"])

# ╔═╡ f7510e4d-5814-4511-bcc3-27df3db89a30
md"""
### 📏 Units
!!! tip " "
	The units are updated everytime the variable name is modified.
"""

# ╔═╡ 9b9716d9-d363-4e3c-be27-98ddcf9600e6
@bind units Select(["degree_Celsius", "psu", "mg/m3", "micromole/kg"],
				   default=variableunits[parameter])

# ╔═╡ 5915e937-63ae-4ebb-99ce-01bfa9b40b63
md"""
### 📆 Period of interest
#### Start date
"""

# ╔═╡ d5334600-ab0d-45f6-ac32-5bf8efe290ed
@bind datestart html"<input type=date value='2000-01-01' min='1800-01-01' max='2100-12-31'>"

# ╔═╡ 3f691b9a-258b-4d5d-bf03-15e830d6620e
md"""
#### End date
"""

# ╔═╡ a365ae24-a6c4-43e1-9f70-de2e9d9573a1
@bind dateend html"<input type=date value='2010-12-31' min='1800-01-01' max='2100-12-31'>"

# ╔═╡ 181c652b-ef85-402a-9f9b-61eb4f759a58
md"""
### 🗺️ Domain and depth range
!!! info " "
	The domain is set from the selected region of interest.
"""

# ╔═╡ 775ce187-9ce5-4e75-aab8-b2153e7a5c29
begin
	minlon = domaininfo[regionname][1]
	maxlon = domaininfo[regionname][2]
	minlat = domaininfo[regionname][3]
	maxlat = domaininfo[regionname][4]
	mindepth = 0. #Minimum water depth
	maxdepth = 400. #Maximum water depth
end

# ╔═╡ 0020634a-d792-4ace-bd74-ab565dfaa86d
md"""
## Query based on input fields
!!! info " "
	We use the function `prepare_query` defined in the next cell. The function definition is hidden but can be viewed by clicking on the _eye_ button. 
"""

# ╔═╡ de7029a9-a5a5-4cea-82e1-43f596c2b617
"""
	prepare_query(parameter, unit, datestart, dateend, mindepth, maxdept, minlon, maxlon, minlat, maxlat)

Prepare the query (JSON) that will be passed to the API.

# Example
```julia
julia> prepare_query("sea_water_temperature", "degree_Celsius", 
Dates.Date(2000, 1, 1), Dates.Date(2020, 12, 31), 0., 250., 26.5, 41.95, 40.0, 47.95)
```
"""
function prepare_query(parameter::String, unit::String, datestart::Date, dateend::Date, mindepth::Float64, maxdepth::Float64, minlon::Float64, maxlon::Float64, minlat::Float64, maxlat::Float64; 
dateref::Date=Dates.Date(1950, 1, 1))

    mintemporal = (datestart - dateref).value
    maxtemporal = (dateend - dateref).value

    # Start with an ordered dictionary, then convert to JSON
    paramdict = OrderedDict(
    "query_parameters" => [
    OrderedDict("data_parameter" => parameter,
        "unit"=> unit,
        "skip_fill_values" => true,
		"alias" => "OBSERVATIONS",
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

# ╔═╡ d65ef7a4-b404-47cc-a789-7138ad800705
md"""
!!! info "@time macro"
	Adding `@time` before a command will provide you with the execution time of that command
"""

# ╔═╡ 7e741d55-ea1f-449e-939e-036259742653
@time query = prepare_query(parameter, units, Date(datestart), Date(dateend), 
    mindepth, maxdepth, minlon, maxlon, minlat, maxlat);

# ╔═╡ c35fcaf8-6183-458c-8ff1-f3f2710670ee
md"""
### Perform request and write into netCDF file
- If the file is already there, the Beacon API is not called.
- The file name is created according to the region name, the period of interest and the depth range.
"""

# ╔═╡ b5d4f777-6ac0-4e84-9179-e96e25f8d542
begin 
	filename = joinpath(datadir, "Argo_$(parameter)_$(regionname)_$(Dates.format(datestart, "yyyymmdd"))-$(Dates.format(dateend, "yyyymmdd"))_$(Int(mindepth))-$(Int(maxdepth))m.nc");

	@info("Data will be written in file:\n$(filename)")

	if isfile(filename)
		@info("File already downloaded")
	else
		@time open(filename, "w") do io
			r = HTTP.request("POST", "$(beaconURL)/api/query", 
		    ["Content-Type" => "application/json"], query,
		    response_stream=io);
			@info(r.status)
		end	

	end;

	@info("NetCDF file size: $(round(filesize(filename)/1000^2, digits=1))M")
end;

# ╔═╡ 921f570e-6c64-4b3e-a7c9-beb9db7ef4c9
md"""
### Read netCDF content
"""

# ╔═╡ b64bc67d-ab2e-47a3-9f5f-0092f7917970
"""
	read_netcdf(datafile)

Read the coordinates and the variable stored in the netCDF file `datafile`

# Example
```julia
julia> obslon, obslat, obsdepth, obsdates, obsval =  read_netcdf("data.nc")
```
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

# ╔═╡ 7bac5550-6079-475d-8432-4913087a9a4b
begin 
	@time obslon, obslat, obsdepth, obsdates, obsval =  read_netcdf(filename);
	coords = [ [obslon[i], obslat[i]] for i in 1:length(obslon) ];
	unique!(coords);
	@info("Found $(length(coords)) unique coordinates")
end

# ╔═╡ 37ad43bd-432d-49f7-8d48-27e9831a3111
md"""
### 🌍 Interactive map ([`Leaflet`](https://leafletjs.com/))

!!! info "Leaflet"
	The coordinates obtained from the input file (netCDF) are directly fed into Leaflet.            

	Changing the region or the period of interest will automatically update the interactive map.
"""

# ╔═╡ a2d61983-0042-405f-ada9-1024e86c1644
@htl("""
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	
	<title>Observations in $(regionname)</title>
	
   <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css" integrity="sha512-h9FcoyWjHcOcmEVkxOfTLnmZFWIH0iZhZT1H2TbOq55xssQGEJHEaIm+PgoUaZbRvQTNTluNOEfb1ZRy6D3BOw==" crossorigin="anonymous" referrerpolicy="no-referrer" />
	<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js" integrity="sha512-puJW3E/qXDqYp9IfhAI54BJEaWIfloJ7JWs7OeD5i6ruC9JZL1gERT1wjtwXFlh7CjE7ZJ+/vcRZRkIYIb6p4g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
      <script src="https://unpkg.com/leaflet-providers@latest/leaflet-providers.js"></script>

	<style>
		html, body {
			height: 100%;
			margin: 0;
		}
	</style>

<body>
<div id="map" style="width: 100%; height: 400px;"></div>
<script>

	var map = L.map('map').setView([43., 34.], 6);
	var myRenderer = L.canvas({ padding: 0.1 });

	var OSM = L.tileLayer.provider('OpenStreetMap');
	var Carto = L.tileLayer.provider('CartoDB.Positron').addTo(map);

    var baseMaps = {
      "OpenStreetMap": OSM,
	  "Carto": Carto
    };

	var geojsonMarkerOptions = {
		renderer: myRenderer,
	    radius: 1.5,
	    fillColor: "#ff7800",
	    color: "#000",
	    weight: 1,
	    opacity: 1,
	    fillOpacity: 0.8
	};

	var geojsonFeature = {
            "type": "Feature",
            "geometry": {
                "type": "MultiPoint",
	                "coordinates": $(coords)
	            }
	        };

	var obs = L.geoJSON(geojsonFeature, {
	    pointToLayer: function (feature, latlng) {
	        return L.circleMarker(latlng, geojsonMarkerOptions);
	    }
	}).addTo(map);

	var bathy = L.tileLayer.wms("https://ows.emodnet-bathymetry.eu/wms", {
	    layers: ['emodnet:mean_atlas_land', 'coastlines'],
		format: 'image/png',
	    transparent: true,
	    attribution: "EMODnet Bathymetry"
	}).addTo(map);

	function fieldStyle(feature) {
		return {
			fillColor: getMoreColor(feature.properties.field),
			color: getMoreColor(feature.properties.field),
			weight: 1,
			opacity: 1,
			fillOpacity: 0.7
		};
	}

	// Define function that defines the colors
	//var divafield = new L.GeoJSON(field, {style: fieldStyle}).addTo(map);

	var southWest = new L.LatLng($(minlat), $(minlon)),
    	northEast = new L.LatLng($(maxlat), $(maxlon)),
    	bounds = new L.LatLngBounds(southWest, northEast)

	map.fitBounds(bounds);

	var overlayers = {
    	"Observation locations" : obs,
		"EMODnet bathymetry": bathy,
		//"DIVAnd interpolation": divafield
    };

	L.control.layers(baseMaps, overlayers, {collapsed:false}).addTo(map);
	
</script>

</body>
""")

# ╔═╡ 21aa2085-6c2e-41b8-97bc-e6eae39c924e
md"""
## 🎨 Make plot
!!! info " "
	The plots are enabled by clicking on the buttons in the `Options for the plots` cell.

	The images are saved locally, then displayed in the notebook using the `LocalResource` command.
### Create figure title
It is generated from the region name and the variable name.
"""

# ╔═╡ 23eca676-7c99-458a-8999-f799ba5b0222
begin 
	figtitleobs = """
		Observations: Argo $(regionname): $(parameter)"""
end

# ╔═╡ 64055f4f-d453-4535-8cce-02a23ab99275
if usecartopy

	fig1 = plt.figure()
	ax1 = plt.subplot(111, projection=ccrs.PlateCarree())
	ax1.set_extent([minlon, maxlon, minlat, maxlat])
	scat = ax1.scatter(obslon, obslat, s=3, c=obsval, cmap=plt.cm.RdYlBu_r)
	gl = ax1.gridlines(crs=ccrs.PlateCarree(), draw_labels=true,
	                  linewidth=.5, color="gray", alpha=0.5, linestyle="--", zorder=3)
	ax1.add_feature(coast, lw=.5, color=".85", zorder=4)
	gl.top_labels = false
	gl.right_labels = false
	ax1.set_title(figtitleobs)
	
	cbar1 = plt.colorbar(scat, shrink=.65)
	cbar1.set_label(units, rotation=0, ha="left")
	
	plt.savefig(joinpath(figdir, "observations01.jpg"))
	plt.close(fig1)

	LocalResource(joinpath(figdir, "observations01.jpg"))

end

# ╔═╡ 7b97d3ad-97aa-46bf-8141-15ce7c077863
if usebasemap

	fig2 = plt.figure()
	ax2 = plt.subplot(111)

	m = Basemap(projection = "cyl", llcrnrlon = minlon, llcrnrlat = minlat, 
    urcrnrlon = maxlon, urcrnrlat = maxlat, resolution = "i") 

	sc = m.scatter(obslon, obslat, latlon=true, s=3, c=obsval, cmap=plt.cm.RdYlBu_r)
	m.drawlsmask(land_color = ".85", ocean_color = "w"); 
	m.drawcoastlines(linewidth=.5, color=".85")
	m.drawparallels(collect(0.:5.:90.), color="gray", labels=[1,0,0,0])
	m.drawmeridians(collect(-10.:10.:80.), color="gray", labels=[0,0,0,1])
	ax2.set_title(figtitleobs)
	
	cbar2 = plt.colorbar(sc, shrink=.65)
	cbar2.set_label(units, rotation=0, ha="left")
	
	plt.savefig(joinpath(figdir, "observations02.jpg"))
	plt.close(fig2)

	LocalResource(joinpath(figdir, "observations02.jpg"))

end

# ╔═╡ 888ba762-4101-4139-88e9-8978d734f1cd
md"""
## `DIVAnd` interpolation
"""

# ╔═╡ ee28b85c-dd78-4edc-bacc-8cf0e8f1d6d5
md"""
### Set grid
"""

# ╔═╡ f3f219ba-b73b-460b-ac03-483bff5bf42b
begin
	dx, dy = 0.25, 0.25
	lonr = minlon:dx:maxlon
	latr = minlat:dy:maxlat
	timerange = [datestart, dateend];
	
	depthr = [0.,5., 10., 15., 20., 25., 30., 40., 50., 60., 
	    75, 85, 100, 112, 125, 135, 150, 175, 200, 225, 250, 
	    275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 
	    800, 850, 900, 950, 1000, 1050, 1100, 1150, 1200, 1250, 
	    1300, 1350, 1400, 1450, 1500, 1600, 1750, 1850, 2000];
	depthr = depthr[depthr .<= maxdepth];
end

# ╔═╡ 52363e92-93a4-457c-b358-42f0ac8bb0b1
md"""
### Time periods
"""

# ╔═╡ 706f5855-62e7-48cc-9fb3-f43af4f5c9ec
begin
	yearlist = [Dates.year(datestart):Dates.year(dateend)];
	monthlist = [[1,2,3],[4,5,6],[7,8,9],[10,11,12]];
	TS = DIVAnd.TimeSelectorYearListMonthList(yearlist,monthlist);
end

# ╔═╡ 38518967-9544-4ab3-b881-3962de5e368c
md"""
### Analysis parameters
- Correlation length
- Noise-to-signal ratio
"""

# ╔═╡ d2c1848d-87ec-42da-9525-315c787ce5d8
begin
	sz = (length(lonr), length(latr), length(depthr));
	lenx = fill(100_000.,sz)   # 100 km
	leny = fill(100_000.,sz)   # 100 km
	lenz = fill(5.,sz);      # 25 m 
	len = (lenx, leny, lenz);
	epsilon2 = 0.1;
end

# ╔═╡ 4696c1e6-8f20-4bf3-8bb9-4a22eee6cbd7
md"""
### Output file name
"""

# ╔═╡ c32ddf96-26aa-43dc-93a5-7f2ab807ff19
outputfile = joinpath(outputdir, "Argo_DIVAnd_$(parameter)_$(regionname)_$(Dates.format(datestart, "yyyymmdd"))-$(Dates.format(dateend, "yyyymmdd"))_$(Int(mindepth))-$(Int(maxdepth))m.nc")

# ╔═╡ 635c8b69-3e30-4ddd-b6df-1c90e8a516b9
md"""
### Select the bathymetry file
- [GEBCO](https://www.gebco.net/) for medium to large areas and 
- [EMODnet Bathymetry](https://emodnet.ec.europa.eu/en/bathymetry) for coastal applications.

The file is automatically downloaded if it is not yet available.
"""

# ╔═╡ 79a50ac3-a5c1-499e-801d-eebc7501d2bb
begin 
	bathymetryfile = joinpath(datadir, "gebco_30sec_16.nc")
	
	if isfile(bathymetryfile) 
		@info("Bathymetry file already downloaded")
	else
	download("https://dox.uliege.be/index.php/s/4tel71HR3bjSmNH/download", bathymetryfile)
	end
end

# ╔═╡ b8b9a325-b647-4e19-bb95-a768e1c457c3
md"""
### Helper function to generate plots
The function will be applied at each steps of the interpolation with `diva3d`.
"""

# ╔═╡ 4cb3bb80-2b61-49df-9be5-71d92b56c367
"""
	makemap(timeindex,sel,fit,erri)

Create a map for the period and variable of interest
"""
function makemap(timeindex,sel,fit,erri)
    tmp = copy(fit)
    nx,ny,nz = size(tmp)
    for i in 1:nz
        plt.figure()
        ax = plt.subplot(111, projection=ccrs.PlateCarree())
        ax.set_extend([lonr[1], lonr[end], latr[1], latr[end]])
        pcm = ax.pcolormesh(lonr, latr, permutedims(tmp[:,:,i], [2,1]), cmap=plt.cm.RdYlBu_r)
        cb = plt.colorbar(pcm, extend="both", orientation="vertical", shrink=0.8)
        cb.set_label("°C", rotation=0, ha="left")
        gl = ax.gridlines(crs=ccrs.PlateCarree(), draw_labels=true,
                  linewidth=.5, color="gray", alpha=0.5, linestyle="--", zorder=3)
        ax.add_feature(coast, lw=.5, color=".85", zorder=4)
        gl.top_labels = false
        gl.right_labels = false
        
        ax.set_title("Depth: $(depthr[i]) \n Time index: $(timeindex)")
        
        figname = parameter * @sprintf("_%02d",i) * @sprintf("_%03d.png",timeindex)
        plt.savefig(joinpath(figdir, figname));
        plt.close_figs()
    end
end

# ╔═╡ 3c65c949-2b21-4f70-9bd3-04fb783fd9d2
md"""
### ⚙️ Run analysis
"""

# ╔═╡ f84ddbf7-934b-47d9-9bf3-39d3d1bd076c
@time dbinfo = diva3d((lonr, latr, depthr, TS),
    (obslon,obslat,obsdepth,obsdates), obsval,
    len, epsilon2,
    outputfile,parameter,
    bathname=bathymetryfile
    );

# ╔═╡ d708b881-8678-40cc-8a07-0513a41159c6
md"""
### Read the results
"""

# ╔═╡ 226d77a9-c50d-4d4c-a906-86631dd60b50
function get_results(outputfile::AbstractString, parameter::AbstractString)
    NCDataset(outputfile, "r") do ds
        lon = ds["lon"][:]
        lat = ds["lat"][:]
        depth = ds["depth"][:]
        time = ds["time"][:]
        field = coalesce.(ds[parameter][:,:,:,:], NaN)
        
        return lon::Vector{Float64}, lat::Vector{Float64}, depth::Vector{Float64}, 				   time::Vector{DateTime}, field::Array{AbstractFloat, 4}
    end
end

# ╔═╡ 8c4e4476-b1a1-4291-8173-149824928339
lon, lat, depth, time, field = get_results(outputfile, parameter);

# ╔═╡ 98cca97e-b391-45f7-96a7-19ee350f4240
md"""
### Find time and depth indices for the plot
#### Select depth
"""

# ╔═╡ ac79bce7-9d1a-4925-9f6c-e0e163e42e43
@bind depth2plot Select(depthr)

# ╔═╡ eaff1b8d-5acf-410f-9800-5c67484260a1
md"""
#### Select month period
"""

# ╔═╡ 3873ec64-95e9-434d-b224-a53b7b2d989c
@bind months2plot Select(monthlist)

# ╔═╡ 56eb6cee-ff59-4afb-98ba-844f6e325d15
md"""
#### Select year period
"""

# ╔═╡ 7e2d01ee-46f7-4478-b0d7-3f1daeb796f5
@bind year2plot Select(yearlist)

# ╔═╡ b0361636-b96f-448a-9449-2774d7a1e86f
begin
	depthindex = findfirst(depth2plot .== depthr)
	monthindex = findfirst([mm == months2plot for mm in monthlist])
	yearindex = findfirst([yy == year2plot for yy in yearlist])
	timeindex = (yearindex-1) * length(monthlist) + monthindex
	@info("Depth index: $(depthindex)")
	@info("Time index: $(timeindex)")
end

# ╔═╡ d8ea13f6-34b2-4f9e-9d33-f02cffdd9f56
md"""
### 🎨 Create the plot
The figure title is set according to the depth and the time period
"""

# ╔═╡ 6a3a230c-333b-4828-99b5-6db74df0bd6b
field2D = @view field[:,:,depthindex,timeindex];

# ╔═╡ 05ae76b2-f489-4264-bd42-9314a8aad0a9
figtitle = """
DIVAnd analysis: Argo $(regionname): $(parameter) at $(depthr[depthindex]) m
Period: $(Dates.monthname(monthlist[monthindex][1])) - $(Dates.monthname(monthlist[monthindex][end])) $(yearlist[yearindex][1]) - $(yearlist[yearindex][end])""";

# ╔═╡ 3fe16edc-93b1-48a0-8d3c-5e56e2c13b2b
if usecartopy

	fig3 = plt.figure(figsize = (12, 8))
	ax3 = plt.subplot(111, projection=ccrs.PlateCarree())
	ax3.set_extent([minlon, maxlon, minlat, maxlat])
	pcm3 = ax3.pcolormesh(lon, lat, field2D', cmap=plt.cm.RdYlBu_r)
	gl3 = ax3.gridlines(crs=ccrs.PlateCarree(), draw_labels=true,
	                  linewidth=.5, color="gray", alpha=0.5, linestyle="--", zorder=3)
	ax3.add_feature(coast, lw=.5, color=".85", zorder=4)
	gl3.top_labels = false
	gl3.right_labels = false
	ax3.set_title(figtitle)
	
	cbar3 = plt.colorbar(pcm3, shrink=.65)
	cbar3.set_label(units, rotation=0, ha="left")
	plt.savefig(joinpath(figdir, "Argo_interpolation.jpg"))
	plt.close()

	LocalResource(joinpath(figdir, "Argo_interpolation.jpg"))
end

# ╔═╡ f72bd266-4559-4895-b753-ced821ffc44e
if usebasemap

	fig4 = plt.figure(figsize = (12, 8))
	ax4 = plt.subplot(111)
	m4 = Basemap(projection = "cyl", llcrnrlon = minlon, llcrnrlat = minlat, 
    urcrnrlon = maxlon, urcrnrlat = maxlat, resolution = "i") 
	
	pcm4 = m4.pcolormesh(lon, lat, field[:,:,1,1]', cmap=plt.cm.RdYlBu_r, latlon=true)

	m4.drawlsmask(land_color = ".85", ocean_color = "#CCFFFF"); 
	m4.drawcoastlines(linewidth=.5)
	m4.drawparallels(collect(0.:5.:90.), color="gray", labels=[1,0,0,0])
	m4.drawmeridians(collect(-10.:10.:80.), color="gray", labels=[0,0,0,1])
	
	cbar4 = plt.colorbar(pcm4, shrink=.65)
	cbar4.set_label(units, rotation=0, ha="left")
	plt.savefig(joinpath(figdir, "Argo_interpolation.jpg"))
	plt.close()

	LocalResource(joinpath(figdir, "Argo_interpolation.jpg"))
end

# ╔═╡ 0674379d-a171-4511-988e-4c917b50974e
# ╠═╡ disabled = true
#=╠═╡
md"""
## Results on a map
The 2D field is converted to geoJSON so it can be ingested by Leaflet.
"""
  ╠═╡ =#

# ╔═╡ bf33dcb0-cae6-4835-80bf-d649904b7a84
# ╠═╡ disabled = true
#=╠═╡
"""
	field2json(lonr, latr, field2D, thelevels)
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
    
    return JSON3.write(geojsonfield, allow_inf=false)
end
  ╠═╡ =#

# ╔═╡ 5258b923-3346-4ecc-aabc-da11e3fa6ae9
# ╠═╡ disabled = true
#=╠═╡
"""
	field2jsonlinestring(lonr, latr, field2D, thelevels)
"""
function field2jsonlinestring(lonr, latr, field2D, thelevels; valex=-999.)
    
    # Replace NaN's by exclusion valueµ
    field2D[isnan.(field2D)] .= valex

    # Compute the contours from the results
    contoursfield = Contour.contours(lonr, latr, field2D, thelevels)
    
    # Create the geoJSON starting from a dictionary
    geojsonfield = [
        Dict(
            "type" => "Feature",
            "geometry" => Dict(
                "type" => "MultiLineString",
                "coordinates" => [[[lon, lat] for (lon, lat) in zip(coordinates(line)[1], coordinates(line)[2])] for line in lines(cl)]),
            "properties" => Dict("field" => cl.level)
        ) for cl in levels(contoursfield)]
    
    return JSON3.write(geojsonfield)
end
  ╠═╡ =#

# ╔═╡ e6577f5a-00ba-4ea8-bce7-c952b7abc500
"""
	function write_field_json(lon, lat, field2D, Δvar)

Create a geoJSON object that stored the results (contours)
"""
function write_field_json(lon, lat, field2D::Matrix{AbstractFloat}, Δvar::Float64; cmap=plt.cm.RdYlBu_r, resfile::AbstractString="./field.js", funfile::AbstractString="./colorfunction.js")

    vmin = nanminimum(field2D)
    vmax = nanmaximum(field2D)
    @info("vmin = $vmin, vmax = $vmax")
    values = collect(floor(vmin / Δvar ) * Δvar : Δvar : floor(vmax / Δvar ) * Δvar)
    norm = mpl.colors.Normalize(vmin=values[1], vmax=vmax[end])

    fieldjson = field2jsonlinestring(lon, lat, field2D, values)

    # Write the contours in the geoJSON file
    #fieldjson = "var field = " * fieldjson
    
    # Prepare the color function
    colorlistrgb = cmap.(norm.(values))
    colorlisthex = [hex(RGB(thecolor[1], thecolor[2], thecolor[3])) for thecolor in colorlistrgb];
    
    # Write the color function (Javascript)
    thestring = "function getMoreColor(d) {return "
	for (vv, cc) in zip(values[1:end-1], colorlisthex[1:end-1])
		thestring *= "d < $(vv) ? '#$(cc)' : "
	end
	thestring *= "'#$(colorlisthex[end])'};"
	return fieldjson, thestring
    
end;

# ╔═╡ 26dddf63-91a3-4520-9f2c-9a8c654902d5
fieldjson, colorfunction = write_field_json(lon, lat, field[:,:,depthindex,timeindex], 0.02);

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
Conda = "8f4d0f93-b110-5947-807f-2305c1781a2d"
Contour = "d38c429a-6771-53c6-b99e-75d170b6e991"
DIVAnd = "efc8151c-67de-5a8f-9a35-d8f54746ae9d"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
InteractiveUtils = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
Markdown = "d6f4376e-aef5-505a-96c1-9c027394607a"
NCDatasets = "85f8d34a-cbdd-5861-8df4-14fed0d494ab"
NaNStatistics = "b946abbf-3ea7-4610-9019-9858bfdeaf2d"
OrderedCollections = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"
PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee"

[compat]
Colors = "~0.12.10"
Conda = "~1.10.0"
Contour = "~0.6.3"
DIVAnd = "~2.7.11"
HTTP = "~1.10.5"
HypertextLiteral = "~0.9.5"
JSON3 = "~1.14.0"
NCDatasets = "~0.14.3"
NaNStatistics = "~0.6.32"
OrderedCollections = "~1.6.3"
PlutoUI = "~0.7.58"
PyCall = "~1.96.4"
PyPlot = "~2.11.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.0-rc3"
manifest_format = "2.0"
project_hash = "928b2bf7088610fe93caa4fd8618a9345bd63378"

[[deps.ADTypes]]
git-tree-sha1 = "99a6f5d0ce1c7c6afdb759daa30226f71c54f6b0"
uuid = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
version = "1.7.1"

    [deps.ADTypes.extensions]
    ADTypesChainRulesCoreExt = "ChainRulesCore"
    ADTypesEnzymeCoreExt = "EnzymeCore"

    [deps.ADTypes.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "LinearAlgebra", "MacroTools", "Markdown", "Test"]
git-tree-sha1 = "f61b15be1d76846c0ce31d3fcfac5380ae53db6a"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.37"

    [deps.Accessors.extensions]
    AccessorsAxisKeysExt = "AxisKeys"
    AccessorsIntervalSetsExt = "IntervalSets"
    AccessorsStaticArraysExt = "StaticArrays"
    AccessorsStructArraysExt = "StructArrays"
    AccessorsUnitfulExt = "Unitful"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    Requires = "ae029012-a4dd-5104-9daa-d747884805df"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "6a55b747d1812e699320963ffde36f1ebdda4099"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.0.4"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AlgebraicMultigrid]]
deps = ["CommonSolve", "LinearAlgebra", "LinearSolve", "Printf", "Reexport", "SparseArrays"]
git-tree-sha1 = "eb3dbbca423d8e8a1d4061b890f775dcd31b8d7c"
uuid = "2169fc97-5a83-5252-b627-83903c6c433c"
version = "0.6.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "3640d077b6dafd64ceb8fd5c1ec76f7ca53bcf76"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.16.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = "CUDSS"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.ArrayLayouts]]
deps = ["FillArrays", "LinearAlgebra"]
git-tree-sha1 = "0dd7edaff278e346eb0ca07a7e75c9438408a3ce"
uuid = "4c555306-a7a7-4459-81d9-ec55ddd5c99a"
version = "1.10.3"
weakdeps = ["SparseArrays"]

    [deps.ArrayLayouts.extensions]
    ArrayLayoutsSparseArraysExt = "SparseArrays"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.BitTwiddlingConvenienceFunctions]]
deps = ["Static"]
git-tree-sha1 = "f21cfd4950cb9f0587d5067e69405ad2acd27b87"
uuid = "62783981-4cbd-42fc-bca8-16325de8dc4b"
version = "0.1.6"

[[deps.Blosc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Lz4_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "19b98ee7e3db3b4eff74c5c9c72bf32144e24f10"
uuid = "0b7ba130-8d10-5ba8-a3d6-c5182647fed9"
version = "1.21.5+0"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9e2a6b69137e6969bab0152632dcb3bc108c8bdd"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+1"

[[deps.CFTime]]
deps = ["Dates", "Printf"]
git-tree-sha1 = "5afb5c5ba2688ca43a9ad2e5a91cbb93921ccfa1"
uuid = "179af706-886a-5703-950a-314cd64e0468"
version = "0.1.3"

[[deps.CPUSummary]]
deps = ["CpuId", "IfElse", "PrecompileTools", "Static"]
git-tree-sha1 = "5a97e67919535d6841172016c9530fd69494e5ec"
uuid = "2a0fbf3d-bb9c-48f3-b0a9-814d99fd7ab9"
version = "0.2.6"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "71acdbf594aab5bbb2cec89b208c41b4c411e49f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.24.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CloseOpenIntervals]]
deps = ["Static", "StaticArrayInterface"]
git-tree-sha1 = "05ba0d07cd4fd8b7a39541e31a7b0254704ea581"
uuid = "fb6a15b2-703c-40df-9091-08a04967cfa9"
version = "0.1.13"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "bce6804e5e6044c6daab27bb533d1295e4a2e759"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.6"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "362a287c3aa50601b0bc359053d5c2468f0e7ce0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.11"

[[deps.CommonDataModel]]
deps = ["CFTime", "DataStructures", "Dates", "Preferences", "Printf", "Statistics"]
git-tree-sha1 = "d6fb5bf939a2753c74984b11434ea25d6c397a58"
uuid = "1fbeeb36-5f17-413c-809b-666fb144f157"
version = "0.3.6"

[[deps.CommonSolve]]
git-tree-sha1 = "0eee5eb66b1cf62cd6ad1b460238e60e4b09400c"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.4"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ConcreteStructs]]
git-tree-sha1 = "f749037478283d372048690eb3b5f92a79432b34"
uuid = "2569d6c7-a4a2-43d3-a901-331e8e4be471"
version = "0.2.3"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "ea32b83ca4fefa1768dc84e504cc0a94fb1ab8d1"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.4.2"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "b19db3927f0db4151cb86d073689f2428e524576"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.10.2"

[[deps.ConstructionBase]]
git-tree-sha1 = "76219f1ed5771adbb096743bff43fb5fdd4c1157"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.8"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.CpuId]]
deps = ["Markdown"]
git-tree-sha1 = "fcbb72b032692610bfbdb15018ac16a36cf2e406"
uuid = "adafc99b-e345-5852-983c-f28acb93d879"
version = "0.3.1"

[[deps.DIVAnd]]
deps = ["AlgebraicMultigrid", "DataStructures", "Dates", "DelimitedFiles", "Distributed", "EzXML", "HTTP", "Interpolations", "IterativeSolvers", "LinearAlgebra", "Missings", "Mustache", "NCDatasets", "Printf", "Random", "SharedArrays", "SparseArrays", "SpecialFunctions", "Statistics", "SuiteSparse", "Test", "UUIDs", "ZipFile"]
git-tree-sha1 = "a0007af330a51cda247a48a231204a1d5aaaadda"
uuid = "efc8151c-67de-5a8f-9a35-d8f54746ae9d"
version = "2.7.11"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DiskArrays]]
deps = ["LRUCache", "OffsetArrays"]
git-tree-sha1 = "ef25c513cad08d7ebbed158c91768ae32f308336"
uuid = "3c3547ce-8d99-4f5e-a174-61eb10b00ae3"
version = "0.3.23"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "dcb08a0d93ec0b1cdc4af184b26b591e9695423a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.10"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.Expronicon]]
deps = ["MLStyle", "Pkg", "TOML"]
git-tree-sha1 = "fc3951d4d398b5515f91d7fe5d45fc31dccb3c9b"
uuid = "6b7a57c9-7cc1-4fdf-b7f5-e857abae3636"
version = "0.8.5"

[[deps.EzXML]]
deps = ["Printf", "XML2_jll"]
git-tree-sha1 = "380053d61bb9064d6aa4a9777413b40429c79901"
uuid = "8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"
version = "1.2.0"

[[deps.FastLapackInterface]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "cbf5edddb61a43669710cbc2241bc08b36d9e660"
uuid = "29a986be-02c6-4525-aec4-84b980013641"
version = "2.0.4"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "6a70198746448456524cb442b8af316927ff3e1a"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.13.0"

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

    [deps.FillArrays.weakdeps]
    PDMats = "90014a1f-27ba-587c-ab20-58faa44d9150"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.FunctionWrappers]]
git-tree-sha1 = "d62485945ce5ae9c0c48f124a84998d755bae00e"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.3"

[[deps.FunctionWrappersWrappers]]
deps = ["FunctionWrappers"]
git-tree-sha1 = "b104d487b34566608f8b4e1c39fb0b10aa279ff8"
uuid = "77dc65aa-8811-40c2-897b-53d922fa7daf"
version = "0.1.3"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GMP_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "781609d7-10c4-51f6-84f2-b8444358ff6d"
version = "6.3.0+0"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "ec632f177c0d990e64d955ccc1b8c04c485a0950"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.6"

[[deps.GnuTLS_jll]]
deps = ["Artifacts", "GMP_jll", "JLLWrappers", "Libdl", "Nettle_jll", "P11Kit_jll", "Zlib_jll"]
git-tree-sha1 = "383db7d3f900f4c1f47a8a04115b053c095e48d3"
uuid = "0951126a-58fd-58f1-b5b3-b08c7c4a876d"
version = "3.8.4+0"

[[deps.HDF5_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LazyArtifacts", "LibCURL_jll", "Libdl", "MPICH_jll", "MPIPreferences", "MPItrampoline_jll", "MicrosoftMPI_jll", "OpenMPI_jll", "OpenSSL_jll", "TOML", "Zlib_jll", "libaec_jll"]
git-tree-sha1 = "82a471768b513dc39e471540fdadc84ff80ff997"
uuid = "0234f1f7-429e-5d53-9886-15a909be8d59"
version = "1.14.3+3"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "d1d712be3164d61d1fb98e7ce9bcbc6cc06b45ed"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.8"

[[deps.HostCPUFeatures]]
deps = ["BitTwiddlingConvenienceFunctions", "IfElse", "Libdl", "Static"]
git-tree-sha1 = "8e070b599339d622e9a081d17230d74a5c473293"
uuid = "3e5b6fbb-0976-4d2c-9146-d79de83f2fb0"
version = "0.1.17"

[[deps.Hwloc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "5e19e1e4fa3e71b774ce746274364aef0234634e"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.11.1+0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "10bd689145d2c3b2a9844005d01087cc1194e79e"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2024.2.1+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "88a101217d7cb38a7b481ccd50d21876e1d1b0e0"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.15.1"

    [deps.Interpolations.extensions]
    InterpolationsUnitfulExt = "Unitful"

    [deps.Interpolations.weakdeps]
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.InverseFunctions]]
git-tree-sha1 = "2787db24f4e03daf859c6509ff87764e4182f7d1"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.16"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IterativeSolvers]]
deps = ["LinearAlgebra", "Printf", "Random", "RecipesBase", "SparseArrays"]
git-tree-sha1 = "59545b0a2b27208b0650df0a46b8e3019f85055b"
uuid = "42fd0dbc-a981-5370-80f2-aaf504508153"
version = "0.9.4"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "f389674c99bfcde17dc57454011aa44d5a260a40"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.6.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "eb3edce0ed4fa32f75a0a11217433c31d56bd48b"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.14.0"

    [deps.JSON3.extensions]
    JSON3ArrowExt = ["ArrowTypes"]

    [deps.JSON3.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.KLU]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse_jll"]
git-tree-sha1 = "07649c499349dad9f08dde4243a4c597064663e9"
uuid = "ef3ab10e-7fda-4108-b977-705223b18434"
version = "0.6.0"

[[deps.Krylov]]
deps = ["LinearAlgebra", "Printf", "SparseArrays"]
git-tree-sha1 = "267dad6b4b7b5d529c76d40ff48d33f7e94cb834"
uuid = "ba0b0d4f-ebba-5204-a429-3ac8c609bfb7"
version = "0.9.6"

[[deps.LRUCache]]
git-tree-sha1 = "b3cc6698599b10e652832c2f23db3cab99d51b59"
uuid = "8ac3fa9e-de4c-5943-b1dc-09c6b5f20637"
version = "1.6.1"
weakdeps = ["Serialization"]

    [deps.LRUCache.extensions]
    SerializationExt = ["Serialization"]

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.LayoutPointers]]
deps = ["ArrayInterface", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "a9eaadb366f5493a5654e843864c13d8b107548c"
uuid = "10f19ff3-798f-405d-979b-55457f8fc047"
version = "0.1.17"

[[deps.LazyArrays]]
deps = ["ArrayLayouts", "FillArrays", "LinearAlgebra", "MacroTools", "SparseArrays"]
git-tree-sha1 = "507b423197fdd9e77b74aa2532c0a05eb7eb4004"
uuid = "5078a376-72f3-5289-bfd5-ec5146d43c02"
version = "2.2.0"

    [deps.LazyArrays.extensions]
    LazyArraysBandedMatricesExt = "BandedMatrices"
    LazyArraysBlockArraysExt = "BlockArrays"
    LazyArraysBlockBandedMatricesExt = "BlockBandedMatrices"
    LazyArraysStaticArraysExt = "StaticArrays"

    [deps.LazyArrays.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockArrays = "8e7c35d0-a365-5155-bbbb-fb81a777f24e"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f9557a255370125b405568f9767d6d195822a175"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.17.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.LinearSolve]]
deps = ["ArrayInterface", "ChainRulesCore", "ConcreteStructs", "DocStringExtensions", "EnumX", "FastLapackInterface", "GPUArraysCore", "InteractiveUtils", "KLU", "Krylov", "LazyArrays", "Libdl", "LinearAlgebra", "MKL_jll", "Markdown", "PrecompileTools", "Preferences", "RecursiveFactorization", "Reexport", "SciMLBase", "SciMLOperators", "Setfield", "SparseArrays", "Sparspak", "StaticArraysCore", "UnPack"]
git-tree-sha1 = "6c5e4555ac2bc449a28604e184f759d18fc08420"
uuid = "7ed4a6bd-45f5-4d41-b270-4a48e9bafcae"
version = "2.34.0"

    [deps.LinearSolve.extensions]
    LinearSolveBandedMatricesExt = "BandedMatrices"
    LinearSolveBlockDiagonalsExt = "BlockDiagonals"
    LinearSolveCUDAExt = "CUDA"
    LinearSolveCUDSSExt = "CUDSS"
    LinearSolveEnzymeExt = ["Enzyme", "EnzymeCore"]
    LinearSolveFastAlmostBandedMatricesExt = ["FastAlmostBandedMatrices"]
    LinearSolveHYPREExt = "HYPRE"
    LinearSolveIterativeSolversExt = "IterativeSolvers"
    LinearSolveKernelAbstractionsExt = "KernelAbstractions"
    LinearSolveKrylovKitExt = "KrylovKit"
    LinearSolveMetalExt = "Metal"
    LinearSolvePardisoExt = "Pardiso"
    LinearSolveRecursiveArrayToolsExt = "RecursiveArrayTools"

    [deps.LinearSolve.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockDiagonals = "0a1fb500-61f7-11e9-3c65-f5ef3456f9f0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"
    FastAlmostBandedMatrices = "9d29842c-ecb8-4973-b1e9-a27b1157504e"
    HYPRE = "b5ffcf37-a2bd-41ab-a3da-4bd9bc8ad771"
    IterativeSolvers = "42fd0dbc-a981-5370-80f2-aaf504508153"
    KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
    KrylovKit = "0b1a1467-8014-51b9-945f-bf0ae24f4b77"
    Metal = "dde4c033-4e86-420c-a63e-0dd931031962"
    Pardiso = "46dd5b70-b6fb-5a00-ae2d-e8fea33afaf2"
    RecursiveArrayTools = "731186ca-8d62-57ce-b412-fbd966d074cd"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "a2d09619db4e765091ee5c6ffe8872849de0feea"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.28"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "c1dd6d7978c12545b4179fb6153b9250c96b0075"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.3"

[[deps.LoopVectorization]]
deps = ["ArrayInterface", "CPUSummary", "CloseOpenIntervals", "DocStringExtensions", "HostCPUFeatures", "IfElse", "LayoutPointers", "LinearAlgebra", "OffsetArrays", "PolyesterWeave", "PrecompileTools", "SIMDTypes", "SLEEFPirates", "Static", "StaticArrayInterface", "ThreadingUtilities", "UnPack", "VectorizationBase"]
git-tree-sha1 = "8084c25a250e00ae427a379a5b607e7aed96a2dd"
uuid = "bdcacae8-1622-11e9-2a5c-532679323890"
version = "0.12.171"

    [deps.LoopVectorization.extensions]
    ForwardDiffExt = ["ChainRulesCore", "ForwardDiff"]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.LoopVectorization.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Lz4_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7f26c8fc5229e68484e0b3447312c98e16207d11"
uuid = "5ced341a-0733-55b8-9ab6-a4889d929147"
version = "1.10.0+0"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "f046ccd0c6db2832a9f639e2c669c6fe867e5f4f"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2024.2.0+0"

[[deps.MLStyle]]
git-tree-sha1 = "bc38dff0548128765760c79eb7388a4b37fae2c8"
uuid = "d8e11817-5142-5d16-987a-aa16d5891078"
version = "0.4.17"

[[deps.MPICH_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Hwloc_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML"]
git-tree-sha1 = "19d4bd098928a3263693991500d05d74dbdc2004"
uuid = "7cb0a576-ebde-5e09-9194-50597f1243b4"
version = "4.2.2+0"

[[deps.MPIPreferences]]
deps = ["Libdl", "Preferences"]
git-tree-sha1 = "c105fe467859e7f6e9a852cb15cb4301126fac07"
uuid = "3da0fdf6-3ccc-4f1b-acd9-58baa6c99267"
version = "0.1.11"

[[deps.MPItrampoline_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML"]
git-tree-sha1 = "8c35d5420193841b2f367e658540e8d9e0601ed0"
uuid = "f1f71cc9-e9ae-5b93-9b94-4fe0e1ad3748"
version = "5.4.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.ManualMemory]]
git-tree-sha1 = "bcaef4fc7a0cfe2cba636d84cda54b5e4e4ca3cd"
uuid = "d125e4d3-2237-4719-b19c-fa641b8a4667"
version = "0.1.8"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.MicrosoftMPI_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f12a29c4400ba812841c6ace3f4efbb6dbb3ba01"
uuid = "9237b28f-5490-5468-be7b-bb81f5f5e6cf"
version = "10.1.4+2"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.Mustache]]
deps = ["Printf", "Tables"]
git-tree-sha1 = "3b2db451a872b20519ebb0cec759d3d81a1c6bcb"
uuid = "ffc61752-8dc7-55ee-8c37-f3e9cdd09e70"
version = "1.0.20"

[[deps.NCDatasets]]
deps = ["CFTime", "CommonDataModel", "DataStructures", "Dates", "DiskArrays", "NetCDF_jll", "NetworkOptions", "Printf"]
git-tree-sha1 = "77df6d3708ec0eb3441551e1f20f7503b37c2393"
uuid = "85f8d34a-cbdd-5861-8df4-14fed0d494ab"
version = "0.14.5"

[[deps.NaNStatistics]]
deps = ["PrecompileTools", "Static", "StaticArrayInterface"]
git-tree-sha1 = "643573fb1771d2ae140b775c18e4278578051c03"
uuid = "b946abbf-3ea7-4610-9019-9858bfdeaf2d"
version = "0.6.41"

[[deps.NetCDF_jll]]
deps = ["Artifacts", "Blosc_jll", "Bzip2_jll", "HDF5_jll", "JLLWrappers", "LazyArtifacts", "LibCURL_jll", "Libdl", "MPICH_jll", "MPIPreferences", "MPItrampoline_jll", "MicrosoftMPI_jll", "OpenMPI_jll", "TOML", "XML2_jll", "Zlib_jll", "Zstd_jll", "libzip_jll"]
git-tree-sha1 = "4686378c4ae1d1948cfbe46c002a11a4265dcb07"
uuid = "7243133f-43d8-5620-bbf4-c2c921802cf3"
version = "400.902.211+1"

[[deps.Nettle_jll]]
deps = ["Artifacts", "GMP_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "eca63e3847dad608cfa6a3329b95ef674c7160b4"
uuid = "4c82536e-c426-54e4-b420-14f461c4ed8b"
version = "3.7.2+0"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OffsetArrays]]
git-tree-sha1 = "1a27764e945a152f7ca7efa04de513d473e9542e"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.14.1"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenMPI_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML"]
git-tree-sha1 = "e25c1778a98e34219a00455d6e4384e017ea9762"
uuid = "fe0851c0-eecd-5654-98d4-656369965a5c"
version = "4.1.6+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "38cb508d080d21dc1128f7fb04f20387ed4c0af4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a028ee3cb5641cccc4c24e90c36b0a4f7707bdf5"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.14+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.P11Kit_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "2cd396108e178f3ae8dedbd8e938a18726ab2fbf"
uuid = "c2071276-7c44-58a7-b746-946036e04d0a"
version = "0.24.1+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"

    [deps.Pkg.extensions]
    REPLExt = "REPL"

    [deps.Pkg.weakdeps]
    REPL = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "eba4810d5e6a01f612b948c9fa94f905b49087b0"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.60"

[[deps.Polyester]]
deps = ["ArrayInterface", "BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "ManualMemory", "PolyesterWeave", "Static", "StaticArrayInterface", "StrideArraysCore", "ThreadingUtilities"]
git-tree-sha1 = "6d38fea02d983051776a856b7df75b30cf9a3c1f"
uuid = "f517fe37-dbe3-4b94-8317-1923a5111588"
version = "0.7.16"

[[deps.PolyesterWeave]]
deps = ["BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "Static", "ThreadingUtilities"]
git-tree-sha1 = "645bed98cd47f72f67316fd42fc47dee771aefcd"
uuid = "1d0040c9-8b98-4ee7-8388-3f51789ca0ad"
version = "0.2.2"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "9816a3826b0ebf49ab4926e2b18842ad8b5c8f04"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.96.4"

[[deps.PyPlot]]
deps = ["Colors", "LaTeXStrings", "PyCall", "Sockets", "Test", "VersionParsing"]
git-tree-sha1 = "0371ca706e3f295481cbf94c8c36692b072285c2"
uuid = "d330b81b-6aea-500a-939a-2ce795aea3ee"
version = "2.11.5"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecursiveArrayTools]]
deps = ["Adapt", "ArrayInterface", "DocStringExtensions", "GPUArraysCore", "IteratorInterfaceExtensions", "LinearAlgebra", "RecipesBase", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "b034171b93aebc81b3e1890a036d13a9c4a9e3e0"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "3.27.0"

    [deps.RecursiveArrayTools.extensions]
    RecursiveArrayToolsFastBroadcastExt = "FastBroadcast"
    RecursiveArrayToolsForwardDiffExt = "ForwardDiff"
    RecursiveArrayToolsMeasurementsExt = "Measurements"
    RecursiveArrayToolsMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    RecursiveArrayToolsReverseDiffExt = ["ReverseDiff", "Zygote"]
    RecursiveArrayToolsSparseArraysExt = ["SparseArrays"]
    RecursiveArrayToolsTrackerExt = "Tracker"
    RecursiveArrayToolsZygoteExt = "Zygote"

    [deps.RecursiveArrayTools.weakdeps]
    FastBroadcast = "7034ab61-46d4-4ed7-9d0f-46aef9175898"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.RecursiveFactorization]]
deps = ["LinearAlgebra", "LoopVectorization", "Polyester", "PrecompileTools", "StrideArraysCore", "TriangularSolve"]
git-tree-sha1 = "6db1a75507051bc18bfa131fbc7c3f169cc4b2f6"
uuid = "f2c3362d-daeb-58d1-803e-2bc74f2840b4"
version = "0.2.23"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "04c968137612c4a5629fa531334bb81ad5680f00"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.13"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMDTypes]]
git-tree-sha1 = "330289636fb8107c5f32088d2741e9fd7a061a5c"
uuid = "94e857df-77ce-4151-89e5-788b33177be4"
version = "0.1.0"

[[deps.SLEEFPirates]]
deps = ["IfElse", "Static", "VectorizationBase"]
git-tree-sha1 = "456f610ca2fbd1c14f5fcf31c6bfadc55e7d66e0"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.43"

[[deps.SciMLBase]]
deps = ["ADTypes", "Accessors", "ArrayInterface", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "Expronicon", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "PrecompileTools", "Preferences", "Printf", "RecipesBase", "RecursiveArrayTools", "Reexport", "RuntimeGeneratedFunctions", "SciMLOperators", "SciMLStructures", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "8001043f80051c86f264fd6e936d97e6b9eff401"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "2.52.0"

    [deps.SciMLBase.extensions]
    SciMLBaseChainRulesCoreExt = "ChainRulesCore"
    SciMLBaseMakieExt = "Makie"
    SciMLBasePartialFunctionsExt = "PartialFunctions"
    SciMLBasePyCallExt = "PyCall"
    SciMLBasePythonCallExt = "PythonCall"
    SciMLBaseRCallExt = "RCall"
    SciMLBaseZygoteExt = "Zygote"

    [deps.SciMLBase.weakdeps]
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    PartialFunctions = "570af359-4316-4cb7-8c74-252c00c2016b"
    PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
    PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
    RCall = "6f49c342-dc21-5d91-9882-a32aef131414"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.SciMLOperators]]
deps = ["Accessors", "ArrayInterface", "DocStringExtensions", "LinearAlgebra", "MacroTools"]
git-tree-sha1 = "e39c5f217f9aca640c8e27ab21acf557a3967db5"
uuid = "c0aeaf25-5076-4817-a8d5-81caf7dfa961"
version = "0.3.10"
weakdeps = ["SparseArrays", "StaticArraysCore"]

    [deps.SciMLOperators.extensions]
    SciMLOperatorsSparseArraysExt = "SparseArrays"
    SciMLOperatorsStaticArraysCoreExt = "StaticArraysCore"

[[deps.SciMLStructures]]
deps = ["ArrayInterface"]
git-tree-sha1 = "25514a6f200219cd1073e4ff23a6324e4a7efe64"
uuid = "53ae85a6-f571-4167-b2af-e1d143709226"
version = "1.5.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.Sparspak]]
deps = ["Libdl", "LinearAlgebra", "Logging", "OffsetArrays", "Printf", "SparseArrays", "Test"]
git-tree-sha1 = "342cf4b449c299d8d1ceaf00b7a49f4fbc7940e7"
uuid = "e56a9233-b9d6-4f03-8d0f-1825330902ac"
version = "0.3.9"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "2f5d4697f21388cbe1ff299430dd169ef97d7e14"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.4.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.Static]]
deps = ["IfElse"]
git-tree-sha1 = "d2fdac9ff3906e27f7a618d47b676941baa6c80c"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.8.10"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "Static"]
git-tree-sha1 = "96381d50f1ce85f2663584c8e886a6ca97e60554"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.8.0"
weakdeps = ["OffsetArrays", "StaticArrays"]

    [deps.StaticArrayInterface.extensions]
    StaticArrayInterfaceOffsetArraysExt = "OffsetArrays"
    StaticArrayInterfaceStaticArraysExt = "StaticArrays"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "eeafab08ae20c62c44c8399ccb9354a04b80db50"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.7"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StrideArraysCore]]
deps = ["ArrayInterface", "CloseOpenIntervals", "IfElse", "LayoutPointers", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface", "ThreadingUtilities"]
git-tree-sha1 = "f35f6ab602df8413a50c4a25ca14de821e8605fb"
uuid = "7792a7ef-975c-4747-a70f-980b88e8d1da"
version = "0.5.7"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "159331b30e94d7b11379037feeb9b690950cace8"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.SymbolicIndexingInterface]]
deps = ["Accessors", "ArrayInterface", "RuntimeGeneratedFunctions", "StaticArraysCore"]
git-tree-sha1 = "c9fce29fb41a10677e24f74421ebe31220b81ad0"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.3.28"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "598cd7c1f68d1e205689b1c2fe65a9f85846f297"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.ThreadingUtilities]]
deps = ["ManualMemory"]
git-tree-sha1 = "eda08f7e9818eb53661b3deb74e3159460dfbc27"
uuid = "8290d209-cae3-49c0-8002-c8c24d57dab5"
version = "0.5.2"

[[deps.TranscodingStreams]]
git-tree-sha1 = "e84b3a11b9bece70d14cce63406bbc79ed3464d2"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.2"

[[deps.TriangularSolve]]
deps = ["CloseOpenIntervals", "IfElse", "LayoutPointers", "LinearAlgebra", "LoopVectorization", "Polyester", "Static", "VectorizationBase"]
git-tree-sha1 = "be986ad9dac14888ba338c2554dcfec6939e1393"
uuid = "d5829a12-d9aa-46ab-831f-fb7c9ab06edf"
version = "0.2.1"

[[deps.Tricks]]
git-tree-sha1 = "7822b97e99a1672bfb1b49b668a6d46d58d8cbcb"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.9"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.VectorizationBase]]
deps = ["ArrayInterface", "CPUSummary", "HostCPUFeatures", "IfElse", "LayoutPointers", "Libdl", "LinearAlgebra", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "e7f5b81c65eb858bed630fe006837b935518aca5"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.21.70"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "1165b0443d0eca63ac1e32b8c0eb69ed2f4f8127"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.3+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "ac88fb95ae6447c8dda6a5503f3bafd496ae8632"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.4.6+0"

[[deps.ZipFile]]
deps = ["Libdl", "Printf", "Zlib_jll"]
git-tree-sha1 = "f492b7fe1698e623024e873244f10d89c95c340a"
uuid = "a5390f91-8eb1-5f08-bee0-b1d1ffed6cea"
version = "0.10.1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e678132f07ddb5bfa46857f0d7620fb9be675d3b"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.6+0"

[[deps.libaec_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "46bf7be2917b59b761247be3f317ddf75e50e997"
uuid = "477f73a3-ac25-53e9-8cc3-50b2fa2566f0"
version = "1.1.2+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libzip_jll]]
deps = ["Artifacts", "Bzip2_jll", "GnuTLS_jll", "JLLWrappers", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "3282b7d16ae7ac3e57ec2f3fa8fafb564d8f9f7f"
uuid = "337d8026-41b4-5cde-a456-74a10e5b31d1"
version = "1.10.1+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7d0ea0f4895ef2f5cb83645fa689e52cb55cf493"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2021.12.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─8fedd67c-80b5-42bb-8c02-c14d278e4e8c
# ╟─c2f31032-1a7c-4fed-9713-0dd33b02ba37
# ╠═557eda82-f679-11ee-274e-37137b03fb0f
# ╟─ba962cb7-46c5-4b6e-8963-d4ab171f8d0a
# ╠═4a823c93-6120-4204-ba4d-3b5558fc8e8d
# ╟─e2c7e580-9202-4b4c-a41d-f00aff0f282f
# ╠═be148eac-bbba-4929-a5ca-a7735c9b77a9
# ╟─ff528eed-305f-4f2c-bf4b-c79f3ddd0010
# ╟─31979a73-1b7f-4e84-9a18-ce8fd808d655
# ╠═b20b0a42-2f04-4abc-8b37-278d62a42e32
# ╠═05def578-6786-4713-af46-ac58b334f5c7
# ╟─2d812c57-40f6-499b-972f-69be172d1365
# ╟─b9c9921b-b41a-480e-b0ac-fca6e652dc22
# ╟─3de1e314-10a2-4604-9c2d-dda5e95e01b4
# ╟─7d195f6e-5308-40b3-9547-6614e96c006a
# ╟─e7ae81f3-970e-4d3f-936f-3073b1063e5c
# ╟─e57790e8-35e9-4920-b24b-0b1fe07f42ce
# ╟─9d3aa9d8-ab25-48b3-aede-428c9d960815
# ╟─f7510e4d-5814-4511-bcc3-27df3db89a30
# ╟─9b9716d9-d363-4e3c-be27-98ddcf9600e6
# ╟─5915e937-63ae-4ebb-99ce-01bfa9b40b63
# ╟─d5334600-ab0d-45f6-ac32-5bf8efe290ed
# ╟─3f691b9a-258b-4d5d-bf03-15e830d6620e
# ╟─a365ae24-a6c4-43e1-9f70-de2e9d9573a1
# ╟─181c652b-ef85-402a-9f9b-61eb4f759a58
# ╠═775ce187-9ce5-4e75-aab8-b2153e7a5c29
# ╟─0020634a-d792-4ace-bd74-ab565dfaa86d
# ╟─de7029a9-a5a5-4cea-82e1-43f596c2b617
# ╟─d65ef7a4-b404-47cc-a789-7138ad800705
# ╠═7e741d55-ea1f-449e-939e-036259742653
# ╟─c35fcaf8-6183-458c-8ff1-f3f2710670ee
# ╠═b5d4f777-6ac0-4e84-9179-e96e25f8d542
# ╟─921f570e-6c64-4b3e-a7c9-beb9db7ef4c9
# ╟─b64bc67d-ab2e-47a3-9f5f-0092f7917970
# ╠═7bac5550-6079-475d-8432-4913087a9a4b
# ╟─37ad43bd-432d-49f7-8d48-27e9831a3111
# ╟─a2d61983-0042-405f-ada9-1024e86c1644
# ╟─21aa2085-6c2e-41b8-97bc-e6eae39c924e
# ╟─23eca676-7c99-458a-8999-f799ba5b0222
# ╠═64055f4f-d453-4535-8cce-02a23ab99275
# ╠═7b97d3ad-97aa-46bf-8141-15ce7c077863
# ╟─888ba762-4101-4139-88e9-8978d734f1cd
# ╠═d9954dc8-c243-4a95-ba50-7768db5b6a82
# ╟─ee28b85c-dd78-4edc-bacc-8cf0e8f1d6d5
# ╠═f3f219ba-b73b-460b-ac03-483bff5bf42b
# ╟─52363e92-93a4-457c-b358-42f0ac8bb0b1
# ╠═706f5855-62e7-48cc-9fb3-f43af4f5c9ec
# ╟─38518967-9544-4ab3-b881-3962de5e368c
# ╠═d2c1848d-87ec-42da-9525-315c787ce5d8
# ╟─4696c1e6-8f20-4bf3-8bb9-4a22eee6cbd7
# ╟─c32ddf96-26aa-43dc-93a5-7f2ab807ff19
# ╟─635c8b69-3e30-4ddd-b6df-1c90e8a516b9
# ╠═79a50ac3-a5c1-499e-801d-eebc7501d2bb
# ╟─b8b9a325-b647-4e19-bb95-a768e1c457c3
# ╟─4cb3bb80-2b61-49df-9be5-71d92b56c367
# ╟─3c65c949-2b21-4f70-9bd3-04fb783fd9d2
# ╠═f84ddbf7-934b-47d9-9bf3-39d3d1bd076c
# ╟─d708b881-8678-40cc-8a07-0513a41159c6
# ╟─226d77a9-c50d-4d4c-a906-86631dd60b50
# ╠═8c4e4476-b1a1-4291-8173-149824928339
# ╟─98cca97e-b391-45f7-96a7-19ee350f4240
# ╟─ac79bce7-9d1a-4925-9f6c-e0e163e42e43
# ╟─eaff1b8d-5acf-410f-9800-5c67484260a1
# ╟─3873ec64-95e9-434d-b224-a53b7b2d989c
# ╟─56eb6cee-ff59-4afb-98ba-844f6e325d15
# ╟─7e2d01ee-46f7-4478-b0d7-3f1daeb796f5
# ╠═b0361636-b96f-448a-9449-2774d7a1e86f
# ╟─d8ea13f6-34b2-4f9e-9d33-f02cffdd9f56
# ╠═6a3a230c-333b-4828-99b5-6db74df0bd6b
# ╟─05ae76b2-f489-4264-bd42-9314a8aad0a9
# ╠═3fe16edc-93b1-48a0-8d3c-5e56e2c13b2b
# ╠═f72bd266-4559-4895-b753-ced821ffc44e
# ╟─0674379d-a171-4511-988e-4c917b50974e
# ╟─bf33dcb0-cae6-4835-80bf-d649904b7a84
# ╟─5258b923-3346-4ecc-aabc-da11e3fa6ae9
# ╟─e6577f5a-00ba-4ea8-bce7-c952b7abc500
# ╠═26dddf63-91a3-4520-9f2c-9a8c654902d5
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
