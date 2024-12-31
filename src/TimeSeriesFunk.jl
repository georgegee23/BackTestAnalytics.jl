module TimeSeriesFunk

# Write your package code here.

########################################## Functions for TimeSeries Manipulations ###########################################################

using TimeSeries
using StatsBase
using DataFrames

export row_mean, column_mean, rowwise_ordinalrank, rowwise_competerank, rowwise_tiedrank, rowwise_denserank,
    rowwise_ordinal_pctrank, rowwise_tied_pctrank, 
    rowwise_quantiles, rowwise_tiedquantiles, rowwise_count, rowwise_countall

####### TIME ARRAY MANIPULATIONS ##########################################################

function row_mean(ta::TimeArray)

    """
    Calculate the mean of each row in a TimeArray, ignoring NaN values.

    Parameters:
    - ta: TimeArray containing data with possible NaN values

    Returns:
    - TimeArray with the same timestamps as the input, where each value represents 
      the mean of non-NaN values in the corresponding row of the input.
    """
    
    ta_mtx = values(ta)
    
    # Calculate row means, ignoring NaN values
    row_mu = [mean(filter(!isnan, row)) for row in eachrow(ta_mtx)]
    
    # Create a meaningful column name
    col_name = [:Mean]
    
    return TimeArray(timestamp(ta), row_mu, col_name)
end


function column_mean(ta::TimeArray)

    """
    Calculate the mean of each column in a TimeArray, ignoring NaN values.

    Parameters:
    - ta: TimeArray containing data with possible NaN values

    Returns:
    - DataFrame with the column name, where each value represents the mean of non-NaN values.
    """
    
    ta_mtx = values(ta)
    
    # Calculate row means, ignoring NaN values
    col_mu = [mean(filter(!isnan, col)) for col in eachcol(ta_mtx)]
    
    return DataFrame(ID = colnames(ta), Mean = col_mu)
end


function rowwise_ordinalrank(ta::TimeArray)
    """
    Compute ordinal ranks for each value in the TimeArray along rows, ignoring NaNs.

    Parameters:
    - ta: TimeArray containing numerical data.

    Returns:
    - A TimeArray with ordinal ranks computed for each row.
    """
    
    # Extract values from TimeArray
    values_matrix = values(ta)
    
    # Initialize matrix for ranks
    rank_matrix = similar(values_matrix, Float64)
    
    # Compute rowwise ordinal ranks
    for i in 1:size(values_matrix, 1)
        row = values_matrix[i, :]
        non_nan_indices = findall(!isnan, row)
        non_nan_values = row[non_nan_indices]
        
        if !isempty(non_nan_values)
            # Compute ordinal ranks for non-NaN values
            row_ranks = ordinalrank(non_nan_values)
            
            # Assign ranks back to the original indices
            rank_matrix[i, non_nan_indices] .= row_ranks
        end
        
        # Preserve NaN values in rank matrix
        rank_matrix[i, setdiff(1:end, non_nan_indices)] .= NaN
    end
    
    # Create new TimeArray with computed ranks
    return TimeArray(timestamp(ta), rank_matrix, colnames(ta))
end

function rowwise_competerank(ta::TimeArray)
    """
    Compute ordinal ranks for each value in the TimeArray along rows, ignoring NaNs.

    Parameters:
    - ta: TimeArray containing numerical data.

    Returns:
    - A TimeArray with ordinal ranks computed for each row.
    """
    
    # Extract values from TimeArray
    values_matrix = values(ta)
    
    # Initialize matrix for ranks
    rank_matrix = similar(values_matrix, Float64)
    
    # Compute rowwise ordinal ranks
    for i in 1:size(values_matrix, 1)
        row = values_matrix[i, :]
        non_nan_indices = findall(!isnan, row)
        non_nan_values = row[non_nan_indices]
        
        if !isempty(non_nan_values)
            # Compute ordinal ranks for non-NaN values
            row_ranks = competerank(non_nan_values)
            
            # Assign ranks back to the original indices
            rank_matrix[i, non_nan_indices] .= row_ranks
        end
        
        # Preserve NaN values in rank matrix
        rank_matrix[i, setdiff(1:end, non_nan_indices)] .= NaN
    end
    
    # Create new TimeArray with computed ranks
    return TimeArray(timestamp(ta), rank_matrix, colnames(ta))
