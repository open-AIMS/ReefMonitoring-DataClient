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

function yr_mask(all_yr, subs)
    return [yr in subs for yr in all_yr]
end

function make_data_frame(coral_dicts; key="median")::DataFrame
    sp_names = unique(get.(coral_dicts, "reefpage_category", "No Name"))
    sp_years = sort(unique(get.(coral_dicts, "report_year", 0)))
    ret = DataFrame(zeros(Float64, length(sp_years), length(sp_names)+1), [:Year, Symbol.(sp_names)...])
    ret[!, :Year] .= sp_years
    for nm in sp_names
        mask = get.(coral_dicts, "reefpage_category", "No Name") .== nm
        mns = get.(coral_dicts[mask], key, -1.0)
        yrs = get.(coral_dicts[mask], "report_year", 0)
        ord = sortperm(yrs)
        ret[yr_mask(ret.Year, yrs), Symbol(nm)] .= mns[ord]
    end
    return ret
end


function get_reef_data(name::String, key="median")
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
        return nothing
    end
    resp_dicts = JSON.parse(String(resp.body))
    unique_srs = unique(get.(resp_dicts, "series", ""))
    for un_srs in unique_srs
        srs_mask = get.(resp_dicts, "series", "") .== un_srs
        hard_coral_mask = get.(resp_dicts, "variable", "") .== "HARD CORAL"
        composition_mask = get.(resp_dicts, "purpose", "") .== "COMPOSITION"
        mask = hard_coral_mask .&& composition_mask .&& srs_mask
        if count(mask) == 0
            return nothing
        end
        res = make_data_frame(resp_dicts[mask]; key=key)
        CSV.write("Outputs/Coral_Composition_$(key)_$(name)_$(un_srs).csv", res)
    end
    return nothing
end

function get_bounds_stats(coral_dicts; key="median")::Tuple{Float64, Float64, Float64, Float64}
    ind = findfirst(x->x==2008, get.(coral_dicts, "report_year", 0))
    ind = isnothing(ind) ? findfirst(x->x==2007, get.(coral_dicts, "report_year", 0)) : ind
    if isnothing(ind)
        return 0.0, 0.0, 0.0, 0.0
    end
    return get(coral_dicts[ind], "mean", -1.0),
           get(coral_dicts[ind], "median", -1.0),
           get(coral_dicts[ind], "lower", -1.0),
           get(coral_dicts[ind], "upper", -1.0)
end

function get_location_cover(name::String)
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
        return 0.0, 0.0, 0.0, 0.0
    end
    resp_dicts = JSON.parse(String(resp.body))
    hard_coral_mask = get.(resp_dicts, "variable", "") .== "HC"
    return get_bounds_stats(resp_dicts[hard_coral_mask])
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
