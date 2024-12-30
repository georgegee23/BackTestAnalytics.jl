module BackTestAnalytics

using TimeSeries
using DaraFrames
using StatsBase
using Plots, GR

# Write your package code here.

    include("infocoef_analytics.jl")
    include("plots_analytics.jl")
    include("quantile_analytics.jl")

end
