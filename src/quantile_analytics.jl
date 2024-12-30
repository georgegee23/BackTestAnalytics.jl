
########################################## BackTestAnalytics Quantile Analysis ###########################################################


####### QUANTILE ANALYSIS ##########################################################

function quantile_return(quantiles_ts::TimeArray, returns_ts::TimeArray, quantile::Any)
    """
    Calculate the mean return for a specific quantile.

    Parameters:
    - quantiles_ts: TimeArray of quantile assignments. Note quantiles should be lagged to n+1 to align with approriate returns. 
    - returns_ts: TimeArray of returns
    - quantile: The specific quantile to calculate returns for

    Returns:
    - A TimeArray with mean returns for the specified quantile
    """
    @assert timestamp(quantiles_ts) == timestamp(returns_ts) "TimeArrays must have matching timestamps"
    
    quantiles_mtx = values(quantiles_ts)
    returns_mtx = values(returns_ts)
    
    function quantile_rowmean(q_row, r_row, qtile) # row mean of non-nan values
        relevant_returns = r_row[q_row .== qtile]
        if isempty(relevant_returns)
            return NaN  # or another appropriate value to indicate no data
        else
            return mean(filter(!isnan, relevant_returns))
        end
    end
    
    quantile_rets_vec = [quantile_rowmean(q_row, r_row, quantile) for (q_row, r_row) in zip(eachrow(quantiles_mtx), eachrow(returns_mtx))]
    
    return TimeArray(timestamp(quantiles_ts), quantile_rets_vec, ["Q$quantile"])
end

function compute_quantiles_returns(quantiles_ta::TimeArray, returns_ta::TimeArray, n_quantiles::Int)
    """
    Compute returns for all quantiles.

    Parameters:
    - quantiles_ta: TimeArray of quantile assignments
    - returns_ta: TimeArray of returns
    - n_quantiles: Number of quantiles

    Returns:
    - A TimeArray with returns for all quantiles
    """
    @assert timestamp(quantiles_ta) == timestamp(returns_ta) "TimeArrays must have matching timestamps"

    # Pre-allocate array to store results
    results = Vector{TimeArray}(undef, n_quantiles)

    # Compute returns for each quantile
    for q in 1:n_quantiles
        results[q] = quantile_return(quantiles_ta, returns_ta, q)
    end

    # Merge all results into a single TimeArray
    quan_rets_ts = merge(results...)

    return quan_rets_ts
end


function quantile_turnover(quantile_ta::TimeArray, target_quantile::Number)

    """
    Calculate the turnover for securities at a specific quantile over time.

    # Arguments
    - `quantile_ta::TimeArray`: A TimeArray where each value represents the quantile 
        to which a security belongs at each time point.
    - `target_quantile::Number`: The specific quantile for which turnover is calculated.
    
    # Returns
    - A `TimeArray` containing:
        - **Turnover**: The fraction of securities at `target_quantile` that changed 
        from the previous period.
        - **NoChange**: Count of securities at `target_quantile` that did not change 
        from the previous period.
        - **Total**: Total count of securities at `target_quantile` for each period.
    
    # Notes
    - This function assumes that `quantile_ta` is sorted by time and that the time 
        series data starts from the second row due to lagging.
    - If there are no securities at `target_quantile` for any given period, this will 
        result in division by zero for that period's turnover calculation, which 
        should be handled externally or by ensuring data integrity before function call.
    """    

    if size(quantile_ta, 1) < 2
        throw(ArgumentError("TimeArray must have at least 2 time points"))
    end

    # Filtering for the target quantile, excluding first row to align with lag
    q_target_ta = (quantile_ta .== target_quantile)[2:end]

    # Lag the quantile TimeArray by one period
    quantile_ta_lag = lag(quantile_ta, 1)

    # Remove the first row to match lengths with the lagged TimeArray
    quantile_ta = quantile_ta[2:end]

    # Identify where there's no change for specified quantile target
    no_change = (quantile_ta .== quantile_ta_lag) .& q_target_ta

    # Sum up no changes for each time period
    no_change_count = sum(no_change, dims=2)

    # Count total valid entries per time period at the target quantile
    total_securities = sum(q_target_ta, dims=2)

    # Calculate turnover
    turnover_ta = 1 .- (no_change_count ./ total_securities)
    turnover_ta = hcat(turnover_ta, no_change_count, total_securities)
    turnover_ta = TimeSeries.rename(turnover_ta, ["Turnover", "NoChange", "Total"])

    return turnover_ta
end

function quantiles_turnover(quantile_ta::TimeArray)

    """
    Calculate the turnover for each quantile from 1 to the maximum quantile present in the `TimeArray`.

    # Arguments
    - `quantile_ta`: A `TimeArray` containing quantile data.

    # Returns
    - A `TimeArray` where each column represents the turnover for a specific quantile, 
      renamed with quantile names like "Q1", "Q2", etc.

    # Throws
    - `ArgumentError` if the `TimeArray` has fewer than 2 time points.
    """

    if size(quantile_ta, 1) < 2
        throw(ArgumentError("TimeArray must have at least 2 time points"))
    end
    
    max_quantile = values(quantile_ta) |> x -> filter(!isnan, x) |> maximum
    turnover_ta = reduce(merge, [quantile_turnover(quantile_ta, q)["Turnover"] for q in 1:max_quantile])

    quantile_names = ["Q"*string(Int(i)) for i in 1:max_quantile]
    turnover_ta = TimeSeries.rename(turnover_ta, quantile_names)
    return turnover_ta
