using CSV, DataFrames, HTTP, JSON

const BASE_URL = "https://api.aims.gov.au/data-v2.0/10.25845/5c09bc4ff315c/"

function dicts_to_dataframe(coral_dicts)::DataFrame
    json_keys = keys(coral_dicts[1])
    cols = Dict(
        str_key => get.(coral_dicts, str_key, nothing) for str_key in json_keys
    )
    return DataFrame(cols...)
end

"""
    get_reef_info()

Retrieve properties of all monitored reef.
"""
function get_reef_info()::DataFrame
    url = joinpath(BASE_URL, "reef")
    resp = HTTP.request("GET", url)
    if resp.status != 200
        throw(HTTP.StatusError(resp.status, "GET", url, resp))
    end
    resp_dicts = JSON.parse(String(resp.body))
    return dicts_to_dataframe(resp_dicts)
end

function get_photo_transect(name::String)::Union{DataFrame,Nothing}
    encoded_arg = HTTP.URIs.escapeuri(name)
    url = joinpath(BASE_URL, "data?domain_name=$(encoded_arg)&domain_category=reef&data_type=photo-transect")
    resp = HTTP.request("GET", url)
    if resp.status != 200
        throw(HTTP.StatusError(resp.status, "GET", url, resp))
    end
    if length(resp.body) == 0
        @info "exiting"
        return nothing
    end
    resp_dicts = JSON.parse(String(resp.body))
    if length(resp_dicts) == 0
        return nothing
    end
    return dicts_to_dataframe(resp_dicts)
end

function get_manta_tow(reef_name::String)::Union{DataFrame,Nothing}
    encoded_arg = HTTP.URIs.escapeuri(reef_name)
    url_target = "data?domain_name=$(encoded_arg)&domain_category=reef&data_type=manta"
    return _get_request(url_target)
end

"""
    get_disturbances(reef_name::String)::Union{DataFrame,Nothing}

Get disturbances for given reef. The disturbance types that appear on the "disturbance"
column translate to: "u" => "unknown", "s" => "storm", "m" => "multiple",
"b" => "bleaching", "d" => "disease", "c" => "cots".

# Arguments
- `reef_name` : The name of the reef to get the disturbances for.
- `aggregation` : How the data is going to be aggregated. Known valid options are "reef"
and "depth". Defaults to "reef".
"""
function get_disturbances(reef_name::String; aggregation::String="reef")::Union{DataFrame,Nothing}
    encoded_arg = HTTP.URIs.escapeuri(reef_name)
    url_target = "disturbance?reef=$encoded_arg&aggregation=$aggregation&zone=_"
    return _get_request(url_target)
end

function get_cots(reef_name::String)::Union{DataFrame,Nothing}
    encoded_arg = HTTP.URIs.escapeuri(reef_name)
    url_target = "cots-by-domain?domain_category=reef&domain_name=$(encoded_arg)"
    return _get_request(url_target)
end

"""
    function get_request(request_url::String)::Union{DataFrame,Nothing}

Perform GET request to given url and parse result to a DataFrame
"""
function _get_request(url_target::String)::Union{DataFrame,Nothing}
    request_url = joinpath(BASE_URL, url_target)
    resp = HTTP.request("GET", request_url)
    if resp.status != 200
        throw(HTTP.StatusError(resp.status, "GET", request_url, resp))
    end
    if length(resp.body) == 0
        return nothing
    end
    resp_dicts = JSON.parse(String(resp.body))
    return dicts_to_dataframe(resp_dicts)
end
