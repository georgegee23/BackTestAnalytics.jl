module BackTestAnalytics

using DataFrames
using DataFramesMeta
using Dates
using TidierData
using ShiftedArrays
using StatsBase
using RollingFunctions
using Plots

export  
    
    #Performance Analytics
    returns_to_prices, returns_to_drawdowns,
    annual_return, annual_stdev, 
    annual_sharpe_ratio, downside_std, sortino_ratio,
    max_drawdown, up_capture, down_capture, overall_capture,

    #Factor Analytics
    plot_factor_distribution,

    #DataFrame Manipulations
    shift_dataframe, rollmax_dataframe, rollstd_dataframe, rowwise_percentiles, row_average,
    dict_to_rowframe, mask_dataframe, category_dataframes, percentage_change,
    rowwise_zscore,

    #Utility functions
    zscore_nonmissing,

    #Spearman Correlation Analytics
    row_spearmanr,
    row_pearsonr,
    cs_spearmanr,
    cs_pearsonr,
    rolling_cs_spearmanr,
    plot_rolling_cs_spearmanr,
    factor_decay,
    factor_decay_ratio,
    rolling_acf, 

    plot_factor_decay,


    #Quantile Analytics
    rowwise_ntiles,
    compute_quantile_returns,
    quantile_performance_table,
    quantiles_holdings_turnover,

    plot_securities_per_quantile,
    plot_quantile_growth,
    plot_quantile_drawdowns, 
    plot_performance_timeseries, 
    plot_performance_table,

    #Factor Turnover
    mean_factor_autocor,

    plot_factor_autocor 



#---------------------------------------------------------------------------------
#PERFORMANCE ANALYTICS

function returns_to_prices(returns::DataFrame)

    """
        
    Convert dataframe of returns to a dataframe of simulated prices.

        """
        
    prices = coalesce.(returns .+ 1, 1) |> 
    eachcol |> 
    x -> cumprod.(x) |> 
    x -> DataFrame(x, names(returns)) .* ifelse.(ismissing.(returns), missing, 1)
    return prices 
    
end

function returns_to_drawdowns(returns::DataFrame)

    """

    Compute drawdowns for each column in a dataframe of returns

    """

    prices = returns_to_prices(returns)
    cummax(x) = accumulate(max, x)
    cummax_df = DataFrame(cummax.(skipmissing.(eachcol(prices))), :auto)
    cummax_df =  rename(cummax_df, names(prices))
    drawdowns_df = prices ./ cummax_df
    return drawdowns_df .- 1
end

function annual_return(returns::DataFrame, periods_per_year::Int)

    """

    Compute annualized return of each column in a DataFrame of returns.

    """
    
    compounded_growth = returns_to_prices(returns)
    n_periods = size(compounded_growth, 1)
    ann_rets = (last.(eachcol(compounded_growth)) .^ (periods_per_year / n_periods)) .- 1
    col_names = names(compounded_growth)
    return ann_rets

end

function annual_stdev(returns::DataFrame, periods_per_year::Int)

    """

    Compute annual standard deviation of each column in a DataFrame of returns.

    """
    
    # Calculate the standard deviation for each column
    std_dev = std.(skipmissing.(eachcol(returns)))
    
    # Annualize the standard deviation
    annual_std_dev = std_dev .* sqrt(periods_per_year)
    
    # Return as a dictionary for easy column name association
    return annual_std_dev
end

function annual_sharpe_ratio(returns::DataFrame, periods_per_year::Int)

    """

    Compute annual sharpe ratio of each column in a DataFrame of returns.

    """


    return annual_return(returns, periods_per_year) ./ annual_stdev(returns, periods_per_year)
end

function downside_std(returns::DataFrame)

    """

    Compute annual downside standard deviation of each column in a DataFrame of returns.

    """
    neg_rets_bool = returns .< 0
    neg_rets = mask_dataframe(returns[2:end,:], neg_rets_bool[2:end,:])
    squared_neg_rets = neg_rets.^2
    down_std = mean.(skipmissing.(eachcol(squared_neg_rets))).^0.5
    return down_std

