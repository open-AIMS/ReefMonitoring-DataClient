# Reef Monitoring Data Client

## Setup

```julia
julia> include("src/endpoints.jl")

julia> include("src/processing.jl")
```

## Usage

### Reef Information
```julia
# Retrieve Reef Monitoring Site information
julia> reef_info = get_reef_info()
203×8 DataFrame
 Row │ latitude  longitude  aims_reef_name                   last_surveyed  last_surveyed_decimal   a_sector  nrm_region         p_code
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ -16.0444    145.867  Agincourt Reef No.1              2023-09-01     2023.6657534246575343   CA        Wet Tropics        LTMP
```

### Photo Transects
```julia
julia> photo_transect = get_photo_transect("Agincourt Reef No.1")
720×19 DataFrame
 Row │ reef_zone  variable    upper       depth    reefpage_category  id       domain_name          series  lower       mean         project_code  purpose      domain_category  date                     median ⋯
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ _          ALGAE       0.523864        9.0  null               2488780  Agincourt Reef No.1  9.0m    0.462604    0.49206      LTMP          GROUP_LEVEL  reef             2023.6657534246575343    0.4916 ⋯

# Extract coral composition statistics
julia> photo_transect_dataset = location_composition_summary(photo_transect)
YAXArray Dataset
Shared Axes:
  (↓ timesteps Sampled{Int64} 1994:2024 ForwardOrdered Regular Points,
  → taxa      Categorical{Symbol} [:Tabular_Acropora, :Corymbose_Acropora, :Corymboses_non_Acropora, :Small_Massives, :Large_Massives] Unordered)

Variables:
lower, mean, median, upper

Properties: Dict{String, Any}("creation data" => "2024-10-17 16:36:31", "desc" => "Hard coral composition statistics")
```

### Manta Tow
```julia
julia> manta_tow = get_manta_tow("Agincourt Reef No.1")
31×19 DataFrame
 Row │ reef_zone  variable  upper     depth    reefpage_category  id       domain_name          series  lower      mean      project_code  purpose  domain_category  date                     median    report_y ⋯
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ _          HC        0.495643      9.0  null               1578817  Agincourt Reef No.1  9.0m    0.395497   0.445421  LTMP          MANTA    reef             2023.6657534246575343    0.44537          2 ⋯
```
