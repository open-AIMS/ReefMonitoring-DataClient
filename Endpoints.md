# Endpoints

This library provides a wrapper for generic Reef Monitoring location information, modelled
data from Manta Tow surveys and modelled data from photogrammetry surveys.

## Location Information

Location information is retrieved using the `get_reef_info()` function and returns a
dataframe. The columns of the dataframe are as follows

 - `aims_reef_name` - name of the reef as referred to be AIMS
 - `latitude` - latitude of reef (unknown if this is in reference to a centroid/feature)
 - `longitude` - longitude of reef (unknown if this is in reference to a centroid/feature)
 - `last_surveyed` - date the reef was last surveyed
 - `a_sector` - GBR-wide reef sector
 - `nrm_region` - natural resource management regions
 - `p_code` - project code


## Photogrammetry

Photogrammetry data can be retrieved by location using `get_photo_transect("<reef name>")`.
The columns of the dataframe returned is detailed below and are shared by manta tow results.

## Manta Tow

Manta Tow data can be retreved by location using `get_manta_tow("<reef name>")`. The columns
of the data frane returned is detailed below and are shared by photogrammetry results.

## Dataframe columns

 - `reef_zone` - empty
 - `variable` - type of cover measured (Algae, Soft Coral, Hard Coral, Other)
 - `upper` - upper bound of interval of modelled output
 - `depth` - depth of location (measured where?)
 - `reefpage_category` - Taxa/Genus of cover modelled
 - `id` - ?
 - `domain_name` - Reef Name
 - `series` - depth
 - `lower` - lower bound of interval of modelled output
 - `mean` - mean of modelled output
 - `project_code` - project code
 - `purpose` - Composition or Group Level
 - `domain_category` - ?
 - `date` - date of observation as a decimal
 - `median` - median of modelled output
 - `report_year` - year of observation
 - `data_type` - photo-transect
 - `italics` - ?
 - `shelf` - shelf position