end

function sortino_ratio(returns::DataFrame)

    """

    Compute sortino_ration of each column in a DataFrame of returns.

    """

    down_stdev = values(downside_std(returns))
    mean_rets = mean.(skipmissing.(eachcol(returns)))
    sortino_ratios = mean_rets ./ down_stdev 
    return sortino_ratios

end

function max_drawdown(returns:: DataFrame)

    """

    Compute max drawdown for each column in a DataFrame of returns.

    """

    drawdowns = returns_to_drawdowns(returns)
    max_dds = minimum.(eachcol(drawdowns))
    return max_dds * -1

end

function down_capture(returns:: DataFrame, benchmark_returns:: Vector{Union{Float64, Missing}}, thresh_value = 0)

    """

    Compute arithmetic mean down capture for each column in a DataFrame of returns.

    """

    down_market = (benchmark_returns .< thresh_value)
    portfolio_down = @view returns[down_market, All()]
    benchmark_down = @view benchmark_returns[down_market]
    dc_ratio = mean.(eachcol(portfolio_down)) / mean(benchmark_down)
    return dc_ratio

end

function up_capture(returns:: DataFrame, benchmark_returns:: Vector{Union{Float64, Missing}}, thresh_value = 0)

    """

    Compute arithmetic mean up capture for each column in a DataFrame of returns.

    """

    up_market = (benchmark_returns .> thresh_value)
    portfolio_up = @view returns[up_market, All()]
    benchmark_up = @view benchmark_returns[up_market]
    uc_ratio = mean.(eachcol(portfolio_up)) / mean(benchmark_up)
    return uc_ratio

end

function overall_capture(returns:: DataFrame, benchmark_returns:: Vector{Union{Float64, Missing}}, thresh_value = 0)

    """

    Compute arithmetic mean overall capture for each column in a DataFrame of returns.

    """

    dc = down_capture(returns, benchmark_returns, thresh_value)
    uc = up_capture(returns, benchmark_returns, thresh_value)
    oc_ratio = uc ./ dc

    return oc_ratio

end


#---------------------------------------------------------------------------------------
#FACTOR ANALYTICS
function plot_factor_distribution(factor_score::DataFrame, dates; label::String = "Mean Factor Score")

    values = map(row -> mean(skipmissing(row)), eachrow(factor_score)) # Compute row mean
    
    p1 = Plots.plot(dates, values, 
          label = label,  
          title = "Mean Factor Values Time Series", titlefontsize=12)

    p2 = Plots.histogram(values, 
               label = label,  # Note: Corrected from "labels" to "label" for single histogram label
               title = "Histogram", titlefontsize=12)

    # Combine plots into a 2x1 subplot
    return Plots.plot(p1, p2, layout = (2, 1), size = (800,600))

end

function plot_factor_distribution(factor_score::Vector{Union{Float64, Missing}}, dates::Vector{Date}; 
    label::String = "Factor Score")
    
    values = factor_score
    p1 = Plots.plot(dates, values, 
          label = label,  
          title = "Factor Values Time Series", titlefontsize=12)

    p2 = Plots.histogram(values, 
               label = label,  # Note: Corrected from "labels" to "label" for single histogram label
               title = "Histogram", titlefontsize=12)

    # Combine plots into a 2x1 subplot
    return Plots.plot(p1, p2, layout = (2, 1), size = (800,600))

end

function plot_factor_distribution(factor_score::Vector{Float64}, dates::Vector{Date}; 
    label::String = "Factor Score")
    
    values = factor_score
    p1 = Plots.plot(dates, values, 
          label = label,  
          title = "Factor Values Time Series", titlefontsize=12)

    p2 = Plots.histogram(values, 
               label = label,  # Note: Corrected from "labels" to "label" for single histogram label
               title = "Histogram", titlefontsize=12)

    # Combine plots into a 2x1 subplot
    return Plots.plot(p1, p2, layout = (2, 1), size = (800,600))

end



