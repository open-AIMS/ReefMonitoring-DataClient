using CSV, DataFrames, HTTP, JSON

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
function get_reef_info()
    resp = HTTP.request(
        "GET",
        "https://api.aims.gov.au/data-v2.0/10.25845/5c09bc4ff315c/reef"
    )
    if resp.status != 200
        throw(HTTP.StatusError(
            resp.status,
            "GET",
            "https://api.aims.gov.au/data-v2.0/10.25845/5c09bc4ff315c/reef",
            resp
        ))
    end
    resp_dicts = JSON.parse(String(resp.body))

    return dicts_to_dataframe(resp_dicts)
end

function get_photo_transect(name::String, key="median")
    encoded_arg = HTTP.URIs.escapeuri(name)
    resp = HTTP.request("GET", "https://api.aims.gov.au/data-v2.0/10.25845/5c09bc4ff315c/data?domain_name=$(encoded_arg)&domain_category=reef&data_type=photo-transect")
    if resp.status != 200
        throw(HTTP.StatusError(
            resp.status,
            "GET",
            "https://api.aims.gov.au/data-v2.0/10.25845/5c09bc4ff315c/data?domain_name=$(encoded_arg)&domain_category=reef&data_type=photo-transect",
            resp
        ))
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

function get_manta_tow(name::String)
    encoded_arg = HTTP.URIs.escapeuri(name)
    resp = HTTP.request("GET", "https://api.aims.gov.au/data-v2.0/10.25845/5c09bc4ff315c/data?domain_name=$(encoded_arg)&domain_category=reef&data_type=manta")
    if resp.status != 200
        throw(HTTP.StatusError(
            resp.status,
            "GET",
            "https://api.aims.gov.au/data-v2.0/10.25845/5c09bc4ff315c/data?domain_name=$(encoded_arg)&domain_category=reef&data_type=photo-transect",
            resp
        ))
    end
    if length(resp.body) == 0
        return nothing
    end
    resp_dicts = JSON.parse(String(resp.body))
    return dicts_to_dataframe(resp_dicts)
end

function get_all_cover()
    nms = get_reef_names()
    means = []
    medians = []
    lower = []
    upper = []
    r_names = []
    for nm in nms.reef_names
        @info "Requesting: $(nm)"
        tmp_m, tmp_med, tmp_l, tmp_u = get_location_cover(nm)
        if tmp_m == 0.0
            @info "$(nm): none found"
            continue
        end
        push!(means, tmp_m)
        push!(medians, tmp_med)
        push!(lower, tmp_l)
        push!(upper, tmp_u)
        push!(r_names, nm)
    end
    return DataFrame(reef_name=r_names, mean=means, median=medians, lower=lower, upper=upper)
end
