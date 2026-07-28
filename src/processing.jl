"""
Functions to transform results from the API endpoints into more user friendly formats.
"""

using CSV,
    DataFrames,
    Dates,
    NetCDF,
    YAXArrays

using StringDistances

import GeoDataFrames as GDF
import ArchGDAL as AG

using ProgressMeter

function get_unique_id(lat::Float64, lon::Float64, canonical_gpkg::DataFrame)::String
    pt = AG.createpoint(lon, lat)
    dists::Vector{Float64} = [AG.distance(poly, pt) for poly in canonical_gpkg.geometry]
    closest = argmin(dists)
    if dists[closest] *  111.1 > 1.0
        return replace("N/A_$(string(trunc(lat, digits=3)))_$(string(trunc(lon, digits=3)))", "." => "", "-" => "")
    end
    return canonical_gpkg.UNIQUE_ID[closest]
end

function get_unique_id_compare(reef_name::String, lat::Float64, lon::Float64, canonical_gpkg::DataFrame)::String
    pt = AG.createpoint(lon, lat)
    closest = argmin([AG.distance(poly, pt) for poly in canonical_gpkg.geometry])
    @info "api name: $(reef_name), canonical_gpkg: $(canonical_gpkg.reef_name[closest]), qgram: $(Overlap(2)(reef_name, canonical_gpkg.reef_name[closest]))"
    return canonical_gpkg.UNIQUE_ID[closest]
end

# Reefmon taxa classification to C~Scape/ADRIAmod functional groups
const REEFMON_TO_TAXA::Dict{String, Int64} = Dict(
    "Acropora" => -1, # Split acro table corym
    "Pocilloporidae" => 3, # Corym non Acro
    "Isopora" => 2 , # Acro Corym
    "Merulinidae" => 4, # Small massive
    "Other" => 0, #
    "Porites" => 5, # Large Massive
    "Unidentified" => 0, #
    "Lobophylliidae" => 4, # Small Massive
    "Montipora" => 2, # Acro Corym
    "Euphylliidae" => 4, # Small Massive
    "Dendrophylliidae" => 2, # Acro Corym
    "Fungiidae" => 4, # Small Massive
    "Goniopora Alveopora" => 5, # Large Massive
    "Pachyseris" => 4, # Small Massive
    "Rare groups" => 0, #
    "Leptastrea" => 4, # Small Massive
    "Psammocora" => 4, # Small Massive
    "Agariciidae" => 4 # Small Massive
)

const N_TAXA::Int64 = 5

const ADRIA_TAXA::Vector{String} = [
    "Tabular_Acropora",
    "Corymbose_Acropora",
    "Corymbose_non_Acropora",
    "Small_Massives",
    "Large_Massives"
]

"""
    _add_taxa_cover!(destination::Matrix, source::DataFrame, taxa::string; stat::Symbol=mean)::Matrix
"""
function _add_taxa_cover!(
    destination::Matrix,
    source::DataFrame,
    taxa::String;
    stat::Symbol=:mean
)::Matrix
    temporal_range = 1992:2025
    taxa_idx = REEFMON_TO_TAXA[taxa]

    # Other or rare groups are ignored
    if taxa_idx == 0
        return destination
    end

    # If acropora split evenly between both acropora groups
    taxa_idx = taxa_idx == -1 ? [1, 2] : [taxa_idx]

    observation_years = source.report_year
    observation_perm = sortperm(observation_years)

    dest_write_mask = [year in observation_years for year in temporal_range]
    destination[dest_write_mask, taxa_idx] .+= (
        source[observation_perm, stat] ./ length(taxa_idx)
    )

    return destination
end

"""
    depth_composition(photo_transect::DataFrame)::YAXArray

Some ltmp location report coral composition at different depths seperately. Calculate the
composition at the dataframe that has already been filtered to only refer to a single depth.
"""
function depth_composition(photo_transect::DataFrame; stat::Symbol=:mean)::Matrix{Union{Float64, Missing}}
    temporal_range = 1992:2025
    composition = Matrix{Union{Float64, Missing}}(undef, length(temporal_range), N_TAXA)
    composition .= 0.0

    reefmon_taxa = unique(photo_transect.reefpage_category)

    for taxa in reefmon_taxa
        taxa_mask = photo_transect.reefpage_category .== taxa
        composition = _add_taxa_cover!(
            composition, photo_transect[taxa_mask, :], taxa; stat=stat
        )
    end

    return composition
end

"""
    fill_missing_years!(composition::Matrix{Union{Float64, Missing}})::Matrix{Union{Float64, Missing}}

Fill years where all data is 0.0 as missing.
"""
function fill_missing_years!(
    composition::Matrix{Union{Float64, Missing}}
)::Matrix{Union{Float64, Missing}}

    for row_idx in 1:size(composition, 1)
        if all(composition[row_idx, :] .== 0.0)
            composition[row_idx, :] .= missing
        end
    end
    return composition
