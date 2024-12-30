
########################################## BackTestAnalytics Information Coefficient Analysis (Correlation Analysis) ###########################################################


####### CORRELATION ANALYSIS ##########################################################

function rows_spearmanr(factors::TimeArray, returns::TimeArray)
    
    """
    Compute the cross-sectional (row-wise) Spearman correlation between two TimeArrays.

    Arguments:
    - `factors::TimeArray`: A time series of factor values.
    - `returns::TimeArray`: A time series of return values.

    Returns:
    - A TimeArray of Spearman correlation coefficients.

    Throws:
    - An error if the dimensions do not match.
    """

    factors_dims = size(factors)
    @assert factors_dims == size(returns) "TimeArrays must have the same dimensions"

    factors_mtx = values(factors)
    returns_mtx = values(returns)

    n_rows = factors_dims[1]
    correlations = Vector{Float64}(undef, n_rows)

    for idx in 1:n_rows
        x = @view factors_mtx[idx, :]
        y = @view returns_mtx[idx, :]

        valid_indices = .!isnan.(x) .& .!isnan.(y)
        x_clean = x[valid_indices]
        y_clean = y[valid_indices]

        if length(x_clean) > 1 && length(y_clean) > 1
            correlations[idx] = corspearman(x_clean, y_clean)
        else
            correlations[idx] = NaN
        end
    end

    ta_correlations = TimeArray(timestamp(factors), correlations, [:SpearmanRank_IC])

    return ta_correlations
end



function rows_pearsonr(factors::TimeArray, returns::TimeArray)
    
    """
    Compute the cross-sectional (row-wise) Spearman correlation between two TimeArrays.

    Arguments:
    - `factors::TimeArray`: A time series of factor values.
    - `returns::TimeArray`: A time series of return values.

    Returns:
    - A TimeArray of Spearman correlation coefficients.

    Throws:
    - An error if the dimensions do not match.
    """

    factors_dims = size(factors)
    @assert factors_dims == size(returns) "TimeArrays must have the same dimensions"

    factors_mtx = values(factors)
    returns_mtx = values(returns)

    n_rows = factors_dims[1]
    correlations = Vector{Float64}(undef, n_rows)

    for idx in 1:n_rows
        x = @view factors_mtx[idx, :]
        y = @view returns_mtx[idx, :]

        valid_indices = .!isnan.(x) .& .!isnan.(y)
        x_clean = x[valid_indices]
        y_clean = y[valid_indices]

        if length(x_clean) > 1 && length(y_clean) > 1
            correlations[idx] = cor(x_clean, y_clean)
        else
            correlations[idx] = NaN
        end
    end

    ta_correlations = TimeArray(timestamp(factors), correlations, [:SpearmanRank_IC])
    
    return ta_correlations
end


function spearman_factor_decay(factors::TimeArray, returns:: TimeArray, max_lags::Int)

    """

    Compute the decay of the Spearman correlation between lagged factor data and returns.

    # Arguments
    - factors::TimeArray: A TimeArray containing factor data. Each column represents a different factor.
    - returns::TimeArray: A TimeArray containing return data, corresponding in time to the factors.
    - max_lag::Int: The maximum number of lags to calculate correlations for.

    # Returns
    - Dict{Int, Float64}: A dictionary where keys are lag periods and values are the average 
        Spearman rank correlation coefficients for that lag.

    """

    @assert size(factors) == size(returns) "Factors and returns must have the same dimensions"
    
    factor_decay_corrs = Dict{Int, Float64}()

    for lag_value in 1:max_lags
        # Lag the factors
        factors_lagged = lag(factors, lag_value)
        
        # Align the returns, we drop the first 'lag_value' entries
        returns_aligned = returns[1+lag_value:end]
        
        # Compute Spearman correlation for each row
        spearman = rows_spearmanr(factors_lagged, returns_aligned)
        
        # Store the mean correlation for this lag in the dictionary
        factor_decay_corrs[lag_value] = mean(values(spearman))
    end

    return sort(factor_decay_corrs)
end


function mean_autocor(factors::TimeArray, maxlag::Int)

    """
    Compute the mean autocorrelation of security factor scores.

    Parameters:
    - factors: TimeArray where each column represents a security factor
    - maxlag: Maximum lag for which to compute the autocorrelation

    Returns:
    - A vector of mean autocorrelations for each lag
    """

    data = values(factors) |> eachcol .|> col -> filter(!isnan, col)
    clean_data = filter(v -> length(v) > maxlag, data)

    if isempty(clean_data)
        @warn "No factors with sufficient non-NaN data points"
        return fill(NaN, maxlag)
    end

    autocors_vecs = [autocor(x, 0:maxlag; demean=true) for x in clean_data]
    autocors_matrix = hcat(autocors_vecs...)
    mean_vec = autocors_matrix |> eachrow |> x -> filter.(!isnan, x) .|> mean 

    return mean_vec
end

function rolling_mean_autocor(factors::TimeArray, acf_maxlag::Int, window::Int)
    """
    Compute the rolling autocorrelation for a given window.

    This function calculates the autocorrelations up to `acf_maxlag` for each window of length
    `window` over the series provided in `factors`. 

    Arguments:
    - `factors::TimeArray`: A TimeArray object containing the time series data.
    - `acf_maxlag::Int`: The maximum lag for which to compute autocorrelations.
    - `window::Int`: The size of the window over which to compute the autocorrelations.

    Returns:
    - `TimeArray`: A TimeArray where each column represents the autocorrelation for a specific lag,
      and each row corresponds to a window.

    Note:
    - The function ensures that there are enough data points (`window` + `acf_maxlag`) before starting the computation.
    - NaN values are handled by the `mean_factors_autocor` function.
    """

    if size(factors, 1) < window + acf_maxlag
        error("TimeArray must have at least `window` + `acf_maxlag` observations.")
    end

    n_periods = size(factors, 1)
    n_windows = n_periods - window + 1
    
    # Pre-allocate matrix for results
    rolling_acfs = Matrix{Union{Float64}}(undef, n_windows, acf_maxlag)

    for start_idx in 1:n_windows
        end_idx = start_idx + window - 1
        w_factors = factors[start_idx:end_idx]
        
        try
            acfs = mean_autocor(w_factors, acf_maxlag)
            rolling_acfs[start_idx, :] = acfs[2:end]  # Exclude lag 0
        catch e
            @warn "Error calculating ACF for window starting at index $start_idx: $e"
        end
    end

    # Create TimeArray with results
    result_dates = timestamp(factors)[window:end]
    column_names = [Symbol("ACF$i") for i in 1:acf_maxlag]
    
    return TimeArray(result_dates, rolling_acfs, column_names)
end