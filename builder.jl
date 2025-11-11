### A Pluto.jl notebook ###
# v0.20.20

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 3f5cedba-a6de-43a4-ac54-44b556e687c8
begin
	using PlutoUI
	using CSV
	using DataFrames
	using HypertextLiteral
	using PrettyTables
	using XLSX
end

# ╔═╡ ec0ef7a0-b2e7-11f0-092a-53f8b3d00bc7
md"""
# Build Data File
"""

# ╔═╡ 6ce004fc-e38a-436e-ab88-f2652cdab622
md"""
## 1. Data XLSX Template
"""

# ╔═╡ 0f751a2d-243b-49ab-807a-702c1d935c3e
begin
	xlsx_input = @bind xlsx confirm(PlutoUI.TextField(default=""))
	
	@htl("""
		<table cellpadding="0" cellspacing="0">
			<tr><td colspan=2><b>📂 Current location:</b> <span style="color: #8a2525; background-color: #f2f1ec; padding: 3px 8px; border-radius: 4px;">$(pwd())</span></td></tr>
		 	<tr>
				<td>Site (location of .xlsx template)</td>
				<td>$(xlsx_input)</td>
			</tr>
		</table>
	""")
end

# ╔═╡ ef2d0673-1473-4905-ad02-fa82ece544ea
md"""
## 2. Data CSV File Contents
"""

# ╔═╡ 20d1d612-cd65-4115-a08e-05920bdeb438
begin
	tmin_check = @bind show_tmin PlutoUI.CheckBox(default=false)
	tmax_check = @bind show_tmax PlutoUI.CheckBox(default=false)
	wind_check = @bind show_wind PlutoUI.CheckBox(default=false)
	rain_check = @bind show_rain PlutoUI.CheckBox(default=false)
	ndec_input = @bind ndec PlutoUI.Slider(1:8, default=3, show_value=true)

	@htl("""
		<style>
	    .show-table input:not([type="checkbox"]) {
	        width: 100px !important;
	        padding: 4px;
	    }
	    .show-table input[type="checkbox"] {
	        width: auto;
	        padding: 0;
	        margin: 0 auto;
	        display: block;
	    }
	    .show-table th {
	        background-color: #2a4973;
	        padding: 5px;
	        font-weight: 600;
	        color: #ffffff;
	        text-align: left;
	    }
	    .show-table td {
	        text-align: left;
	    }
	    .show-table td:nth-child(2) {
	        text-align: center;
	    }
		</style> 
		<table cellpadding="0" cellspacing="0" class="show-table">
		<tr>
			<th>Parameters</th>
		 	<th>Show ☑</th>
		</tr>
		<tr>
			<td>Min. Air Temp.</td><td>$(tmin_check)</td>
		</tr>
		<tr>
			<td>Max. Air Temp.</td><td>$(tmax_check)</td>
		</tr>
		<tr>
			<td>Wind Speed</td><td>$(wind_check)</td>
		</tr>
		<tr>
			<td>Rainfall</td><td>$(rain_check)</td>
		</tr>
		</table>
		<table>
		<tr>
			<td>No. of decimal places</td>
		 	<td>$(ndec_input)</td>
		</tr>
		</table>
	""")
end