#----------------------------------------------------------------------------------------
#DATAFRAME MANIPULATIONS
function category_dataframes(returns::DataFrame, categories::DataFrame)

    sector_dataframe_dict = Dict{String, DataFrame}()

    category_names = Set(categories[:, :Category])
    for cat_name in category_names

        selected_ids = @subset(categories, :Category .== cat_name)[!, "Security_ID"]
        category_rets_df = returns[:, selected_ids]

        sector_dataframe_dict[cat_name] = category_rets_df
    end
    return sector_dataframe_dict
end

function rowwise_ntiles(factors::DataFrame, n::Int)
    # Create a copy to avoid modifying the original DataFrame
    quantiles_df = deepcopy(factors)
    
    # Apply ntile function to each row
    for i in 1:size(factors,1)
        row = collect(factors[i, :])  # Convert row to vector for ntile function
        quantiles_df[i, :] = ntile(row, n)
    end
    
    return quantiles_df
end

function rowwise_percentiles(df::DataFrame)

    """ 
    
    Convert dataframe rows into rank percentile.

    """

    if isempty(df)
        return df  # Return an empty DataFrame if the input is empty
    end
    
    ntile_df = copy(df) # Create a copy to not modify the original DataFrame
    
    for (i, row) in enumerate(eachrow(ntile_df))
        # Convert each row to a vector, suitable for operations like ntile
        vector_row = collect(row)
        
        # Count non-missing values in the row
        n = count(!ismissing, vector_row)
        
        # Rank elements and divide by the number of non-missing elements,
        # which gives percentiles (1/n, 2/n, ..., n/n) for each non-missing element.
        ranks = sortperm(sortperm(filter(!ismissing, vector_row)))
        vector_row[.!ismissing.(vector_row)] .= (ranks ./ n)
        
        # Replace the row in ntile_df with the computed percentiles
        ntile_df[i, :] = vector_row
    end
    
    return ntile_df
end

function shift_dataframe(df::DataFrame; shift::Int, fill_value=missing)

    """
    Creates a new DataFrame where each column is shifted_df by the specified number of periods.

    # Arguments:
    - `df::DataFrame`: The input DataFrame to be shifted_df.
    - `lags::Int`: The number of periods to lag each column. Default is 1.
    - `fill_value`: The value to fill where data does not exist due to lagging (e.g., at the start of the series). Default is `missing`.

    # Returns:
    - A new DataFrame with shifted_df columns.

    """

    shifted_df = DataFrame()
    for col in names(df)
        shifted_df[!, col] = ShiftedArrays.lag(df[!, col], shift, default=fill_value)
    end
    return shifted_df
end

function dict_to_rowframe(dict, col_names)

    """

    Convert a dictionary to a DataFrame row-wise, where the keys are rows. 

    """

    df = DataFrame(collect(values(dict)), :auto)
    df = permutedims(df)
    df = rename(df, col_names)
    df[!, "Key"] = collect(keys(dict))
    df = sort(df, :Key)
    return df
end

function mask_dataframe(df::DataFrame, bool_df:: DataFrame)

    """

    Mask a dataframe with a boolean dataframe of the same size.

    """
    
    @assert size(df) == size(bool_df) "DataFrames must have the same dimensions"

    # Create a new DataFrame with selected values
    result = DataFrame([ifelse(bool_df[i,j], df[i,j], missing) for i in axes(df, 1), j in axes(df, 2)], names(df))
    return result
end

function rollmax_dataframe(df::DataFrame, window::Int)

    """

    Calculates the cumulative rolling maximum of each column in a DataFrame.

    **Arguments:**
    - `df::DataFrame`: The input DataFrame.
    - `window::Int`: The size of the rolling window.

    **Returns:**
    - `DataFrame`: A new DataFrame with the rolling maximum for each column.

    **Note:**
    - This function assumes that larger values are considered "maximum".
    - Missing values will be propagated; if you want to skip missings, ensure to clean your data beforehand or handle them within the function.
    
    """


    rollmax_df = DataFrame()
    for col in names(df)
        rollmax_df[!, col] = rollmax(df[!,col], window)
    end
    return rollmax_df