end

function rowwise_tiedrank(ta::TimeArray)
    """
    Compute tied ranks for each value in the TimeArray along rows, ignoring NaNs.

    Parameters:
    - ta: TimeArray containing numerical data.

    Returns:
    - A TimeArray with ordinal ranks computed for each row.
    """
    
    # Extract values from TimeArray
    values_matrix = values(ta)
    
    # Initialize matrix for ranks
    rank_matrix = similar(values_matrix, Float64)
    
    # Compute rowwise ordinal ranks
    for i in 1:size(values_matrix, 1)
        row = values_matrix[i, :]
        non_nan_indices = findall(!isnan, row)
        non_nan_values = row[non_nan_indices]
        
        if !isempty(non_nan_values)
            # Compute ordinal ranks for non-NaN values
            row_ranks = StatsBase.tiedrank(non_nan_values)
            
            # Assign ranks back to the original indices
            rank_matrix[i, non_nan_indices] .= row_ranks
        end
        
        # Preserve NaN values in rank matrix
        rank_matrix[i, setdiff(1:end, non_nan_indices)] .= NaN
    end
    
    # Create new TimeArray with computed ranks
    return TimeArray(timestamp(ta), rank_matrix, colnames(ta))
end

function rowwise_denserank(ta::TimeArray)
    """
    Compute tied ranks for each value in the TimeArray along rows, ignoring NaNs.

    Parameters:
    - ta: TimeArray containing numerical data.

    Returns:
    - A TimeArray with ordinal ranks computed for each row.
    """
    
    # Extract values from TimeArray
    values_matrix = values(ta)
    
    # Initialize matrix for ranks
    rank_matrix = similar(values_matrix, Float64)
    
    # Compute rowwise ordinal ranks
    for i in 1:size(values_matrix, 1)
        row = values_matrix[i, :]
        non_nan_indices = findall(!isnan, row)
        non_nan_values = row[non_nan_indices]
        
        if !isempty(non_nan_values)
            # Compute ordinal ranks for non-NaN values
            row_ranks = StatsBase.denserank(non_nan_values)
            
            # Assign ranks back to the original indices
            rank_matrix[i, non_nan_indices] .= row_ranks
        end
        
        # Preserve NaN values in rank matrix
        rank_matrix[i, setdiff(1:end, non_nan_indices)] .= NaN
    end
    
    # Create new TimeArray with computed ranks
    return TimeArray(timestamp(ta), rank_matrix, colnames(ta))
end

function rowwise_ordinal_pctrank(ta::TimeArray)
    """
    Compute ordinal percentile ranks for each value in the TimeArray along rows, ignoring NaNs.

    Parameters:
    - ta: TimeArray containing numerical data.

    Returns:
    - A TimeArray with ordinal percentile ranks computed for each row.

    Notes:
    - Rows with only one non-NaN value will result in NaN for that row's percentile calculation.
    - Percentile ranks are calculated as (ordinal rank) / (maximum rank in the row).
    - NaN values are preserved in their original positions.

    """
    
    ta_ordrank = rowwise_ordinalrank(ta)
    max_values = ta_ordrank |> values |> eachrow |> row -> filter.(!isnan, row) .|> maximum

    ta_ord_pct = ta_ordrank ./ max_values

    return ta_ord_pct
end

function rowwise_tied_pctrank(ta::TimeArray)
    """
    Compute ordinal percentile ranks for each value in the TimeArray along rows, ignoring NaNs.

    Parameters:
    - ta: TimeArray containing numerical data.

    Returns:
    - A TimeArray with ordinal percentile ranks computed for each row.

    Notes:
    - Rows with only one non-NaN value will result in NaN for that row's percentile calculation.
    - Percentile ranks are calculated as (ordinal rank) / (maximum rank in the row).
    - NaN values are preserved in their original positions.

    """
    
    ta_ordrank = rowwise_tiedrank(ta)
    max_values = ta_ordrank |> values |> eachrow |> row -> filter.(!isnan, row) .|> maximum

    ta_ord_pct = ta_ordrank ./ max_values

    return ta_ord_pct