# ╔═╡ bed35b5f-3717-4be2-a654-6e660daeb1cc
begin
	const MTHS = ["Annual", "January", "February", "March", "April", "May", 
	              "June", "July", "August", "September", "October", 
	              "November", "December"]

	
	function xlsx_to_csv(input_xlsx)
	    function has_sheet(sht, sheets)
	        (sht ∉ sheets) && error("'$(sht)' sheet not found")
	    end
	
	    isempty(input_xlsx) && return (DataFrame(), "")
	    
	    try
	        xf = XLSX.readxlsx(input_xlsx)
	    
	        # Check for required worksheets
	        sht_names = XLSX.sheetnames(xf)
	        foreach(sht -> has_sheet(sht, sht_names), 
	                ["Site", "Tmin", "Tmax", "Wind", "Rain"])
	    
	        sitename, latitude = read_siteinfo(xf)
	        
	        # Extract data from all sheets
	        tmin_data = extract_data(xf["Tmin"], 4)
	        tmax_data = extract_data(xf["Tmax"], 4)
	        wind_data = extract_data(xf["Wind"], 3)
	        rain_data = extract_data(xf["Rain"], 3)
	        
	        # Validate that all sheets have data
	        isempty(tmin_data) && error("No data in Tmin sheet")
	        isempty(tmax_data) && error("No data in Tmax sheet")
	        isempty(wind_data) && error("No data in Wind sheet")
	        isempty(rain_data) && error("No data in Rain sheet")
	        
	        # Validate years match across all sheets
	        validate_same_years(tmin_data, tmax_data, wind_data, rain_data)
	        
	        # Validate no missing/NaN values
	        validate_no_missing(tmin_data, "Tmin")
	        validate_no_missing(tmax_data, "Tmax")
	        validate_no_missing(wind_data, "Wind")
	        validate_no_missing(rain_data, "Rain")
	        
	        # Build DataFrame
	        years = sort!(collect(keys(tmin_data)))
	        df = DataFrame(year = years)
	        # Add parameters in order: Tmin, Tmax, Wind, Rainfall
	        add_params!(df, tmin_data, ["mean", "sd", "rlag", "skew"], "tmin", years)
	        add_params!(df, tmax_data, ["mean", "sd", "rlag", "skew"], "tmax", years)
	        add_params!(df, wind_data, ["mean", "sd", "rlag"], "wind", years)
	        add_params!(df, rain_data, ["totrain", "pww", "pwd"], "", years)
	        
	        datafile_path = write_csv_with_latitude(sitename, latitude, df)
	        return (df, datafile_path)
	    catch e
	        @warn "Error processing XLSX file. $(sprint(showerror, e))"
	        return (DataFrame(), "")
	    end
	end
	
	
	function read_siteinfo(xf)
	    sheet = xf["Site"]
	    sitename = get_cell(sheet, 2, 2)  # Cell B2
	    sitename === nothing && error("Missing site name")
	
	    lat_val = get_cell(sheet, 3, 2)  # Cell B3
	    lat_val === nothing && error("Missing latitude value")
	    
	    try
	        return (sitename, Float64(lat_val))
	    catch
	        error("Latitude '$lat_val' is not a valid number")
	    end
	end
	
	
	function validate_same_years(tmin_data, tmax_data, wind_data, rain_data)
	    tmin_years = Set(keys(tmin_data))
	    tmax_years = Set(keys(tmax_data))
	    wind_years = Set(keys(wind_data))
	    rain_years = Set(keys(rain_data))
	    
	    # Check if all sets are equal
	    if !(tmin_years == tmax_years == wind_years == rain_years)
	        # Find differences
	        all_years = union(tmin_years, tmax_years, wind_years, rain_years)
	        
	        missing_in = String[]
	        for year ∈ all_years
	            sheets_missing = String[]
	            year ∉ tmin_years && push!(sheets_missing, "Tmin")
	            year ∉ tmax_years && push!(sheets_missing, "Tmax")
	            year ∉ wind_years && push!(sheets_missing, "Wind")
	            year ∉ rain_years && push!(sheets_missing, "Rain")
	            
	            if !isempty(sheets_missing)
	                push!(missing_in, 
	                      "Year $year missing in: $(join(sheets_missing, ", "))")
	            end
	        end
	        
	        error("Years do not match across all sheets:\n  " * 
	              join(missing_in, "\n  "))
	    end
	    
	    true
	end
	
	
	function validate_no_missing(data::Dict, sheet_name::String)
	    mth(i) = MTHS[i-1]
	
	    for (year, matrix) ∈ data
	        for month ∈ axes(matrix, 1), param ∈ axes(matrix, 2)
	            val = matrix[month, param]
	            
	            if isnan(val) || ismissing(val)
	                month_name = month == 1 ? "Annual" : mth(month)
	                error("Missing or NaN value in '$sheet_name' sheet, " *
	                      "Year $year, $month_name, Parameter $param")
	            end
	            
	            # Check if value is a valid number
	            if !isa(val, Real) || isinf(val)
	                month_name = month == 1 ? "Annual" : mth(month)
	                error("Invalid value '$val' in '$sheet_name' sheet, " *
	                      "Year $year, $month_name, Parameter $param")
	            end
	        end
	    end
	    
	    true
	end
	
	
	function write_csv_with_latitude(sitename, latitude, df)
	    function create_site_folder(path)
	        try
	            mkpath(path)
	            return true
	        catch
	            return false
	        end
	    end
	
	    path = joinpath(pwd(), sitename)
	    !create_site_folder(sitename) && error("Site name '$(sitename)' is invalid.")
	
	    datafile_path = joinpath(path, "data.csv")
	    csv_string = sprint(io -> CSV.write(io, df))
	    open(datafile_path, "w") do io
	        println(io, "$latitude")
	        write(io, csv_string)
	    end
	
	    datafile_path
	end
	
	
	function extract_data(sheet, n_params::Int)
	    data = Dict{Int, Matrix{Float64}}()
	    row = 3  # Start after headers
	    
	    while true
	        year = get_cell(sheet, row, 1)
	        
	        # Skip blank rows and look for next year
	        skip_count = 0
	        while year === nothing
	            row += 1
	            skip_count += 1
	            skip_count > 10 && return data  # Stop after 10 blank rows
	            year = get_cell(sheet, row, 1)
	        end
	        
	        # Validate year is a number
	        year_int = try
	            Int(year)
	        catch
	            error("Invalid year value '$year' at row $row. " *
	                  "Year must be an integer.")
	        end
	        
	        # Read 13 months x n_params into matrix
	        matrix = [
	            let
	                val = get_cell(sheet, row+m-1, p+2)
	                val === nothing ? NaN : 
	                    try
	                        Float64(val)
	                    catch
	                        NaN
	                    end
	            end for m ∈ 1:13, p ∈ 1:n_params
	        ]
	        
	        data[year_int] = matrix
	        row += 13
	    end
	    
	    data
	end
	
	
	function get_cell(sheet, row::Int, col::Int)
	    try
	        val = sheet[row, col]
	        return ismissing(val) ? nothing : val
	    catch
	        return nothing
	    end
	end
	
	
	function add_params!(df::DataFrame, data::Dict, param_names::Vector{String},
	                     suffix::String, years::Vector{Int})
	    for (param_idx, param_name) ∈ enumerate(param_names)
	        for month ∈ 0:12
	            col_name = isempty(suffix) ? "$(param_name)$(month)" :
	                                         "$(param_name)_$(suffix)$(month)"
	            df[!, col_name] = [data[year][month + 1, param_idx] for year ∈ years]
	        end
	    end
	end
	

	function display_table(title, df, idx; ndec=3)
		df_rest = df[:, 2:end]
		dft = DataFrame(
		    [[names(df_rest)]; collect.(eachrow(df_rest))], 
		    [:Parameter; [Symbol("$year") for year ∈ df.year]]
		)
		
		col_names = names(dft)
	 
	    original_groups = [
			1=>"~Min. Air Temperature~", 
			53=>"~Max. Air Temperature~", 
			105=>"~Wind Speed~", 
			144=>"~Rainfall~"]
		
		row_group_labels = Pair{Int, String}[]
	    for (orig_row, label) in original_groups
	        new_row_pos = findfirst(==(orig_row), idx)
	        if !isnothing(new_row_pos)
	            push!(row_group_labels, new_row_pos => label)
	        end
	    end
		
		hl_tmin = HtmlHighlighter(
	        (data, i, j) -> occursin("tmin", lowercase(String(data[i, 1]))),
	        ["color"=>"royalblue"]
	    )
	    hl_tmax = HtmlHighlighter(
	        (data, i, j) -> occursin("tmax", lowercase(String(data[i, 1]))),
	        ["color"=>"chocolate"]
	    )
	    hl_wind = HtmlHighlighter(
	        (data, i, j) -> occursin("wind", lowercase(String(data[i, 1]))),
	        ["color"=>"seagreen"]
	    )
	    hl_rain = HtmlHighlighter(
	        (data, i, j) -> occursin("rain", lowercase(String(data[i, 1]))) ||
	                        occursin("pw", lowercase(String(data[i, 1]))),
	        ["color"=>"orchid"]
	    )

		pretty_table(
	        HTML, dft[idx, :]; backend=:html,
	        column_labels=col_names,
	        title="🔍 Reformatted view: '$(title)'",
	        title_alignment=:l,
			alignment=[:c; repeat([:r], ncol(dft) - 1)],
	        row_group_labels=row_group_labels,
			highlighters=[hl_tmin, hl_tmax, hl_wind, hl_rain],
			formatters=[fmt__printf("%.$(ndec)f")],
			style = HtmlTableStyle(;
	            title=[
					"font-weight"=>"normal",
				],        
	            first_line_column_label=[
					"font-weight"=>"bold",
				],       
				row_group_label=[
					"font-style"=>"italic",
				],
	            table=[
					"font-family"=>"monospace",
					# "background-color"=>"#ffffff"
				],
	        )
	    )
	end

	
	Markdown.parse("🙈 _unhide core code_")