end

function total_quantiles_turnover(quantile_ta::TimeArray)
    """
    Calculate the turnover of quantiles for each time period in a TimeArray.

    # Arguments
    - `ta::TimeArray`: A TimeArray where each column represents a security or asset, 
                       and each row corresponds to a time point.
    
    # Returns
    `TimeArray` containing:
        - **Turnover**: The fraction of securities at `quantile_ta` that changed 
        from the previous period.
        - **NoChange**: Count of securities at `quantile_ta` that did not change 
        from the previous period.
        - **Total**: Total count of securities at `quantile_ta` for each perio
    
    # Notes
    - Turnover is calculated as 1 minus the ratio of unchanged securities to the total 
      number of securities with valid entries for that period.
    - If there are less than two time points, an `ArgumentError` is thrown since turnover 
      requires at least two periods to be computed.
    """
    
    if size(quantile_ta, 1) < 2
        throw(ArgumentError("TimeArray must have at least 2 time points"))
    end

    # Lag the quantile TimeArray by one period
    quantile_ta_lag = lag(quantile_ta, 1)

    # Remove the first row to match lengths with the lagged TimeArray
    quantile_ta = quantile_ta[2:end]

    # Identify where there's no change
    no_change = quantile_ta .== quantile_ta_lag

    # Sum up changes for each time period
    no_change_count = sum(no_change, dims=2)

    # Count total valid entries per time period
    total_securities = sum(.!isnan.(quantile_ta), dims=2)

    # Calculate turnover
    turnover_ta = 1 .- no_change_count ./ total_securities
    turnover_ta = hcat(turnover_ta, no_change_count, total_securities)
    turnover_ta = TimeSeries.rename(turnover_ta, ["Turnover", "NoChange", "Total"])

    return turnover_ta
end


function quantile_performance_table(quantile_returns::TimeArray, benchmark_returns::TimeArray; thresh_value::Number = 0, periods_per_year::Int)

    """
    Compute table with summary performance statistics for factor quantiles.

    Parameters:
    - quantile_returns: TimeArray containing returns for each quantile
    - benchmark_returns: TimeArray containing benchmark returns
    - thresh_value: Threshold value for down markets (default: 0)
    - periods_per_year: Number of periods in a year 

    Returns:
    - DataFrame with performance metrics for each quantile
    """   

    @assert size(quantile_returns, 1) == size(benchmark_returns,1) "Quantile returns and benchmark row counts do not match."

    quantile_names = colnames(quantile_returns)
    annual_returns = annual_return(quantile_returns, periods_per_year)
    annual_std = annual_stdev(quantile_returns, periods_per_year)
    sharpe_ratio = annual_sharpe_ratio(quantile_returns, periods_per_year)
    sortino_ratios = sortino_ratio(quantile_returns, thresh_value)
    max_dds = max_drawdown(quantile_returns)
    uc_ratio = up_capture(quantile_returns, benchmark_returns, thresh_value)
    dc_ratio = down_capture(quantile_returns, benchmark_returns, thresh_value)
    oc_ratio = overall_capture(quantile_returns, benchmark_returns, thresh_value)

    stats_names = ["Annual Return", "Annual StDev", "Sharpe Ratio", "Sortino Ratio", "Max Drawdowns", 
    "Down Capture", "Up Capture", "Overall Capture"]

    summary_stats_table = DataFrame([annual_returns, annual_std, sharpe_ratio, sortino_ratios, max_dds, 
    dc_ratio, uc_ratio, oc_ratio], :auto)
    summary_stats_table = permutedims(summary_stats_table) .* 100
    summary_stats_table = DataFrames.rename(summary_stats_table, quantile_names)


    summary_stats_table[!, "Stat"] = stats_names
    summary_stats_table = select(summary_stats_table, :Stat, quantile_names...)

    return summary_stats_table

end






function quantile_chg(perf_table::DataFrame)

    tb = permutedims(perf_table)

    tb = tb[2:end,:] 
    tb = DataFrames.rename(tb, perf_table.Stat)

    vecs_chg = tb .- shift_dataframe(tb, shift = 1) |> eachcol .|> col -> filter(!ismissing, col)

    mu_chg =  vecs_chg .|> mean
    std_chg = vecs_chg .|> std
    ratio_chg = mu_chg ./ std_chg

    results = DataFrame(:MeanChg => mu_chg, :StdChg => std_chg, :Ratio => ratio_chg, :Stat => q_perf_table.Stat)
    results = results[:, [:Stat, :MeanChg, :StdChg, :Ratio]]

    return results

end