end

"""
    hard_coral_composition(photo_transect::DataFrame)::YAXArray

Calculate the coral composition at a given ltmp location.
"""
function hard_coral_composition(photo_transect::DataFrame; stat::Symbol=:mean)::Matrix
    hard_coral_mask   = photo_transect.variable .== "HARD CORAL"
    composition_mask  = photo_transect.purpose .== "COMPOSITION"
    photo_transect_hc = photo_transect[hard_coral_mask .&& composition_mask, :]

    all_depths = unique(photo_transect_hc.series)
    depth_mask = photo_transect_hc.series .== all_depths[1]
    composition = depth_composition(photo_transect_hc[depth_mask, :]; stat=stat)

    if length(all_depths) == 1
        composition = fill_missing_years!(composition)
        return composition
    end

    for srs = all_depths[2:end]
        depth_mask = photo_transect_hc.series .== srs
        composition .+= depth_composition(photo_transect_hc[depth_mask, :]; stat=stat)
    end

    # Average composition across depths
    composition ./= length(all_depths)
    composition = fill_missing_years!(composition)

    return composition
end

"""
    location_composition_stat(photo_transect::DataFrame; stat=:mean)::YAXArray

Constuct a YAXArray for the given statistic contained in the dataframe.
"""
function location_composition_stat(photo_transect::DataFrame; stat=:mean)::YAXArray
    props::Dict{String, Any} = Dict(
        "unit" => "proportion",
        "name" => "composition " * String(stat),
        "desc" => "hard coral composition description",
    )
    dims::Tuple = (
        Dim{:timesteps}(1992:2025),
        Dim{:taxa}(ADRIA_TAXA)
    )
    return YAXArray(
        dims,
        hard_coral_composition(photo_transect; stat=stat),
        props
    )
end

"""
    location_composition_dataset(photo_transect::DataFrame)::Dataset

Construct a dataset containing the lower, mean, median and upper variables of coral
composition transformed to match C~Scape/ADRIAmod functional groups.
"""
function location_composition_dataset(photo_transect::DataFrame)::Dataset
    var_names = [:lower, :mean, :median, :upper]
    vars = Tuple(
        stat => location_composition_stat(photo_transect; stat=stat) for stat in var_names
    )
    properties::Dict{String, Any} = Dict(
        "creation data" => Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"),
        "desc" => "Hard coral composition statistics"
    )
    return Dataset(; properties=properties, vars...)
end

"""
    multiple_location_stat(photo_transects, lats::Vector{Float64}, lons::Vector{Float64}, canonical_gpkg::DataFrame; stat=:mean)::YAXArray

Create the YAXArray for a single statistic.
"""
function multiple_location_stat(
    photo_transects,
    lats::Vector{Float64},
    lons::Vector{Float64},
    canonical_gpkg::DataFrame;
    stat=:mean
)::YAXArray
    # Get the unique ids for each for location by finding the closest reef polygon
    unique_ids::Vector{String} = get_unique_id.(lats, lons, Ref(canonical_gpkg))
    timesteps = 1992:2025

    props::Dict{String, Any} = Dict(
        "unit" => "proportion",
        "name" => "composition " * String(stat),
        "desc" => "hard coral cover composition for each location"
    )
    dims::Tuple = (
        Dim{:timesteps}(timesteps),
        Dim{:taxa}(ADRIA_TAXA),
        Dim{:location}(unique_ids)
    )

    n_timesteps = length(timesteps)
    n_taxa = length(ADRIA_TAXA)
    n_locs = length(photo_transects)

    loc_stat = YAXArray(dims, zeros(Union{Float64, Missing}, n_timesteps, n_taxa, n_locs), props)
    for (loc_idx, ) in enumerate(photo_transects)
        loc_stat[location=loc_idx] .= hard_coral_composition(photo_transects[loc_idx]; stat=stat)
    end
    return loc_stat
end

"""
    multiple_location_comparison(locs::DataFrame, canonical_gpkg::DataFrame)::Dataset

Construct a dataset of coral composition for each location present in the given dataframe.
"""
function multiple_location_comparison(
    locs::DataFrame,
    canonical_gpkg_path::String
)::Dataset
    canonical_gpkg = GDF.read(canonical_gpkg_path)
    pt_data = @showprogress desc="Requesting" map(get_photo_transect, locs.aims_reef_name)
    data_mask = (!).(isnothing.(pt_data))

    var_names = [:lower, :mean, :median, :upper]
    vars = Tuple(
        stat => multiple_location_stat(
            pt_data[data_mask],
            locs.latitude[data_mask],
            locs.longitude[data_mask],
            canonical_gpkg;
            stat=stat
        ) for stat in var_names
    )

    properties::Dict{String, Any} = Dict(
        "creation data" => Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"),
        "desc" => "Hard coral composition statistics for each location"
    )
    return Dataset(; properties=properties, vars...)
end