end

# ╔═╡ 10036c97-44fa-4cb3-abf7-39196b698476
begin
	xl_file = isempty(xlsx) ? "" : "$(basename(xlsx)).xlsx" 
	xl_path = joinpath(xlsx, xl_file)
	datadf, datafile_path = xlsx_to_csv(xl_path)
	if !isempty(datafile_path)
		@info "Template file read: '$(xl_path)'"
		@info "Data file created:'$(relpath(datafile_path))'"
	else
		nothing
	end
end

# ╔═╡ efe58c3c-e03f-49a3-9b9c-90b495fee5af
begin
	xlsx
	if !isempty(datadf)
		idx = Int[]
		show_tmin && append!(idx, 1:52)
		show_tmax && append!(idx, 53:104)
		show_wind && append!(idx, 105:143)
		show_rain && append!(idx, 144:182)
		if !isempty(idx)
			display_table(relpath(datafile_path), datadf, idx; ndec=Int(ndec))
		else
			@info "🙈 Nothing to show! You did not select any parameter."
		end
	else
		@info "No data file created; nothing to show."
	end
end

# ╔═╡ 93407ea6-0ee1-41d0-b986-5a7b560c6a4f
begin
	# To read `data.csv` into XLSX template file
	
	function csv_to_xlsx(site_path)
		site = basename(site_path)
		xlsx_file = joinpath(site_path, "$(site).xlsx")
		csv_path = joinpath(site_path, "data.csv")		
		
		latitude = parse(Float64, readline(csv_path))
	    df = CSV.read(csv_path, DataFrame; header=2)
	    
	    XLSX.openxlsx(xlsx_file, mode="w") do xf
	        create_site_sheet!(xf, site_path, latitude)
	        create_tmin_sheet!(xf, df)
	        create_tmax_sheet!(xf, df)
	        create_wind_sheet!(xf, df)
	        create_rain_sheet!(xf, df)
	    end
	    
	    xlsx_file
	end
	
	
	function create_site_sheet!(xf, site_name, latitude)
	    sheet = xf[1]
	    XLSX.rename!(sheet, "Site")
	    sheet["A1"] = "Site Info"
	    sheet["B1"] = "Value"
	    sheet["A2"] = "[path/]site name"
	    sheet["B2"] = site_name
	    sheet["A3"] = "Site latitude in decimal degrees (e.g., 3.033)"
	    sheet["B3"] = latitude
	end
	
	
	function create_tmin_sheet!(xf, df)
	    XLSX.addsheet!(xf, "Tmin")
	    sheet = xf["Tmin"]
	    sheet["A1"] = "Minimum Temperature (Tmin)"
	    sheet["A2"] = "Year"
	    sheet["B2"] = "Period"
	    sheet["C2"] = "Mean"
	    sheet["D2"] = "SD"
	    sheet["E2"] = "R_lag"
	    sheet["F2"] = "Skewness"
	    
	    row = 3
	    for year_row ∈ eachrow(df)
	        for (i, month) ∈ enumerate(MTHS)
	            sheet[row, 1] = year_row.year
	            sheet[row, 2] = month
	            sheet[row, 3] = year_row[Symbol("mean_tmin$(i-1)")]
	            sheet[row, 4] = year_row[Symbol("sd_tmin$(i-1)")]
	            sheet[row, 5] = year_row[Symbol("rlag_tmin$(i-1)")]
	            sheet[row, 6] = year_row[Symbol("skew_tmin$(i-1)")]
	            row += 1
	        end
	        row += 1  # Blank row between years
	    end
	end
	
	
	function create_tmax_sheet!(xf, df)
	    XLSX.addsheet!(xf, "Tmax")
	    sheet = xf["Tmax"]
	    sheet["A1"] = "Maximum Temperature (Tmax)"
	    sheet["A2"] = "Year"
	    sheet["B2"] = "Period"
	    sheet["C2"] = "Mean"
	    sheet["D2"] = "SD"
	    sheet["E2"] = "R_lag"
	    sheet["F2"] = "Skewness"
	    
	    row = 3
	    for year_row ∈ eachrow(df)
	        for (i, month) ∈ enumerate(MTHS)
	            sheet[row, 1] = year_row.year
	            sheet[row, 2] = month
	            sheet[row, 3] = year_row[Symbol("mean_tmax$(i-1)")]
	            sheet[row, 4] = year_row[Symbol("sd_tmax$(i-1)")]
	            sheet[row, 5] = year_row[Symbol("rlag_tmax$(i-1)")]
	            sheet[row, 6] = year_row[Symbol("skew_tmax$(i-1)")]
	            row += 1
	        end
	        row += 1  # Blank row between years
	    end
	end
	
	
	function create_wind_sheet!(xf, df)
	    XLSX.addsheet!(xf, "Wind")
	    sheet = xf["Wind"]
	    sheet["A1"] = "Wind Speed"
	    sheet["A2"] = "Year"
	    sheet["B2"] = "Period"
	    sheet["C2"] = "Mean"
	    sheet["D2"] = "SD"
	    sheet["E2"] = "R_lag"
	    
	    row = 3
	    for year_row ∈ eachrow(df)
	        for (i, month) ∈ enumerate(MTHS)
	            sheet[row, 1] = year_row.year
	            sheet[row, 2] = month
	            sheet[row, 3] = year_row[Symbol("mean_wind$(i-1)")]
	            sheet[row, 4] = year_row[Symbol("sd_wind$(i-1)")]
	            sheet[row, 5] = year_row[Symbol("rlag_wind$(i-1)")]
	            row += 1
	        end
	        row += 1  # Blank row between years
	    end
	end
	
	
	function create_rain_sheet!(xf, df)
	    XLSX.addsheet!(xf, "Rain")
	    sheet = xf["Rain"]
	    sheet["A1"] = "Rainfall"
	    sheet["A2"] = "Year"
	    sheet["B2"] = "Period"
	    sheet["C2"] = "Total_Rain"
	    sheet["D2"] = "P_WW"
	    sheet["E2"] = "P_WD"
	    
	    row = 3
	    for year_row ∈ eachrow(df)
	        for (i, month) ∈ enumerate(MTHS)
	            sheet[row, 1] = year_row.year
	            sheet[row, 2] = month
	            sheet[row, 3] = year_row[Symbol("totrain$(i-1)")]
	            sheet[row, 4] = year_row[Symbol("pww$(i-1)")]
	            sheet[row, 5] = year_row[Symbol("pwd$(i-1)")]
	            row += 1
	        end
	        row += 1  # Blank row between years
	    end
	end
	
	
	# csv_to_xlsx("data/Test")
	Markdown.parse("🙈 _unhide core code_")
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PrettyTables = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
XLSX = "fdbf4ff8-1666-58a4-91e7-1b58723a45e0"

