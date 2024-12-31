module BackTestAnalytics

using TimeSeries
using DataFrames
using StatsBase
using Plots, GR


export rows_spearmanr, rows_pearsonr, spearman_factor_decay, mean_autocor, rolling_mean_autocor,
    plot_factor_distribution, plot_performance_table,
     
    quantile_return, compute_quantiles_returns, 
    quantile_turnover, quantiles_turnover, total_quantiles_turnover, quantile_performance_table, quantile_chg,

    row_mean, column_mean, rowwise_ordinalrank, rowwise_competerank, rowwise_tiedrank, rowwise_denserank,
    rowwise_ordinal_pctrank, rowwise_tied_pctrank, 
    rowwise_quantiles, rowwise_tiedquantiles, rowwise_count, rowwise_countall

# Write your package code here.

    include("infocoef_analytics.jl")
    include("plots_analytics.jl")
    include("quantile_analytics.jl")
    include("timeseriesfunk.jl")

end
