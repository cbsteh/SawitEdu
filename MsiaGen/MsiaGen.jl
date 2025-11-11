module MsiaGen

using CSV
using DataFrames
using Dates
using Distributions
using LinearAlgebra
using Parameters
using Printf
using Random
using SpecialFunctions
using Statistics
using StatsBase

include("met.jl")
include("utils.jl")
include("gof.jl")
include("collate.jl")
include("gentemp.jl")
include("genwind.jl")
include("genrain.jl")
include("gensolar.jl")
include("input.jl")

# GoF.jl
using .GoF
export GoF

# utils.jl
export csv2df
# collate.jl
export collate_mets, collate_stats, gof, generate_mets
# gentemp.jl
export create_temp
# genwind.jl
export create_wind
# genrain.jl
export create_rain
# gentemp.jl, genwind.jl, genrain.jl
export generate!
# gensolar.jl
export add_solar_radiation!
# input.jl
export create_data_file

end # module MsiaGen
