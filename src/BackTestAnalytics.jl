module BackTestAnalytics

using TimeSeries
using StatsBase
using Plots

# Write your package code here.

    include("infocoef_analytics.jl")
    include("plots_analytics.jl")
    include("quantile_analytics.jl")

end
