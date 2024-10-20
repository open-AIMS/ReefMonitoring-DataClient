module ReefMonitoring

include("endpoints.jl")
include("processing.jl")

# GET endpoints
export
    get_reef_info,
    get_photo_transect,
    get_manta_tow

# Data formatting methods
export
    location_composition_dataset,
    multiple_location_comparison

end