end

function rollstd_dataframe(df::DataFrame, window::Int)

    """

    Calculates the rolling standard deviation of each column in a DataFrame.

    **Arguments:**
    - `df::DataFrame`: The input DataFrame.
    - `window::Int`: The size of the rolling window.

    **Returns:**
    - `DataFrame`: A new DataFrame with the rolling standard deviation for each column.

    """

    roll_df = DataFrame()
    for col in names(df)
        roll_df[!, col] = rolling(std, df[!,col], window; padding=missing)
    end
    return roll_df
end

function row_average(df::DataFrame)

    """

    Compute row averages of a DataFrame. 

    """
    vectors = collect.(skipmissing.(eachrow(df)))
    r_means = [isempty(v) ? missing : mean(v) for v in vectors]
    return r_means

end


function percentage_change(df::DataFrame, window::Int = 1)


    """

    Calculate the percentage change for each column in a DataFrame over a specified window.

    # Arguments
    - `df::DataFrame`: The input DataFrame containing numerical data where percentage changes are to be calculated.
    - `window::Int=1`: The number of periods to look back for calculating the percentage change. 
    Default is 1, meaning the change is calculated from one period to the next.

    # Returns
    - `DataFrame`: A new DataFrame where each column represents the percentage change of the corresponding column in `df`.
    - The first `window` rows will be `missing` because there isn't enough data to calculate the percentage change.
    - If the previous value in the window is `missing` or zero, the result for that entry will also be `missing`.

    # Throws
    - `ArgumentError`: If `window` is less than 1.

    """


    if window < 1
        throw(ArgumentError("Window size must be at least 1"))
    end

    # Create a new DataFrame with the same structure but allowing missing
    result_df = DataFrame([Vector{Union{Missing, Float64}}(undef, size(df, 1)) for _ in 1:size(df, 2)], names(df))
    
    # Set the first `window` rows to missing
    result_df[1:window,:] .= missing
    
    for col in names(df)
        data = convert(Vector{Union{Missing, Float64}}, df[!, col])
        
        # Calculate windowed percentage change
        pct_change = map(window + 1:length(data)) do i
            if ismissing(data[i - window]) || data[i - window] == 0
                missing
            else
                (data[i] - data[i - window]) / data[i - window]
            end
        end
        
        # Place the calculated percentage changes into the DataFrame
        result_df[(window + 1):end, col] = pct_change
    end

    return result_df
end


function rowwise_zscore(dataframe::DataFrame)::DataFrame

    """

    Transforms each row of a DataFrame into z-scores, handling missing data.

    """
    # Assuming sp_riskadj_momentum_score is your DataFrame
    zscore_df = deepcopy(dataframe)
    for idx in 1:size(zscore_df, 1)
        row_vector = collect(eachrow(zscore_df)[idx])
    
        if !all(ismissing, row_vector)
            zscore_df[idx, :] = zscore_nonmissing(row_vector)
        else
            # If all values are missing, keep them as is
            continue
        end
    end

    return zscore_df
end


#----------------------------------------------------------------------------
#Utility functions

function zscore_nonmissing(values_vec::Vector{Union{T, Missing}} where T<:Union{Float64, Int})::Vector{Union{Missing, Float64}}

    """

    Compute the z-score for each element in the vector `values_vec`, handling missing values.

    This function:
    - Ignores missing values for calculation of mean and standard deviation.
    - Returns a vector of the same length as `values_vec` where non-missing values are transformed into z-scores.
    - Missing values in the input vector remain as missing in the output.

    # Arguments
    - `v::Vector{Any}` : Vector containing numeric values and potentially missing values.

    # Returns
    - `Vector{Union{Missing, Float64}}`: Vector where each non-missing value has been converted to its z-score.

    """

    # Filter out missing values
    non_missing = skipmissing(values_vec)
    
    # Convert to Vector for calculations
    nonmissing_vec = collect(non_missing)
    
    # Check if there are enough non-missing values to compute z-scores
    if length(nonmissing_vec) < 2
        error("Need at least two non-missing values to compute z-scores.")
    end
    
    # Compute mean and standard deviation
    μ = mean(nonmissing_vec)
    σ = std(nonmissing_vec)
    
    # Compute z-scores for all values including missing ones
    zscores_vec = map(values_vec) do x
        if ismissing(x)
            missing
        else
            (x - μ) / σ
        end
    end

    return zscores_vec
