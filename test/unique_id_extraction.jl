"""
This script is built to automatically check the correctness of the location matching and
print sufficient information for the user to manually verify location that could not be
automatically matched.

If the human readable names match sufficiently according to the overlap string similarity or
the point is contained within the canonical reef polygon then we automatically dismiss the
location as correct. Other locations must be checked manually using qgis to make sure no
locations not contained in the gpkg are not matched.
"""

import GeoDataFrames as GDF

include("../src/endpoints.jl")
include("../src/processing.jl")

function compare_match(reef_name::String, lat::Float64, lon::Float64, canonical_gpkg::DataFrame)
    unique_id::String = get_unique_id(lat, lon, canonical_gpkg)
    if all(unique_id[1:3] .== "N/A")
        @info "api name: $(reef_name), unqiue_id: $(unique_id), no match."

        return nothing
    end
    idx::Int64 = findfirst(canonical_gpkg.UNIQUE_ID .== unique_id)
    canonical_name::String = canonical_gpkg.reef_name[idx]
    not_useful = ["reef" => "", "island" => "", "Reef" => "", "Island" => "", "U/N " => ""]
    canonical_name = replace(canonical_name, not_useful...)
    reef_name = replace(reef_name, not_useful...)

    similarity = Overlap(2)(reef_name, canonical_name)
    if similarity > 0.4
        @info "index: $(idx), api name: $(reef_name), canonical_gpkg: $(canonical_name)"
        dist = AG.distance(canonical_gpkg.geometry[idx], AG.createpoint(lon, lat))
        if dist == 0.0
            @info "Contained in polygon."
        else
            # Information for debugging
            @info "lat: $(lat), lon: $(lon)"
        end
    end
    return nothing
end