end

function rowwise_quantiles(ta::TimeArray, n_quantiles::Int=5)
    
    """
    Convert values in a TimeArray to quantiles rowwise, ignoring NaN values.

    Parameters:
    - ta: Input TimeArray
    - n_quantiles: Number of quantiles (default: 5)

    Returns:
    - A new TimeArray with non-NaN values replaced by their quantile ranks
    """
    
    ta_pctrank = rowwise_ordinal_pctrank(ta)

    values_matrix = values(ta_pctrank)
    result_matrix = similar(values_matrix)
    
    for row in 1:size(values_matrix, 1)
        row_data = values_matrix[row, :]
        non_nan_data = filter(!isnan, row_data)
        
        if isempty(non_nan_data)
            result_matrix[row, :] .= NaN
        else
            quantile_breaks = quantile(non_nan_data, (0:n_quantiles)/n_quantiles)
            
            for (col, value) in enumerate(row_data)
                if isnan(value)
                    result_matrix[row, col] = NaN
                else
                    result_matrix[row, col] = findfirst(q -> value <= q, quantile_breaks[2:end])
                end
            end
        end
    end
    
    return TimeArray(timestamp(ta), result_matrix, colnames(ta))
end

function rowwise_tiedquantiles(ta::TimeArray, n_quantiles::Int=5)
    
    """
    Convert values in a TimeArray to quantiles rowwise, ignoring NaN values.

    Parameters:
    - ta: Input TimeArray
    - n_quantiles: Number of quantiles (default: 5)

    Returns:
    - A new TimeArray with non-NaN values replaced by their quantile ranks
    """
    
    ta_pctrank = rowwise_tied_pctrank(ta)

    values_matrix = values(ta_pctrank)
    result_matrix = similar(values_matrix)
    
    for row in 1:size(values_matrix, 1)
        row_data = values_matrix[row, :]
        non_nan_data = filter(!isnan, row_data)
        
        if isempty(non_nan_data)
            result_matrix[row, :] .= NaN
        else
            quantile_breaks = quantile(non_nan_data, (0:n_quantiles)/n_quantiles)
            
            for (col, value) in enumerate(row_data)
                if isnan(value)
                    result_matrix[row, col] = NaN
                else
                    result_matrix[row, col] = findfirst(q -> value <= q, quantile_breaks[2:end])
                end
            end
        end
    end
    
    return TimeArray(timestamp(ta), result_matrix, colnames(ta))
end


function rowwise_count(ta::TimeArray, target_value::Any)

    """
    Counts the occurrences of `target_value` in each row of the given `TimeArray` `ta`.

    # Arguments
    - `ta::TimeArray`: The TimeArray to analyze.
    - `target_value::Any`: The value to count within each row.

    # Returns
    - A new `TimeArray` where each entry represents the count of `target_value` in 
    the corresponding row of the input `TimeArray`. The timestamp from the input 
    `TimeArray` is preserved.
    """

    values_matrix = values(ta)
    counts = [count(x -> x == target_value, row) for row in eachrow(values_matrix)]
    
    return TimeArray(timestamp(ta), counts, ["CountOf_$target_value"])
end

function rowwise_countall(ta::TimeArray)

    """
    Compute counts of unique values in each row of the TimeArray, ignoring NaNs.

    Parameters:
    - ta: TimeArray containing numerical data.

    Returns:
    - A TimeArray with counts of unique values for each row.
    """

    values_range = ta |> values |> unique |> x -> filter(!isnan, x) |> sort
    results_df = DataFrame(:TimeStamp => timestamp(ta))

    for val in values_range

        results_df[!, "Var_$val"] = rowwise_count(ta, val) |> values 
    end

    return TimeArray(timestamp = :TimeStamp, results_df)
end




################################### THE END ######################################################################################

end