end


#----------------------------------------------------------------------------
#SPEARMAN CORRELATION ANALYTICS

function row_spearmanr(row1, row2)

    """

    Compute the spearman correlation between two dataframe rows.
    
    """
    
    # Ensure we are working with vectors for easier indexing
    row1 = collect(row1)
    row2 = collect(row2)

    # Check if the lengths match
    @assert length(row1) == length(row2) "Input rows must have the same length"

    # Create a boolean mask for non-missing pairs
    valid_pairs = .!ismissing.(row1) .& .!ismissing.(row2)

    # Filter out missing values and convert to Float64 for correlation computation
    x = Float64.(@view row1[valid_pairs])
    y = Float64.(@view row2[valid_pairs])

    # Check if there's enough data to compute correlation
    if length(x) < 2
        return NaN  # Not enough data points for a meaningful correlation
    end

    # Compute Spearman rank correlation
    return StatsBase.corspearman(x, y)
end

function cs_spearmanr(factors::DataFrame, returns::DataFrame)

    """

    Compute the cross-sectional (row-wise) spearman correlation between two dataframes. 

    """

    factors_size = size(factors)
    @assert factors_size == size(returns) "DataFrames must have the same dimensions"

    correlations = [row_spearmanr((@view factors[i, :]), (@view returns[i, :])) for i in 1:factors_size[1]]
    return mean(correlations)
end

function rolling_cs_spearmanr(factors::DataFrame, returns::DataFrame, rolling_window::Int = 12)
    
    """
    
    Compute the rolling cross-sectional (rowwise) spearman correlation between two dataframes.
    
    """

    rolling_spearmanr = Dict()
    for start_idx in 1:(size(factors,1) - rolling_window)

        end_idx = start_idx + rolling_window - 1

        w_spearmanr = cs_spearmanr(factors[start_idx:end_idx,:], returns[start_idx:end_idx,:])
        rolling_spearmanr[end_idx] = w_spearmanr

    end

    return sort(rolling_spearmanr)
end


function plot_rolling_cs_spearmanr(factors::DataFrame, returns::DataFrame, dates::Vector{Date}, rolling_window::Int = 12)

    """

    Plot the rolling cross-sectional (rowwise) spearman correlation between two dataframes.


    """

    rolling_spearmanr = rolling_cs_spearmanr(factors, returns, rolling_window)
    corrs = sort(rolling_spearmanr) |> values |> collect

    return Plots.bar(dates, corrs, title = "Rolling Spearman Correlation (Window Size: $rolling_window)", size = (800,400), label = "")

end

function row_pearsonr(row1, row2)

    """

    Compute the pearson correlation between two dataframe rows.
    
    """
    
    # Ensure we are working with vectors for easier indexing
    row1 = collect(row1)
    row2 = collect(row2)

    # Check if the lengths match
    @assert length(row1) == length(row2) "Input rows must have the same length"

    # Create a boolean mask for non-missing pairs
    valid_pairs = .!ismissing.(row1) .& .!ismissing.(row2)

    # Filter out missing values and convert to Float64 for correlation computation
    x = Float64.(@view row1[valid_pairs])
    y = Float64.(@view row2[valid_pairs])

    # Check if there's enough data to compute correlation
    if length(x) < 2
        return NaN  # Not enough data points for a meaningful correlation
    end

    # Compute Spearman rank correlation
    return Statistics.cor(x, y)
end

function cs_pearsonr(factors::DataFrame, returns::DataFrame)

    """

    Compute the cross-sectional (row-wise) pearson correlation between two dataframes. 

    """

    factors_size = size(factors)
    @assert factors_size == size(returns) "DataFrames must have the same dimensions"

    correlations = [row_pearsonr((@view factors[i, :]), (@view returns[i, :])) for i in 1:factors_size[1]]
    return mean(correlations)