[compat]
CSV = "~0.10.15"
DataFrames = "~1.8.0"
HypertextLiteral = "~0.9.5"
PlutoUI = "~0.7.72"
PrettyTables = "~3.1.0"
XLSX = "~0.10.4"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.1"
manifest_format = "2.0"
project_hash = "8190a7873aa1df079749a9a09468f27b889cccf3"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.ArgCheck]]
git-tree-sha1 = "f9e9a66c9b7be1ad7372bbd9b062d9230c30c5ce"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.5.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "deddd8725e5e1cc49ee205a1964256043720a6c3"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.15"

[[deps.CodecInflate64]]
deps = ["TranscodingStreams"]
git-tree-sha1 = "d981a6e8656b1e363a2731716f46851a2257deb7"
uuid = "6309b1aa-fc58-479c-8956-599a07234577"
version = "0.1.3"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "9d8a54ce4b17aa5bdce0ea5c34bc5e7c340d16ad"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.18.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.0+1"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "c967271c27a95160e30432e011b58f42cd7501b5"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.8.0"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "6c72198e6a101cccdd4c9731d3985e904ba26037"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.1"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EzXML]]
deps = ["Printf", "XML2_jll"]
git-tree-sha1 = "7ea1aa5869e2626ccae84480e4f37185bc6f41d3"
uuid = "8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"
version = "1.2.3"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "3bab2c5aa25e7840a4b065805c0cdfc01f3068d2"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.24"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.InlineStrings]]
git-tree-sha1 = "8f3d257792a522b4601c24a577954b0a8cd7334d"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.5"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.InputBuffers]]
git-tree-sha1 = "e5392ea00942566b631e991dd896942189937b2f"
uuid = "0c81fc1b-5583-44fc-8770-48be1e1cca08"
version = "1.1.1"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "0533e564aae234aff59ab625543145446d8b6ec2"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.7.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.11.1+1"

