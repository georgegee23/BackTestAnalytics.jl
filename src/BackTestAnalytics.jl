module BackTestAnalytics

using TimeSeries
using DataFrames
using StatsBase
using Plots, GR

export rows_spearmanr, rows_pearsonr, spearman_factor_decay 
export mean_autocor, rolling_mean_autocor
export plot_factor_distribution, plot_performance_table
export quantile_return, compute_quantiles_returns,
export quantile_turnover, quantiles_turnover, total_quantiles_turnover, quantile_performance_table, quantile_chg

# Write your package code here.

    include("infocoef_analytics.jl")
    include("plots_analytics.jl")
    include("quantile_analytics.jl")

end