end



function factor_decay(factors::DataFrame, returns:: DataFrame, max_shift::Int)

    """
    Compute the decay of the Spearman correlation between lagged factor data and returns.

    # Arguments
    - factors::DataFrame: A DataFrame containing factor data. Each column represents a different factor.
    - returns::DataFrame: A DataFrame containing return data, corresponding in time to the factors.
    - max_lag::Int: The maximum number of lags to calculate correlations for.

    # Returns
    - Dict{Int, Float64}: A dictionary where keys are lag periods and values are the average 
        Spearman rank correlation coefficients for that lag.
    """

    
    factor_decay_corr = Dict{Int, Float64}()

    for shift in 1:max_shift

        factors_lagged = shift_dataframe(factors; shift = shift)[shift+1:end,:]
        spearmanR = cs_spearmanr(factors_lagged, returns[shift+1:end,:])

        factor_decay_corr[shift] = spearmanR
    end

    return factor_decay_corr

end

function plot_factor_decay(factors::DataFrame, returns:: DataFrame, max_shift::Int; kwargs...)

    """
    Bar plot of the decay of the Spearman correlation between lagged factor data and returns.

    # Arguments
    - factors::DataFrame: A DataFrame containing factor data. Each column represents a different factor.
    - returns::DataFrame: A DataFrame containing return data, corresponding in time to the factors.
    - max_lag::Int: The maximum number of lags to calculate correlations for.

    # Returns
    - Dict{Int, Float64}: A dictionary where keys are lag periods and values are the average 
        Spearman rank correlation coefficients for that lag.
    """

    decay_dict = factor_decay(factors, returns, max_shift)

    periods_shift = collect(keys(sort(decay_dict)))
    corr_sr = collect(values(sort(decay_dict)))

    return Plots.bar(periods_shift, corr_sr, label = "", title = "Factor Decay")
end

function factor_decay_ratio(factors::DataFrame, returns:: DataFrame, max_lag::Int)
    
    """

    Calculate the ratio of mean to standard deviation of Spearman correlations over different lags.

    # Arguments
    - factors::DataFrame: A DataFrame containing factor data. Each column represents a different factor.
    - returns::DataFrame: A DataFrame containing return data, corresponding in time to the factors.
    - max_lag::Int: The maximum number of lags to calculate correlations for.

    # Returns
    - Float64: The decay ratio, which is the mean of correlation coefficients divided by their standard deviation.

    """
    
    decay_dict = factor_decay(factors, returns, max_lag)
    corr = values(decay_dict)
    mean_corr = mean(corr)
    std_corr = std(corr)

    decay_ratio = mean_corr / std_corr

    return decay_ratio
end



#-------------------------------------------------------------------------------------
#QUANTILE ANALYTICS


function compute_quantile_returns(quantiles::DataFrame, returns::DataFrame)

    """

    Compute returns for the given quantiles. 

    Make sure quantiles are lagged. 

    """

    @assert size(quantiles) == size(returns) "DataFrames must have the same dimensions"

    n_quantiles = maximum(skipmissing(quantiles[1,:]))
    quantile_bool = DataFrame()
    quantile_returns_dataframe =  DataFrame()

    for q in 1:n_quantiles

        quantile_bool = .!ismissing.(quantiles) .& (quantiles .== q)
        masked_df = mask_dataframe(returns, quantile_bool)
        q_name = "Q"*string(Int(q))
        quantile_returns_dataframe[!, q_name] = row_average(masked_df)
    end

    return quantile_returns_dataframe
end

