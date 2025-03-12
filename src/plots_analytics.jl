
####### PLOTS FOR ANALYSIS ##########################################################

function plot_factor_distribution(factors::TimeArray; bins::Int = 20)

    """
    Plots the distribution of factor scores over time and as a histogram.

    Parameters:
    - factor_score: TimeArray of factor scores
    - bins: Number of bins for the histogram


    Returns:
    - A plot object combining a time series plot and a histogram
    """

    # Ensure the factor_score is not empty
    if isempty(factors)
        throw(ArgumentError("factor_score cannot be empty"))
    end

    # Calculate the row mean
    mu_row = row_mean(factors)

    # Time series plot
    p1 = Plots.plot(timestamp(mu_row), values(mu_row), 
    title = "Mean Factor Values Over Time",
    label = "",
    xlabel = "Time",
    ylabel = "Mean Factor Score",
    titlefontsize = 12,
    legend = :top)

    # Histogram plot
    mu_row_values = values(mu_row)
    p2 = Plots.histogram(mu_row_values, 
    title = "Distribution of Mean Factor Scores",
    label = "",
    xlabel = "Mean Factor Score",
    ylabel = "Frequency",
    titlefontsize = 12,
    legend = :top,
    bins = bins)

    # Combine plots into a 2x1 subplot
    return Plots.plot(p1, p2, layout = (2, 1), size = (800,600))
end


function plot_performance_table(table::DataFrames)

    """
    Compute and plot table with summary performance statistics for factor quantiles.

    Parameters:
    - quantile_returns: TimeArray containing returns for each quantile
    - benchmark_returns: TimeArray containing benchmark returns
    - thresh_value: Threshold value for down markets (default: 0)
    - periods_per_year: Number of periods in a year 

    Returns:
    - Plot
    """ 

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