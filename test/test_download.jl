using NCDatasets
using Test


@testset "Download" begin

    datafilelist = ["/tmp/jl_ozclgXm7gT.nc", "/tmp/jl_naTALaDiv4.nc", "/tmp/jl_EhWRKP2hOF.nc"]

    ds = NCDataset(datafilelist[1], "r") 
    lonref = ds["LONGITUDE"][:]
    tempref = ds["TEMP"][:]
    close(ds)

    @test length(lonref) == 667
    @test length(lonref) == length(tempref)

    for datafile in datafilelist[2:end]
        nc = NCDataset(datafile, "r") 
        lon = nc["LONGITUDE"][:]
        close(nc)
        @test sort(lon) == sort(lonref)
    end
end