function quantile_performance_table(quantile_returns::DataFrame, benchmark_returns::Vector{Union{Float64, Missing}}; periods_per_year::Int)

    """

    Compute table with summary performance statistics for factor quantiles. 

    """    

    @assert size(quantile_returns, 1) == size(benchmark_returns,1) "Quantile returns and benchmark row counts do not match."

    quantile_names = names(quantile_returns)
    annual_returns = annual_return(quantile_returns, periods_per_year)
    annual_std = annual_stdev(quantile_returns, periods_per_year)
    sharpe_ratio = annual_sharpe_ratio(quantile_returns, periods_per_year)
    sortino_ratios = sortino_ratio(quantile_returns)
    max_dds = max_drawdown(quantile_returns)
    uc_ratio = up_capture(quantile_returns, benchmark_returns, 0)
    dc_ratio = down_capture(quantile_returns, benchmark_returns, 0)
    oc_ratio = overall_capture(quantile_returns, benchmark_returns, 0)

    stats_names = ["Annual Return", "Annual StDev", "Sharpe Ratio", "Sortino Ratio", "Max Drawdowns", 
    "Down Capture", "Up Capture", "Overall Capture"]

    summary_stats_table = DataFrame([annual_returns, annual_std, sharpe_ratio, sortino_ratios, max_dds, 
    dc_ratio, uc_ratio, oc_ratio], :auto)
    summary_stats_table = permutedims(summary_stats_table) .* 100
    summary_stats_table = rename!(summary_stats_table, quantile_names)

    
    summary_stats_table[!, "Stat"] = stats_names
    summary_stats_table = summary_stats_table[:, vcat("Stat", quantile_names)]

    return summary_stats_table

end


function quantile_turnover(quantiles::DataFrame, q::Int, window::Int = 12)

    """
    Compute the mean rolling turnover of holdings for a given quantile.

    Parameters:
    - quantiles: DataFrame containing quantile assignments
    - q: The quantile number to analyze
    - window: The number of periods to compute rolling holdings turnover (default: 12)

    Returns:
    - Mean rolling holdings turnover for the specified quantile and period.

    """
    if !(q in unique(skipmissing(Matrix(quantiles))))
        throw(ArgumentError("Specified quantile $q not found in the data"))
    end

    n_rows = nrow(quantiles)
    window_hlds_turnover = zeros(Float64, n_rows - window)

    for idx in 1:n_rows - window

        beg_holdings = quantiles[idx,:] |> collect |> row -> row .== q
        end_holdings = quantiles[idx+window,:] |> collect |> row -> row .== q
        n_common_holdings = (beg_holdings .& end_holdings) |> skipmissing |> sum
        n_beg_holdings = beg_holdings |> skipmissing |> sum
        holdings_turnover = 1 - (n_common_holdings / n_beg_holdings)

        window_hlds_turnover[idx] = holdings_turnover

    end

    mean_holdings_turnover = mean(window_hlds_turnover)

    return mean_holdings_turnover
end

function quantiles_holdings_turnover(quantiles::DataFrame, window::Int = 12)

    """
    Compute the turnover of holdings for all quantiles.

    Parameters:
    - quantiles: DataFrame containing quantile assignments
    - window: The number of periods to compute rolling holdings turnover (default: 12)

    Returns:
    - Mean holdings turnover for all the quantiles in the given period.

    """

    n_quantiles = quantiles[1,:] |> skipmissing |> maximum |> Int
    q_dict = Dict()

    for q in 1:n_quantiles

        q_dict[q] = quantile_turnover(quantiles, q, window)

    end

    return q_dict

end

function plot_securities_per_quantile(quantiles::DataFrame, dates; kwargs...)

    n_securities_per_quantile = sum.(skipmissing.(eachrow(quantiles .== 1)))
    p = Plots.plot(dates, n_securities_per_quantile; kwargs...)
    return p
end

function plot_quantile_growth(quantile_returns::DataFrame, dates; kwargs...)

    quantile_names = names(quantile_returns) |> permutedims 
    prices = returns_to_prices(quantile_returns)

    return Plots.plot(dates, Matrix(prices), label = quantile_names; kwargs...)
end

function plot_quantile_drawdowns(quantile_returns::DataFrame, dates; kwargs...)

    quantile_names = names(quantile_returns) |> permutedims
    drawdowns = returns_to_drawdowns(quantile_returns)

    return Plots.plot(dates, Matrix(drawdowns), labels = quantile_names; kwargs...)