[[deps.LibGit2]]
deps = ["LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.9.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "OpenSSL_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.3+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.5.20"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.1+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.12.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "f53232a27a8c1c836d3998ae1e17d898d4df2a46"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.72"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "0f27480397253da18fe2c12a4ba4eb9eb208bf3d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.0"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "REPL", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "6b8e2f0bae3f678811678065c09571c1619da219"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "3.1.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.REPL]]
deps = ["InteractiveUtils", "JuliaSyntaxHighlighting", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "712fb0231ee6f9120e005ccd56297abbc053e7e0"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.8"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "64d974c2e6fdf07f8155b5b2ca2ffa9069b608d9"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.2"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

    [deps.Statistics.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "725421ae8e530ec29bcbdddbe91ff8053421d023"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.1"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "f2c1efbc8f3a609aadf318094f8fc5204bdaf344"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "372b90fe551c019541fafc6ff034199dc19c8436"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.12"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XLSX]]
deps = ["Artifacts", "Dates", "EzXML", "Printf", "Tables", "ZipArchives", "ZipFile"]
git-tree-sha1 = "7fca49e6dbb35b7b7471956c2a9d3d921360a00f"
uuid = "fdbf4ff8-1666-58a4-91e7-1b58723a45e0"
version = "0.10.4"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "5c959b708667b34cb758e8d7c6f8e69b94c32deb"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.15.1+0"

[[deps.ZipArchives]]
deps = ["ArgCheck", "CodecInflate64", "CodecZlib", "InputBuffers", "PrecompileTools", "TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9a08756e326388a9e6c038125aa4686e0467d27b"
uuid = "49080126-0e18-4c2a-b176-c102e4b3760c"
version = "2.5.1"

[[deps.ZipFile]]
deps = ["Libdl", "Printf", "Zlib_jll"]
git-tree-sha1 = "f492b7fe1698e623024e873244f10d89c95c340a"
uuid = "a5390f91-8eb1-5f08-bee0-b1d1ffed6cea"
version = "0.10.1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.1+2"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.64.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.5.0+2"
"""

# ╔═╡ Cell order:
# ╟─ec0ef7a0-b2e7-11f0-092a-53f8b3d00bc7
# ╟─6ce004fc-e38a-436e-ab88-f2652cdab622
# ╟─0f751a2d-243b-49ab-807a-702c1d935c3e
# ╟─10036c97-44fa-4cb3-abf7-39196b698476
# ╟─ef2d0673-1473-4905-ad02-fa82ece544ea
# ╟─20d1d612-cd65-4115-a08e-05920bdeb438
# ╟─efe58c3c-e03f-49a3-9b9c-90b495fee5af
# ╟─3f5cedba-a6de-43a4-ac54-44b556e687c8
# ╟─bed35b5f-3717-4be2-a654-6e660daeb1cc
# ╠═93407ea6-0ee1-41d0-b986-5a7b560c6a4f
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