end

function plot_performance_timeseries(quantile_returns::DataFrame, dates::Vector{Date})
    
    p1 = plot_quantile_growth(quantile_returns, dates)
    p2 = plot_quantile_drawdowns(quantile_returns, dates)

    # Combine plots into a 2x1 subplot
    return Plots.plot(p1, p2, layout = (2, 1), size = (800,500))

end

function plot_performance_table(table::DataFrame; kwargs...)

    quantile_names = names(table)[2:end]
    bar_width=0.3

    p1 = Plots.bar(quantile_names, collect(table[1,2:end]), labels = "Annual Return", bar_width = bar_width)
    p2 = Plots.bar(quantile_names, collect(table[2,2:end]), labels = "Annual StDev", bar_width = bar_width)
    p3 = Plots.bar(quantile_names, collect(table[3,2:end]), labels = "Sharpe Ratio", bar_width = bar_width)
    p4 = Plots.bar(quantile_names, collect(table[5,2:end]), labels = "Max Drawdown", bar_width = bar_width)
    p5 = Plots.bar(quantile_names, collect(table[6,2:end]), labels = "Up Capture", bar_width = bar_width)
    p6 = Plots.bar(quantile_names, collect(table[7,2:end]), labels = "Down Capture", bar_width = bar_width)

    return Plots.plot(p1, p2, p3, p4, p5, p6, layout = (3, 2), size = (800,600), legend=:outertop)
end


#---------------------------------------------------------------------------
# Factor Turnover (Autocorrelation)


function mean_factor_autocor(factors::DataFrame, lags::AbstractVector{<:Integer}; kwargs...)
    
    """
    Compute the mean autocorrelation of security factor scores.

    Parameters:
    - `factors`: DataFrame where each column represents a security factor.
    - `lags`: Vector of integers specifying the lags for which to compute the ACF.
    - `kwargs...`: Additional keyword arguments passed to `autocor`.

    Returns:
    - A vector of mean autocorrelations for each lag.

    Note: 
    - Columns with too few non-missing values or where all values are missing are skipped.
    - The function uses `StatsBase.autocor` for calculating the ACF.
    """

    acf_dict = Dict{Int, Vector{Float64}}()

    for (idx, security) in enumerate(eachcol(factors))
        security_vec = Vector{Float64}(filter(!ismissing, security))

        if length(security_vec) > maximum(lags)
            security_vec_acf = StatsBase.autocor(security_vec, lags; kwargs...)
            
            if !any(isnan, security_vec_acf) 
                acf_dict[idx] = security_vec_acf
            end
        end
    end

    if isempty(acf_dict)
        @warn "No valid columns for ACF calculation."
        return Float64[]
    end

    acf_matrix = hcat(values(acf_dict)...)
    mean_acf_vector = mean(acf_matrix, dims=2)

    return mean_acf_vector
end

function plot_factor_autocor(factors::DataFrame, lags::AbstractVector{<:Integer}; kwargs...)

    """ 
    
    Plot the mean autocorrelation of security factor scores.

    """

    mean_acf_vector = mean_factor_autocor(factors, lags; kwargs...)
    
    p = Plots.bar(lags, mean_acf_vector, 
        size = (800, 300), 
        label = "Mean Autocorrelation",
        title = "Factor Autocorrelation",
        xlabel = "Lag",
        ylabel = "Autocorrelation",
        kwargs...)

    return p
end

function rolling_acf(factors::DataFrame, acf_window::Int, acf_lag::Int=2)

    """ 
    
    Compute the rolling autocorrelation for a given window.

    """

    acf1_mean = Dict()

    for idx in 1:(size(factors,1) - acf_window)

        start_idx = idx
        end_idx = idx + acf_window - 1

        w_factors =  factors[start_idx:end_idx,:]
        acf1 = mean_factor_autocor(w_factors , 0:acf_lag)[acf_lag]

        acf1_mean[idx] = acf1

    end

    return sort(acf1_mean)

end




############ END OF MODULE #####################################################################################################
end # module BackTestAnalytics


