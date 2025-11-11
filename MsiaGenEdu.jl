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

# ╔═╡ 8a062689-2c97-4e06-8693-b7fa93699a34
begin
	using PlutoUI
	using HypertextLiteral
	using KernelDensity
	using LsqFit
	using LaTeXStrings
	using ColorSchemes
	using CairoMakie
	
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
	using OrderedCollections
end

# ╔═╡ 8230d169-70d3-4668-abde-5d652d2ccf07
begin
	include("./MsiaGen/MsiaGen.jl")
	using .MsiaGen
end

# ╔═╡ a42ede34-6c38-4106-9145-544cc0bd4e48
md"""
**Understanding Weather Interactions Through System Coupling**

Weather at any location emerges from tightly coupled physical processes. The interplay between these processes is mapped in Fig. 1, where Blue Circles are measured weather data, Green Boxes are derived agricultural metrics like VPD and ET, and Orange Boxes show final crop impacts. The effect of solar radiation is controlled by **Cloud Cover**, which moderates incoming energy. This, in turn, affects **Max Temperature (Tmax)** and **Mean Temperature**, which controls **Vapor Pressure Deficit (VPD)**, the atmosphere's "thirst" for moisture. **Rainfall** reduces VPD by adding humidity, while high VPD indicates dry air demanding water from plants and soil.

**Wind** influences the system through multiple pathways: increasing **evaporative demand (ET₀)**, correlating with rainfall events (monsoon surges, storms), and affecting cloud formation. Rainfall inputs to **Soil Water Storage**, while ET₀ represents atmospheric water demand. Their balance determines soil moisture and **Crop Water Stress**.

In Malaysia's humid tropics, these couplings are especially visible: cloudy, wet spells suppress daytime maxima through shading and maintain high humidity, while wind bursts often accompany monsoon surges that simultaneously alter temperature and rainfall.

**Diagnostic Framework**

As you work through this notebook, look for recurring seasonal structure, short-term persistence from day to day, and how temperature, wind, and rain co-vary.

However, short records can overstate extremes and inflate correlations simply because variables share the same seasonal cycle. Base conclusions on longer records approaching the 30-year climatological normal if you wish to characterize a site's climate. Examine whether relationships persist across different seasons, not just in seasonal averages.
"""

# ╔═╡ 62e69d33-1902-47a2-8d6d-9401a0ff065d
begin
	md"""
	$(PlutoUI.LocalResource("./images/weather_interactions.svg"))
	**Fig. 1.** Weather variable interactions and their agricultural impacts.
	"""
end |> WideCell(; max_width=1000)

# ╔═╡ 5368f1ab-afd4-467d-82a5-d79b47676cd3
md"""
## 1. Weather Input
"""

# ╔═╡ bef2592b-048f-4407-a26b-58444953a85f
md"""
Here you can either: 1) generate or 2) use actual daily weather.

Option 1 will stochastically (randomly) generate weather, so daily weather will be different each time you generate the weather, unless you set the `seed` to a fixed value (see below).

**Site folder name:** 
Specifies which location's data to use. For generated weather, the data file is `data.csv`. This file contains the monthly values for the distribution parameters. For observed (actual) weather, the data file is the daily weather (`wthr.csv`).

**Seed number:**
Use -1 for random generation (different each time you generate).
Use positive values for reproducible results (same output every time).
"""

# ╔═╡ 3402bb40-b3d7-11f0-a219-b375107af3f7
begin
	@bind inputs confirm(PlutoUI.combine() do Child
		usetype_input = Child(:usetype, PlutoUI.Slider(
			["generate", "observed"], default="generate", show_value=true))
		data_input = Child(:datafile, PlutoUI.TextField(default=""))
		seed_input = Child(:seed, PlutoUI.TextField(default="-1"))

		@htl("""
			 <style>
			 .data-display {
			 	font-family: monospace; 
			    font-size: 12px;
			 }
			 .data-display * {
			    font-family: inherit !important;
			    font-size: inherit !important;
			 }
			.load-table {
			    border-collapse: separate;
			    border-spacing: 0;
			    table-layout: fixed;
			    width: 100%;
			 }
			.load-table th {
			    background-color: #2a4973;
			    padding: 5px;
			    font-weight: 600;
			    color: #ffffff;
			    text-align: left;
			    border-top: none;
			    border-right: 1px solid #dee2e6;
			    border-bottom: none;
			    border-left: none;
			}
			.load-table th:last-child {
			    border-right: none;
			}
			.load-table td {
			    padding: 5px;
			    text-align: left;
			    border-top: none;
			    border-right: 1px solid #dee2e6;
			    border-bottom: none;
			    border-left: none;
			    vertical-align: top;
			}
			.load-table td:last-child {
			    border-right: none;
			}
			</style>
  		    <table cellpadding="0" cellspacing="0" class="load-table">
			<tr>
			 	<th>ⓘ Info</th>
			 	<th>Values</th>
			</tr>
			<tr>
				<td>Generate or use observed weather?</td>
			 	<td><div class="data-display">$(usetype_input)</div></td>
			</tr>
			<tr><td colspan=2><b>📂 Current location:</b> <span style="color: #8a2525; background-color: #f2f1ec; padding: 3px 8px; border-radius: 4px;">$(pwd())</span></td></tr>		
			<tr>
				<td>Site folder name (where the site's weather data file is located)</td>
			 	<td>$(data_input)</td>
			</tr>
			<tr>
				<td>Seed number (+ve values for deterministic runs, or -1 for random runs; ignored for observed weather)</td>
			 	<td>$(seed_input)</td>
			</tr>
		</table>
		""")
	end, label="⛭ Submit")
end

# ╔═╡ c6d848be-a3f0-4279-ba1b-df4f1ed2f026
begin
	function get_datafile(path, usetype)
		!isdir(path) && return (1, "Name '$(path)' is invalid or not found")
		sitename = basename(path)
		datafile = (usetype=="generate") ? "data.csv" : "$(sitename).csv"
		csv_path = joinpath(path, datafile)
		!isfile(csv_path) && return (2, "'$(datafile)' not found in '$(path)'")
		return (0, csv_path)
	end
	
	
	csv_path = ""
	if !isempty(inputs.datafile)
		ret, msg = get_datafile(inputs.datafile, inputs.usetype)
		if ret != 0
	    	@htl("""<script>alert('✗ ' + $(msg));</script>""")
		else
	    	csv_path = msg
		end
	end
	
	nothing
end

# ╔═╡ d37b6946-11d7-459f-838e-5d84c80b0f11
let
	inputs
	sitename = basename(dirname(csv_path))
	prefix = inputs.usetype == "generate" ? "Gen. Weather" : "Obs. Weather"
	sname = !isempty(sitename) ? " ($(sitename))" : ""

	Markdown.parse("""
	# $(prefix)$(sname)
	""")
end

# ╔═╡ 0c287c83-2dad-4303-a9fd-343c821468b0
md"""
## 2. Master Control
"""

# ╔═╡ 6152f922-0342-48bb-bf48-c6206c6a3cf6
md"""
Adjust the width of all plots can particularly improve reading of autocorrelation and running-mean heatmaps. Make it wider if you notice the plots look "cramp" with many years plotting.

You can choose to save all plots as `PNG` format, or lock this feature to prevent accidental saving, such as when you rerun a cell.
"""

# ╔═╡ 5b0cc9ca-f269-4d74-9968-afb479cd2969
begin
	locksave_check = @bind locksave PlutoUI.CheckBox(default=true)
	
	@htl("""
		<table cellpadding="0" cellspacing="0" class="load-table">
		 <tr>
		 	<td>Lock figures saving? (Tick for no saving)</td>
			<td>$(locksave_check)</td>
		 </tr>
		</table>
	""")
end

# ╔═╡ fa2a3c3c-6aa1-40e7-b8a2-ec15ba4069cb
begin
	width_input = @bind width PlutoUI.Slider(700:100:2400; default=700, 		                                     	     show_value=true)
	savefigs_btn = @bind savefigs PlutoUI.CounterButton("⤵️ Save Now")

	@htl("""
		<table cellpadding="0" cellspacing="0" class="load-table">
		<tr>
			<th>Control</th>
			<th>Selection</th>
		</tr>
		<tr>
			<td>Width of all charts (in pixels)</td>
			<td><div class="data-display">$(width_input)</div></td>
		</tr>

		$(if !locksave
			@htl("""
			<tr>
				<td>Save all figures</td>
				<td>$(savefigs_btn)</td>
			</tr>
			""")
		end)
		 
		</table>
	""")
end

# ╔═╡ 0c722376-bbfd-45a9-bfa8-1aa8739f9a85
md"""
## 3. Min. Air Temp.
"""

# ╔═╡ 59d16002-60a5-4bfe-a17f-932c3fd96aa8
md"""
### 3.1 Distribution
"""

# ╔═╡ 3dc912ad-cf32-42a2-a6b6-a4b21c122c7a
md"""
**Histogram:** Shows the spread of air temperature values. Values that occur more frequently will have increasingly tall bars, whereas rare values will have shorter bars.

0. Shape of histogram: Is it normal (bell-shaped), skewed, or bimodal?
0. Mean (`μ`): The average minimum temperature
0. Standard deviation (`σ`): How much temperatures vary
0. 1st order autcorrelation (`r`) and skewness (`γ`): Statistical measures of the distribution shape. Note `r` here is not the same as the `r` used later in cross‑variable scatterplots.

**Time series with seasonal fit (two‑harmonic Fourier model)**:
- `ω` = 2π/365, and `t` = day of year
- The constant term is the annual mean
- The `cos(ωt)` and `sin(ωt)` terms capture the **annual** cycle
- The `cos(2ωt)` and `sin(2ωt)` terms capture the **semi-annual** variations

**Important:** The magnitude of the coefficients indicates the strength of each cycle:

- **For the annual cycle:** The amplitude is `√(a₁² + b₁²)` where `a₁` and `b₁` are the coefficients of `cos(ωt)` and `sin(ωt)`
- **For the semi-annual cycle:** The amplitude is `√(a₂² + b₂²)` where `a₂` and `b₂` are the coefficients of `cos(2ωt)` and `sin(2ωt)`

**What this means:**

- **Larger coefficients** (in absolute value) = stronger seasonal cycle at that frequency
- If annual coefficients are large and semi-annual coefficients are small, the location has one distinct warm/cool season per year
- If semi-annual coefficients are also large, there may be two warm/cool periods per year (*e.g.*, some tropical locations have bimodal temperature patterns)

**Tip:** Compare the relative magnitudes when looking at different sites. A site with weak seasonal variation will have smaller coefficients than a site with strong seasons.

**Violin plots by month:** Shows the distribution shape for each month. Imagine looking at a histogram chart rotated 90 degrees.

- Vertical axis = temperature. Vertical extent shows the range; internal markers typically indicate the median and quartiles.
- Width at any temperature value shows relative frequency (probability density): wider = more common; narrow “necks” = rarer values.
- Read violins for symmetry/skew, spread (how concentrated vs dispersed a month is), and the presence of outliers.

**Questions:**

0. Does your site show strong seasonal variation or relatively constant temperatures?
0. Is the temperature distribution symmetric or skewed?
"""

# ╔═╡ eca15e5f-33bf-4837-98d3-9ba64c9fcdf3
md"""
### 3.2 Autocorrelation
"""

# ╔═╡ 245ca246-0aea-4b0a-a4bf-4c45e9ebfc4f
md"""
Autocorrelation plot shows how today's temperature relates to future temperatures.

- Short lags (0-60 days): Strong correlation means temperature persists day-to-day
- ~183 days: A spike here indicates semi-annual seasonality
- ~365 days: A spike here indicates annual seasonality
- 95% confidence interval (pink band): Values outside are statistically significant (p<0.05)

**How to interpret the decay pattern:**

0. **Temperature typically shows strong persistence:** Autocorrelation often remains significant for 30-90+ days because atmospheric conditions change gradually

0. **Rate of decay matters:**
   - **Slow decay** (stays high for 60+ days) → very stable, slowly changing conditions
   - **Fast decay** (drops to confidence band in <30 days) → more variable, rapidly changing conditions

0. **Look at the shape:**
   - Smooth, gradual decline → persistent weather patterns
   - Rapid drop then leveling → initial persistence followed by randomness

**Important distinction:**

- Statistical significance (outside pink band) ≠ practical predictability.
- Meaningful persistence for daily temperature in Malaysia’s humid tropics is usually concentrated at short lags (order of days to a couple of weeks). Look at the `r` value. Should be r>0.5.
- Long persistence (60+ days significance) indicates the climate has strong "memory" and stable patterns

**Why it matters:**

- Strong 'memory' is high correlation at long lags
- Longer persistence → fewer extreme day-to-day changes
- Shows whether air temperature is stable and predictable
- Shows whether any seasonal transitions are more gradual
- Allows better planning for short-term activities
- Indicate whether any extreme day-to-day fluctuations
- Indicate how strongly current conditions influence weather weeks into the future

**Questions:**

0. How many days ahead can you predict temperature with reasonable confidence? *Hint:* At what lag does the autocorrelation become insignificant for this site?
0. Is there a clear semi-annual and annual cycles (spike at ~183 and ~365 days, respectively)?
0. Why might there be a semi-annual and an annual cycle?
"""

# ╔═╡ 32d4784a-d59b-4f6a-9f46-c53dc93f40e7
md"""
### 3.3 Seasonal Patterns
"""

# ╔═╡ e675760c-c2c7-4743-a96a-18b72a455435
md"""
**What is a running mean?**: A running mean (or moving average) calculates the average of the current day plus the previous days in the window. For example, a 7-day running mean averages today's value with the previous 6 days (7 days total). This smooths out day-to-day fluctuations to reveal broader patterns.

**What to look for**:
- **Color patterns**: Cooler (blue) versus warmer (red) periods
- **Consistency across years**: Do the same calendar days show similar patterns year after year?
- **Anomalies**: Unusual hot or cold spells that stand out from the typical pattern
- **Timing of transitions**: When do seasons shift from cool to warm and vice versa?

**The Window Size Slider - What it does**:
1. **Smaller window (*e.g.*, 1-3 days)**:
   - Less smoothing, closer to actual daily values
   - Shows more day-to-day variation and short-term weather events
   - Heatmap appears more "noisy" with rapid color changes
   - Useful for identifying brief extreme events (cold snaps, heat waves)

2. **Larger window (*e.g.*, 15-30 days)**:
   - More smoothing across time
   - Emphasizes longer-term patterns and seasonal trends
   - Heatmap appears more uniform with gradual color transitions
   - Better for seeing the "big picture" seasonal cycle
   - Individual weather events get averaged out

**Interpretation tip**: 
- Larger windows = more smoothing = clearer seasonal patterns but less detail
- Smaller windows = less smoothing = more detail but harder to see overall trends
- **Caution**: this notebook uses trailing *n*-day running mean. Because of this, apparent peaks are delayed by approximately `(n–1)/2` days. Larger `n` ⇒ larger apparent delay. Example: `n`=28 → ~14‑day delay.

**Why it matters**: 
- Reveals seasonal timing and year-to-year consistency
- Helps identify optimal planting/harvesting windows
- Shows if seasons are shifting earlier or later across years

**Questions**:
0. Adjust the window size. How does the pattern change?
0. Are there specific weeks that are consistently cooler or warmer across all years?
0. Do you see any years with unusual patterns (anomalous seasons)?
"""

# ╔═╡ fbce7664-c0de-496d-be00-10f76dea43b6
begin
	window_tmin_input = @bind window_tmin PlutoUI.Slider(
		1:1:60, default=7, show_value=true)
	
	@htl("""
	<table>
		<tr>
     	 <td style="background-color: #2a4973; color: #ffffff;">Window size:</td>
		 <td>$(window_tmin_input)</td>
		</tr>
	</table>
	""")
end

# ╔═╡ 43113a8f-5841-4789-b9fb-adcb2c48807b
md"""
## 4. Max. Temp
"""

# ╔═╡ dd6fe4f1-7060-4dff-af11-d5f2c50f77c2
md"""
### 4.1 Distribution
"""

# ╔═╡ a9987d0b-ca5e-4063-8ba7-128021588710
md"""
In Malaysian humid, tropical sites, daytime maxima are strongly modulated by cloud cover and wetness through shading and evaporative cooling.

**Compare with minimum temperature**:
- Is the standard deviation larger? (Maximum temps usually vary more)
- Is the distribution shape different?
- What's the typical diurnal range (difference between max and min)?

**Questions**:
0. Do maximum temperatures show more variability than minimum temperatures? Why?
0. How does cloud cover affect maximum temperatures?
"""

# ╔═╡ 462b1e0c-1232-4b2e-9365-d01b2e28be0d
md"""
### 4.2 Autocorrelation
"""

# ╔═╡ c87244ea-48b5-4766-ab5c-52b637ed13a9
md"""
**Look for**:
- Similar patterns to minimum temperature, but possibly weaker correlation
- Does maximum temperature have more or less "memory" than minimum temperature?

**Questions**:
0. Based on the autocorrelation plots for both minimum (3.2) and maximum temperature (4.2), which variable has stronger 'memory'
0. How does temperature 'memory' relate to physical drivers, such as nighttime cooling vs. daytime solar heating?
"""

# ╔═╡ 1e557802-e526-42dd-b9a2-63839e867eea
md"""
### 4.3 Seasonal Patterns
"""

# ╔═╡ 7672cf1c-0219-45ea-ac50-8d724cb25483
md"""
**Compare with section 3.3**:
- Are the hottest times of year the same as when minimum temperatures peak?
- Is there a lag between maximum and minimum temperature seasons?

**Remember**: 
- Larger windows = more smoothing = clearer seasonal patterns but less detail
- Smaller windows = less smoothing = more detail but harder to see overall trends
- **Caution**: this notebook uses trailing *n*-day running mean. Because of this, apparent peaks are delayed by approximately `(n–1)/2` days. Larger `n` ⇒ larger apparent delay. Example: `n`=28 → ~14‑day delay.

**Questions**:
0. Compare the heatmaps in Section 3.3 and 4.3. Do the hottest times of the year (red periods in 4.3) coincide with the warmest nights (red periods in 3.3), or is there a noticeable shift in timing?
0. Are there more variability in daily maximum temperatures than minmum temperatures?
"""

# ╔═╡ b7a4e62b-a2ad-407b-91a3-fdea7843d14f
begin
	window_tmax_input = @bind window_tmax PlutoUI.Slider(
		1:1:60, default=7, show_value=true)
	
	@htl("""
	<table>
		<tr>
     	 <td style="background-color: #2a4973; color: #ffffff;">Window size:</td>
		 <td>$(window_tmax_input)</td>
		</tr>
	</table>
	""")
end

# ╔═╡ d1076ae7-56a8-4e35-9ab0-41455acd893b
md"""
## 5. Wind Speed
"""

# ╔═╡ d231b4a7-7cd8-4497-8c70-231ff3783761
md"""
### 5.1 Distribution
"""

# ╔═╡ a110527e-7fdf-4167-84e4-3c440a91f016
md"""
Daily mean wind speeds are typically right‑skewed and are often better described by a Weibull distribution rather than a normal curve.

**What to look for**:
- **Mean wind speed**: Is this a calm or windy location?
- **Distribution shape**: Wind speed is often right-skewed (occasional high winds)
- **Seasonal pattern**: Look at the monthly violin plots

**Why wind speed matters**:
1. **Disease Management**:
   - Tropics have high humidity and warm temperatures year-round
   - **Low wind + high humidity = ideal conditions for fungal diseases**
   - Stagnant air allows fungal spores to settle and infect plants
   - Higher wind speeds improve air circulation, reducing leaf wetness duration

2. **Evapotranspiration and Water Use**:
   - Wind increases evapotranspiration rates
   - Low wind = lower water demand (less irrigation needed)
   - High wind = higher water stress (more irrigation required)
   - Important for water management in plantations

3. **Pollination**:
   - For wind-pollinated crops, low wind periods can reduce pollination efficiency and fruit set
   - Timing of low wind periods affects yield

4. **Microclimate Control**:
   - Wind affects temperature and humidity around crops
   - In dense plantations (oil palm, rubber), low wind creates hot, humid microclimates
   - Can stress plants or promote disease

5. **Drying and Post-Harvest**:
   - Paddy (rice) and other crops need drying after harvest
   - Wind speeds affect drying rates
   - Low wind = slower drying = higher risk of spoilage

6. **Pest Dispersal**:
   - Wind can spread pests (*e.g.*, bagworms in oil palm)
   - Understanding wind patterns helps predict pest outbreaks

**Questions**: 
0. Based on the violin plot (bottom panel), which months show the lowest mean wind speeds, and what agricultural risks might this present (refer to Why wind speed matters)?
0. Are there recurring breezy periods, where wind speeds are above 3 to 4 m s⁻¹?
0. Plot several sites to determine how does the location of a site affect the typical daily wind speeds. *Hint*: compare coastal vs inland sites, Peninsular vs East Malaysia sites.
"""

# ╔═╡ fb1f648c-5d2e-434d-b456-1d2b08f193e8
md"""
### 5.2 Autocorrelation
"""

# ╔═╡ 269c9adf-2597-46cd-a7c7-297bc9c44681
md"""
Wind speed shows **much weaker autocorrelation** than temperature—often dropping into the confidence band within just a few days.

**Why wind has less "memory"**:
- Wind is driven by **pressure differences** that change rapidly (weather systems, local heating/cooling)
- Temperature changes gradually due to thermal inertia (land/ocean heat up and cool down slowly)
- Daily wind speeds can vary dramatically from one day to the next

**What to look for**:

0. **Short-lag behavior (0-10 days)**:
   - Does autocorrelation drop to near zero quickly (within 5-10 days)?
   - This is normal for wind—it means yesterday's wind doesn't tell you much about next week's wind
   - Compare this to your temperature autocorrelation—wind should be much weaker

0. **Seasonal signals**:
   - **Spike near 365 days**: Indicates **annual wind cycle** (one distinct pattern per year)
   - **Spike near 183 days (~6 months)**: Indicates **semi-annual wind cycle** (two distinct patterns per year)
   - **Both spikes present**: Your site has **bimodal wind patterns**—common in monsoon regions!
   
   **What bimodal patterns mean**:
   - Two wind seasons per year (*e.g.*, Northeast and Southwest monsoons)
   - Wind reverses direction or changes intensity twice annually
   - Example: Malaysia has NE monsoon (~Nov-Mar, windier) and SW monsoon (~May-Sep, calmer)
   - Important for planning: you have two predictable seasonal transitions

0. **Overall pattern**:
   - **Rapid decay then flat**: Typical pattern—initial weak persistence, then essentially random
   - **Consistently low**: Wind is highly variable with little predictability
 - **Small spikes at 183/365**: Weak but predictable seasonal patterns overlaid on daily variability


**Why this matters for agriculture**:

- **Low persistence = high uncertainty**: Cannot reliably predict wind conditions more than a few days ahead
- **Plan for variability**: 
  - Irrigation scheduling should account for unpredictable evapotranspiration rates
  - Spraying operations need flexible timing (wait for calm conditions)
  - Wind-sensitive crops (*e.g.*, banana, papaya) face unpredictable stress

- **If you see seasonal patterns** (365-day spike):
  - Your region has predictable seasonal wind shifts (good for planning)
  - Example: Monsoon regions can anticipate windier/calmer seasons
  - Useful for wind-pollination or field operations like drying (paddy)

**Questions**:
0. How does wind autocorrelation at this current site compare to temperature autocorrelation?
0. Do you see one spike (~365 days) or two spikes (~183 and ~365 days)? Why might wind speeds have only one spike or two spikes in a year?
0. If wind is highly unpredictable (*i.e.*, very low ACF everywhere), what management strategies would you recommend for wind-sensitive operations?
0. The wind-rainfall relationship description mentions coastal versus inland sites. What key wind-related mechanism might be unique to a coastal site?
"""

# ╔═╡ 1429b63b-8122-4351-9407-72272e782b6c
md"""
### 5.3 Seasonal Patterns
"""

# ╔═╡ 5630d61f-d01a-4cf4-b569-0cc0bc00e66f
md"""
**Look for**:
- **Monsoon patterns**: Seasonal wind shifts
- **Land-sea breeze patterns**: In coastal vs inland areas

**Remember**: 
- Larger windows = more smoothing = clearer seasonal patterns but less detail
- Smaller windows = less smoothing = more detail but harder to see overall trends
- **Caution**: this notebook uses trailing *n*-day running mean. Because of this, apparent peaks are delayed by approximately `(n–1)/2` days. Larger `n` ⇒ larger apparent delay. Example: `n`=28 → ~14‑day delay.

**Questions**:
0. When do wind speeds tend to be high and low at this site?
0. Even when wind speeds are at the highest, are they harmful or beneficial for agriculture. Explain your answer.
"""

# ╔═╡ 1c50fe2b-23df-4ba1-8d7e-9a67850f5c9a
begin
	window_wind_input = @bind window_wind PlutoUI.Slider(
		1:1:60, default=7, show_value=true)
	
	@htl("""
	<table>
		<tr>
     	 <td style="background-color: #2a4973; color: #ffffff;">Window size:</td>
		 <td>$(window_wind_input)</td>
		</tr>
	</table>
	""")
end

# ╔═╡ bf717e4b-1ac1-4101-81bf-f82e461133ba
md"""
## 6. Rainfall
"""

# ╔═╡ cffe1909-2e95-4019-bb2f-2afdec26d44e
md"""
### 6.1 Distribution
"""

# ╔═╡ 0999ebf3-6b38-4214-be53-f118c67b7c95
md"""
**Key statistics**:
- **Total annual rainfall**: Indicates how much rainfall in a year. Note: 1 mm rain means 1 L (or 1 kg) of water over 1 m² ground area. So, 2000 mm annual rainfall means 2000 L of water has fallen over 1 m² ground area in a year. 
- **Wet days**: Indicates how many days per year have measurable rain
- **PWW** (Probability Wet-Wet): If today is wet, what is the probability tomorrow will also be wet (*i.e.*, probability of two consecutive wet days)
- **PWD** (Probability Wet-Dry): If today is dry, what is the probability tomorrow will be wet
- **Mean daily rainfall**: Average amount on rainy/wet days

**Histogram interpretation**:
- **First few bars (left of chart)**: Represents dry days and days with light rains, (they are typically 50-80% of days)
- **Long right tail**: Occasional/rare heavy rainfall events

**Questions**:
0. What percentage of annual rainfall comes from extreme events versus light rain?
0. Why is it important in agriculture to know the distribution of wet and dry spell lengths?
0. Extreme heavy rain events occur rarely. So, if they are relatively rare, are they important in agriculture, compared to light rain events? Explain.
"""

# ╔═╡ d69144f5-2aaa-4fb3-a654-02c86aa1126a
md"""
### 6.2 Persistence
"""

# ╔═╡ 1ed28912-0a8c-4642-96e2-40a32a83c28c
md"""
**Spell distributions**:

Wet spell distribution shows the frequency of consecutive rainy days of different lengths (*e.g.*, how often do 3-day, 7-day, or 14-day wet periods occur?). Dry spell distribution shows the same for consecutive dry days.

**Why it matters**:
* Long dry spells → drought risk, crop water stress
* Long wet spells → flooding, delayed field operations, increased disease pressure

**Transition probability matrix (Markov chain)**: Shows probability of tomorrow's state given today's state.
* **Read as**: "If today is [row state], tomorrow will be [column state] with probability [value]"
* **Diagonal values** (*e.g.*, Dry→Dry, Light→Light): Persistence probability—how likely a state continues
* **Off-diagonal values**: Transition probability—how likely states change

High Dry→Dry persistence means dry spells last longer, which can become critical for irrigation scheduling and planting windows.

**Key probabilities**:
* **PWW** (Wet→Wet): Probability wet day follows wet day
* **PWD** (Dry→Dry): Probability dry day follows dry day

Higher PWD lengthens dry spells; higher PWW lengthens wet spells.

**Questions**:
0. Why is knowing rainfall persistence important in agriculture?
0. Examine "Dry→[rain intensity]" transitions: When rain breaks a dry spell, is it typically light or can it be heavy? What are the implications for runoff and soil erosion?
0. Using the transition matrix, what is the total probability that a "Light rain" day (Today's State) will be followed by any type of wet day (Light, Moderate, Heavy, or Very Heavy)?
0. Suppose PWW increases from 0.55 to 0.75, while PWD decreases from 0.20 to 0.10. Explain how this specific shift in transition probabilities alters the agricultural risk profile for the area, focusing on water storage management and the potential for alternating flood and drought stress within the same season.
"""

# ╔═╡ c0f892f0-f11c-4354-9699-577b4c13b2d4
md"""
### 6.3 Monthly Contributions
"""

# ╔═╡ 78c3cc81-0828-46d6-a9e6-88f25982a65f
md"""
Peninsular and East Malaysia sites often show monsoon‑related unimodal or bimodal rainfall contributions, with timing that differs between coasts because of the Northeast and Southwest Monsoons.

**What to look for**:
- **Uniform line**: 8.33% per month (even distribution)
- **Bars above this line**: Wetter months
- **Bars below this line**: Drier months

**Common patterns**:
- **Unimodal**: One rainy season
- **Bimodal**: Two rainy seasons (common in tropics near equator)

**Questions**:
0. Does this site have distinct wet and dry seasons? Refer also to Section 6.6.
0. When does this site tend to experience distint periods of high and low rainfalls? Again, refer also to section 6.6.
0. Explain the impact of seasonal rainfall distribution on agriculture.
"""

# ╔═╡ e8e881ba-96fb-41b3-8b5b-a27151635ee9
md"""
### 6.4 Monthly Variability
"""

# ╔═╡ 27df242c-4752-4898-91cc-24832865827b
md"""
**IQR/Median Ratio) - What it measures**:
The ratio of interquartile range (IQR) to median quantifies rainfall predictability on a relative scale:
* **Low IQR/Median** (<0.5): Consistent rainfall year-to-year → more predictable
* **High IQR/Median** (>1.0): High year-to-year variability → unpredictable

**Why IQR/Median instead of coefficient of variation (CV)?**
Rainfall data are highly skewed (many low values, few extreme highs). CV assumes normally distributed data and is sensitive to outliers. IQR/Median is non-parametric and robust to skewness, making it more appropriate for rainfall.

**Color scale**: Green (predictable) → yellow → red (highly variable)

**Why it matters**:
High variability means farmers face greater uncertainty. A month with median rainfall of 200 mm but high IQR could deliver 50 mm (crop failure) or 400 mm (flooding) in different years. Management strategies must account for this range, not just the average.

**Questions**:
0. How does unpredictable rainfall harm agriculture? *Hint*: Consider: (a) planting timing decisions, (b) crop selection, (c) investment in irrigation/drainage infrastructure.
0. Compare variability during wet versus dry season months. Which season is more predictable, and why might this matter for cropping calendars?
0. If rainfall is highly unpredictable (high IQR/Median), what risk management strategies would you recommend? *Hint*: Consider: crop diversification, insurance, water storage, drought-tolerant varieties.
"""

# ╔═╡ 13429b2e-dac8-46ee-85c4-143945d07074
md"""
### 6.5 Max. Dry Spell Length
"""

# ╔═╡ 893df8c0-d71f-4b45-9de0-674975974403
md"""
**What to look for**:
* **Top panel**: Maximum dry spell length each year vs. critical threshold (red dashed line, set here at 14 consecutive dry days—the approximate point where crop water stress begins)
* **Bottom panel**: Timing of when maximum dry spells occur each year

Compare with sections 6.3 (seasonal rainfall patterns) and 6.4 (spell distributions) to see if long dry spells consistently occur during specific months or are randomly distributed.

**Application**: 

Critical for irrigation scheduling, drought preparedness, and assessing planting window risk. If maximum dry spells frequently exceed the threshold during the growing season, supplemental irrigation or drought-tolerant varieties become necessary.

**Questions**:
0. If the maximum dry spell shown in the Top Panel occurred during a critical crop growth stage, would deficit irrigation (light, strategic watering) or full irrigation be more appropriate? Consider the Mean spell length from the Dry Spell Distribution chart (6.2).

0. The 14-day threshold used here is generic. How would you determine the actual critical threshold for a specific crop? *Hint*: consider rooting depth, growth stage sensitivity, soil water holding capacity.

0. Irrigation clearly benefits crops, so why isn't it widely practiced? Discuss: (a) economic constraints (capital, energy, labor costs), (b) water availability and rights, (c) trade-offs between irrigation methods (flood, sprinkler, drip), and (d) risk of over-irrigation (waterlogging, salinization).
"""

# ╔═╡ d3b95b82-3786-4c19-a135-c4c85dbc4ff1
md"""
### 6.6 Seasonal Patterns
"""

# ╔═╡ 8b0504e1-f480-4191-a4f4-cfe236bee4ef
md"""
**_n_-day running sum heatmap**:
Shows accumulated rainfall over rolling *n*-day windows. Blue/dark indicates heavy rainfall periods; yellow/light indicates dry periods.

**What to look for**:
- Consistency of wet/dry timing across years
- Seasonal patterns and their variability
- Extreme events (very dark blue cells)

**Remember**:
- **Apparent delay**: Trailing sums shift peaks by ~`(n–1)/2` days. Example: `n`=28 causes ~14-day delay in apparent timing.
- **Window size effects**: Larger windows accumulate more rainfall and always appear "wetter." So, do not compare absolute values between different `n` values. Instead, compare timing patterns within one window size, then test sensitivity by varying `n`.

**Questions**:
1. What periods consistently appear wet or dry across years? Compare with section 6.3.
2. How does knowing wet/dry periods help farmers plan operations?
"""

# ╔═╡ f7ceb2cd-bb36-47dc-b3d3-4952149ff453
begin
	window_rain_input = @bind window_rain PlutoUI.Slider(
		1:1:60, default=7, show_value=true)
	
	@htl("""
	<table>
		<tr>
     	 <td style="background-color: #2a4973; color: #ffffff;">Window size:</td>
		 <td>$(window_rain_input)</td>
		</tr>
	</table>
	""")
end

# ╔═╡ 8094903f-4a19-4643-8b18-5c7eb0b8adfb
md"""
## 7. Relationships
"""

# ╔═╡ db705dba-8da8-4d56-bb6a-6ca96a737808
md"""
### 7.1 Temperature-Wind-Rainfall
"""

# ╔═╡ 58e9b26d-d62e-4b9e-976f-d1b49a90fc16
md"""
**Temperature-Wind-Rainfall Relationships**

**Correlation coefficients (`r`)**:
* `r` ≈ –1: strong negative relationship
* `r` ≈ 0: weak or no relationship  
* `r` ≈ +1: strong positive relationship

**Max Temperature vs Wind Speed**:
Relationship is location-dependent. Coastal sites: wind may bring cooler marine air (negative correlation). Inland sites: wind may advect warm or cold air masses depending on source region.

**Wind Speed vs Rainfall**:
Two competing mechanisms:
* **Negative correlation**: Calm conditions favor localized convective rainfall development
* **Positive correlation**: Large-scale storms bring both wind and heavy rain simultaneously

Which dominates depends on the site's rainfall regime (convective vs. frontal/monsoon-driven).

**Normalized seasonal plot**:
Scales all three variables to 0–1 range for direct comparison. Look for which variables peak together (in-phase) versus offset timing (out-of-phase), revealing coupling patterns discussed in Fig. 1.

**Questions**:
0. Why do temperature and rainfall often show negative correlation? *Hint*: consider cloud cover and evaporative cooling.
0. Compare wind-rainfall relationships at one coastal versus one inland site. Are correlations weaker or stronger inland? What drives the difference?
0. In the normalized plot, do temperature and rainfall peak in the same month(s)?
"""

# ╔═╡ ff9b154e-7440-4095-ae5d-490c632714b4
md"""
### 7.2 Rainfall Anomaly
"""

# ╔═╡ 0ac6a248-ea47-4274-a043-3923aefef296
md"""
**Definition**: 

Anomaly = Observed rainfall − Climatological average (for that location and time period)

This measures **departure from normal** (that is, deviation from typical rainfall for that site), not whether rainfall is sufficient for crops.

**What it tells you**:
- **Positive anomaly**: Wetter than usual for that location/season
- **Negative anomaly**: Drier than usual for that location/season
- **Zero anomaly**: Rainfall matches the long-term average

**Key distinction**:
* **Anomaly** answers: "Is this wetter/drier than typical?"
* **Deficit/surplus** answers: "Is rainfall enough to meet water demand (ET₀)?"

A location can have **positive rainfall anomaly** (wetter than usual) but still experience **water deficit** if evaporative demand exceeds rainfall. Conversely, a **negative anomaly** (drier than usual) may still meet crop needs if demand is low.

**Why anomalies matter**:
- Removes location bias (100 mm is "wet" in arid zones, but "dry" in rainforest)
- Reveals unusual conditions that stress ecosystems/agriculture
- Enables comparison across different climates

**Reference period dependency**:

Anomalies depend on what you define as "normal." Standard practice uses 30-year climatological periods (*e.g.*, 1991–2020). Short datasets produce unreliable anomalies since the "average" itself may not represent true climate.

**Tip**:

Set the window size that matches the crop’s growing length (*e.g.*, 30-35 days for leafy vegetables) or sensitive stage length (*e.g.*, 30–45 days for early establishment versus 60–90 days for reproductive and grain filling in many tropical annuals).


**Questions**:
0. The text distinguishes between Anomaly and Deficit/Surplus. Explain how a month could have a positive rainfall anomaly (wetter than usual) but still experience water deficit (crop water stress).
0. Why might a +50 mm anomaly be severe in one location but minor in another?
0. Are there any cycles of sustained wetter and drier periods? How long do these cycles typically last?
0. How might these sustained wet/dry cycles affect planting decisions or crop selection for farmers?
0. Refer to the Rainfall Anomaly Over Time chart (second panel). Why does positive rainfall anomaly change more slowly than negative rainfall anomaly? *Hint*: Refer to section 6.1.
"""

# ╔═╡ b63dacdf-b6f1-4844-b1ea-b0944f2ac206
begin
	window_rain_deficit_input = @bind window_rain_decifit PlutoUI.Slider(
		[7, 30:30:180...], default=60, show_value=true)
	
	@htl("""
	<table>
		<tr>
     	 <td style="background-color: #2a4973; color: #ffffff;">Window size:</td>
		 <td>$(window_rain_deficit_input)</td>
		</tr>
	</table>
	""")
end

# ╔═╡ f9393768-1fad-4327-ab2f-4b2221b92bf5
md"""
### 7.3 Soil Water Storage
"""

# ╔═╡ 1b871b02-3dbd-4388-b5ee-d9ab39f5e7b9
md"""
Daily soil moisture is estimated using a water balance approach:
* **Inputs**: Rainfall (water added to soil)
* **Outputs**: Reference evapotranspiration (ET₀, calculated from temperature, humidity, wind, radiation, and latitude using [FAO‑56 Penman–Monteith] (https://www.fao.org/4/x0490e/x0490e06.htm) method)
* **Daily change**: Soil storage increases with rainfall, decreases with ET₀

**Available Water Capacity (AWC)**:

AWC represents the soil's maximum water storage, which is the difference between field capacity (water held after drainage) and permanent wilting point (where plants can no longer extract water). Think of AWC as the soil's "water tank capacity."

* **200 mm m⁻¹ AWC**: A 1-m deep soil column can store 200 L of plant-available water
* **50 mm m⁻¹ AWC**: Same volume stores only 50 L (*e.g.*, sandy soil vs. loam)

AWC is estimated from soil texture (clay and sand content) using pedotransfer functions ([Saxton et al., 1986](https://doi.org/10.2136/sssaj1986.03615995005000040039x)).

**Heatmap interpretation**:
* **Dark blue**: Near field capacity (soil *water tank* nearly full)
* **Light blue**: Adequate moisture (>50% AWC)
* **Orange/light red**: Depleting (<50% AWC, stress begins)
* **Dark red**: Severely dry (near wilting point)

**What to look for**:
* Frequency of full recharge events
* Duration and timing of water stress periods (<30–50% AWC)
* Recovery time after dry spells

**Why it matters**:

Soil water storage directly determines crop water availability. Most crops experience stress when storage drops below 30–50% AWC, triggering yield loss even before visible wilting. This metric integrates rainfall and atmospheric demand to show actual plant-available water, which is the most critical variable for agricultural decision-making.

**Questions**:
0. If planting a 90-day crop requiring adequate moisture throughout, which months offer the most reliable planting windows (fewest stress periods)?
0. Compare the Soil Water Heatmap (7.3) with the Max Temperature Heatmap (4.3). Do periods of low soil water (red/orange) coincide with the highest maximum temperatures (red/darker periods)? What specific vulnerability does this combined heat and water stress pose to crops?
0. How is evapotranspiration related to soil water balance? How is field evapotranspiration typically measured?
0. Consider two adjacent fields managed under rainfed conditions: Field A has a sandy loam texture (10% clay, 65% sand), and Field B has a silty clay loam texture (35% clay, 10% sand). What is the AWC of the soil in Field A and B?
0. Continuing the previous question, if the region experiences high rainfall persistence (high PWW), describe how the management strategy (*e.g.*, drainage needs, timing of nitrogen application) should differ between Field A and Field B.
"""

# ╔═╡ 4fe9fbb9-d10b-400f-96d9-05bf799f6879
begin
	@with_kw mutable struct CropProp
		kc::Float64 = 0.5
		dg::Float64 = 1.0
		stress::Float64 = 0.5
	end
	
	# Crop database
	crop_db = OrderedDict(
	    "Oil Palm" => CropProp(0.85, 1.5, 0.35),
	    "Rice (vegetative)" => CropProp(1.05, 0.3, 0.50),
	    "Rice (reproductive)" => CropProp(1.2, 0.3, 0.60),
	    "Banana" => CropProp(1.1, 0.6, 0.45),
	    "Pineapple" => CropProp(0.5, 0.3, 0.30),
	    "Reference (grass)" => CropProp(1.0, 1.0, 0.40)
	)

	sel_croptype = @bind croptype PlutoUI.Select(collect(keys(crop_db)))
	sand_input = @bind sand PlutoUI.Slider([5:1:95...], default=30, show_value=true)
	clay_input = @bind clay PlutoUI.Slider([5:1:60...], default=30, show_value=true)
	
	@htl("""
		<table cellpadding="0" cellspacing="0" class="load-table">
		<tr>
			<th>Crop/soil info</th>
			<th>Values</th>
		</tr>
		<tr>
			<td>Crop type</td>
			<td><div class="data-display">$(sel_croptype)</div></td>
		</tr>
		<tr>
			<td>Soil clay content (range 5-60%)</td>
			<td><div class="data-display">$(clay_input)</div></td>
		</tr>
		<tr>
			<td>Soil sand content (range 5-95%)</td>
			<td><div class="data-display">$(sand_input)</div></td>
		</tr>
		</table>
	 
	""")
end

# ╔═╡ 52bd99e5-64c0-4520-a4bf-cb4c40dbc720
begin
	crop_prop = crop_db[croptype]

	@bind init confirm(PlutoUI.combine() do Child
		inputs = [
			Child(:kc, PlutoUI.TextField(default=string(crop_prop.kc))),
			Child(:dg, PlutoUI.TextField(default=string(crop_prop.dg))),
			Child(:stress, PlutoUI.TextField(default=string(crop_prop.stress))),
		]

		@htl("""
			<table cellpadding="0" cellspacing="0" class="load-table">
			<tr>
				<th>$(croptype)</th>
				<th>Crop values</th>
			</tr>
			<tr>
				<td>Crop coefficient Kc (>0)</td>
				<td><div class="data-display">$(inputs[1])</div></td>
			</tr>
			<tr>
				<td>Root depth (>0 m)</td>
				<td><div class="data-display">$(inputs[2])</div></td>
			</tr>
			<tr>
				<td>Drought sensitivity (0=least to 1=most sensitive)</td>
				<td><div class="data-display">$(inputs[3])</div></td>
			</tr>
			</table>
		""")
	end; label="🔄 Update Soil Water Storage")
end

# ╔═╡ 63f62bc8-7673-49c5-ba40-18c3a1dbebcf
TableOfContents()

# ╔═╡ e20a1060-ab8a-4577-a251-ce0e5f89a023
begin
	const SKEW_THRESHOLD = 0.995272
	const N_SAMPLES = 1_000
	const KDE_SAMPLES = 10_000
	const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun",
					"Jul","Aug","Sep","Oct","Nov","Dec"]
	
	mths() = MONTHS[1:12]
	
	
	function gen_weather(csv_path, seed)
		isempty(csv_path) && return DataFrame()

		seednum = (seed < 0) ? rand(1:typemax(Int)) : seed
		Random.seed!(seednum)
		@info "Seed no. $(seednum)"
		
		res = csv2df(csv_path)
		nt = generate_mets(res.df; verbose=false)
		df = collate_mets(nt)
		lat = res.lat
		
		res = et0_vpd.(lat, df.doy, df.tmin, df.tmax, df.wind)
		df.et0 = getproperty.(res, :et0)
	    df.vpd = getproperty.(res, :vpd)
		(df, lat)
	end

	
	function obs_weather(csv_path)
	    isempty(csv_path) && return (DataFrame(), 0.0)
	    
	    res = csv2df(csv_path)
	    df = res.df
	    lat = res.lat
	    
	    if !hasproperty(df, :doy)
	        df.doy = zeros(Int, nrow(df))
	        current_doy = 1
	        current_year = df.year[1]
	        
	        for i ∈ 1:nrow(df)
	            if df.year[i] != current_year
	                current_doy = 1
	                current_year = df.year[i]
	            end
	            
	            df.doy[i] = current_doy
	            current_doy += 1
	        end
	    end

		res = et0_vpd.(lat, df.doy, df.tmin, df.tmax, df.wind)
	    df.et0 = getproperty.(res, :et0)
	    df.vpd = getproperty.(res, :vpd)
		
		(df, lat)
	end

		
	function et0_vpd(lat, doy, Tmin, Tmax, wind; elev=50.0, kRs=0.16)
	    STEFAN_BOLTZMANN = 4.903e-9  # MJ K⁻⁴ m⁻² day⁻¹
	    SOLAR_CONSTANT = 0.0820      # MJ m⁻² min⁻¹
	    ALBEDO = 0.23                # for grass reference surface

	    Tmean = (Tmax + Tmin) / 2.0
	    P = 101.3 * ((293.0 - 0.0065 * elev) / 293.0)^5.26
	    γ = 0.000665 * P
	    es_Tmax = 0.6108 * exp((17.27 * Tmax) / (Tmax + 237.3))
	    es_Tmin = 0.6108 * exp((17.27 * Tmin) / (Tmin + 237.3))
	    es = (es_Tmax + es_Tmin) / 2.0
	    ea = 0.6108 * exp((17.27 * Tmin) / (Tmin + 237.3))
	    vpd = es - ea
	    Δ = (4098 * es) / ((Tmean + 237.3)^2)
	    lat_rad = lat * π / 180.0
	    δ = 0.409 * sin(2π * doy / 365.0 - 1.39)
	    ωs = acos(-tan(lat_rad) * tan(δ))
	    dr = 1.0 + 0.033 * cos(2π * doy / 365.0)
	    Ra = (24.0 * 60.0 / π) * SOLAR_CONSTANT * dr * 
	         (ωs * sin(lat_rad) * sin(δ) + cos(lat_rad) * cos(δ) * sin(ωs))
		Rs = kRs * sqrt(Tmax - Tmin) * Ra
	    Rso = (0.75 + 2e-5 * elev) * Ra
	    Rns = (1.0 - ALBEDO) * Rs
	    Tmin_K = Tmin + 273.16
	    Tmax_K = Tmax + 273.16
	    Rnl = STEFAN_BOLTZMANN * ((Tmax_K^4 + Tmin_K^4) / 2.0) *
	          (0.34 - 0.14 * sqrt(ea)) *
	          (1.35 * Rs / Rso - 0.35)
	    Rn = Rns - Rnl
	    G = 0.0
	    numerator = 0.408 * Δ * (Rn-G) + γ * (900.0 / (Tmean+273.0)) * wind * vpd
	    denominator = Δ + γ * (1.0 + 0.34 * wind)
	    et0 = max(0.0, numerator / denominator)
		(; et0=et0, vpd=vpd)
	end
		

	function est_awc(c, s)
	    s2 = s^2
	    coef_a = exp(-4.396 - 0.0715 * c - 0.000488 * s2 - 0.00004285 * s2 * c)
	    coef_b = -3.14 - 0.00222 * c^2 - 0.00003484 * s2 * c
	    b = 1 / coef_b
	    fc = (0.33333 / coef_a) ^ b    # FC
	    pwp = (15 / coef_a) ^ b        # PWP
	    fc - pwp
	end

	
	function quick_msg(msg; secs=10)
		@htl("""
		<div id="temp-msg">
		    <p>$(msg)</p>
		</div>
		<script>
		    setTimeout(() => {
		        document.getElementById('temp-msg').remove();
		    }, $(secs*1000));
		</script>
		""")
	end


	function show_empty_chart(msg, width)
		fig = Figure(size=(width, 200))
		ax = Axis(fig[1, 1])
		hidedecorations!(ax)
		text!(ax, 0.5, 0.5, text=msg, align=(:center, :center), space=:relative)
		fig
	end	

	
	function fit_skewnorm(samples)
	    sample_mean = mean(samples)
	    sample_sd = std(samples)
	    sample_skew = skewness(samples)
	    fn = abs(sample_skew) < SKEW_THRESHOLD ? normal_skew : high_skew
	    fn(sample_mean, sample_sd, sample_skew)
	end

	
	function normal_skew(avg, sd, sk)
	    sk2_3 = abs(sk) ^ (2 / 3)
	    n1 = 0.5 * pi * sk2_3
	    n2 = sk2_3 + ((4 - pi) / 2) ^ (2 / 3)
	    delta = copysign(sqrt(n1 / n2), sk)
		delta >= 1
	    α = delta / sqrt(1 - delta ^ 2)
	    δ = α / sqrt(1 + α^2)
	    ω = sqrt(sd^2 / (1 - 2 * δ^2 / pi))
	    ξ = avg - ω * sqrt(2 / pi) * δ
	    SkewNormal(ξ, ω, α)
	end
	

	function high_skew(avg, sd, sk)
	    sk1 = abs(sk)
	    sk2 = sk1^2
	    df2 = 500
	    d6 = df2 - 6
	    d4 = df2 - 4
	    d2 = df2 - 2
	    a = sqrt(-32 * d4 + sk2 * d6^2)
	    b = d2 * (-d6 * sk1 + a)
	    df1 = -b / (2 * a)
	
	    fsample = rand(FDist(df1, df2), KDE_SAMPLES)
	    fmean = mean(fsample)
	    fsd = std(fsample)
	    new_samples = avg .+ (fsample .- fmean) .* sd ./ fsd
	
	    if sk < 0
	        new_samples = mean(new_samples) .- new_samples
	    end
	
	    new_samples = new_samples .+ (avg .- mean(new_samples))
	    kde(new_samples)
	end	
	

	fit_weibull(samples) = weibull_dist(mean(samples), std(samples),
								        first(autocor(samples, [1])))
	
	
	function weibull_dist(μ, σ, ρ)
	    σₑ = sqrt(σ^2 * (1 - ρ^2))
	    shape = (σₑ / μ)^-1.086
	    scale = μ / gamma(1 + 1/shape)
	    Weibull(shape, scale)
	end


	fmt(val) = (val>=0) ? @sprintf("+%.2f", val) : @sprintf("-%.2f", abs(val))	
		
		
	function calc_pww_pwd(rainfall)
		is_wet = rainfall .> 0.0

		wet_to_wet = 0
		wet_to_dry = 0
		dry_to_wet = 0
		dry_to_dry = 0

		for i ∈ 2:length(rainfall)
			if is_wet[i-1] && is_wet[i]
				wet_to_wet += 1
			elseif is_wet[i-1] && !is_wet[i]
				wet_to_dry += 1
			elseif !is_wet[i-1] && is_wet[i]
				dry_to_wet += 1
			else
				dry_to_dry += 1
			end
		end

		n1 = wet_to_wet + wet_to_dry
		n2 = dry_to_wet + dry_to_dry
		pww = (n1>0) ? wet_to_wet / n1 : 0.0
		pwd = (n2>0) ? dry_to_wet / n2 : 0.0
		(pww, pwd)
	end
		
	
	Markdown.parse("🙈 _unhide core code_")
end	

# ╔═╡ b50f3995-152f-44ca-926b-42dc893798ef
# Generate weather or load observed weather
begin
	df, lat = isempty(csv_path) ? (DataFrame(), 0.0) :
		          inputs.usetype == "observed" ? obs_weather(csv_path) : 
			      gen_weather(csv_path, parse(Int, inputs.seed))

	if !isempty(df)
		site_path = dirname(csv_path)
		if inputs.usetype == "generate"
			wthr_path = joinpath(site_path, "wthr.csv")
			CSV.write(wthr_path, df)
			txt = "Generated weather file saved to: '$(wthr_path)'"
		else
			txt = "Observed weather file loaded: '$(csv_path)'"
		end

		@info "$txt"
		@htl("""<script>alert('✓ ' + $(txt));</script>""")
	end
end

# ╔═╡ add04be8-dce7-49f0-8390-3dea2076d2d7
begin
	function plot_distribution(df; par=:tmin, width=700)
		if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
		end
		
		# Variable settings
	    var_settings = Dict(
	        :tmin => (label="Min. temp.", unit="°C", 
					  column=:tmin, dist_type=:skewnorm),
	        :tmax => (label="Max. temp.", unit="°C", 
					  column=:tmax, dist_type=:skewnorm),
	        :wind => (label="Wind speed", unit="m s⁻¹", 
					  column=:wind, dist_type=:weibull)
	    )
	    
	    # Get settings for chosen variable
	    vset = var_settings[par]
	    is_wind = (par == :wind)
	    
	    # Extract all samples
	    all_samples = df[!, vset.column]
	    
	    # Get year information
	    years = unique(df.year)
	    nyears = length(years)
	    firstyear = minimum(years)
	    lastyear = maximum(years)
	    
	    # Fit appropriate distribution
	    all_dist = is_wind ? fit_weibull(all_samples) : fit_skewnorm(all_samples)
	    
	    # Calculate statistics
	    avg = round(mean(all_samples), digits=2)
	    sd = round(std(all_samples), digits=2)
	    rlag = round(first(autocor(all_samples, [1])), digits=2)
	    
	    # Year range text
	    txt = nyears > 1 ? 
	          "$nyears years: $firstyear-$lastyear" :
	          "$nyears year: $firstyear"
	    
	    fig = Figure(size=(width, 1050))

		# ========== Panel 1: Histogram with PDF ==========
	    # Title includes skewness for temperature, not for wind
	    title_str = if is_wind
	        "$(vset.label) Distribution ($txt)\n(μ=$avg, σ=$sd, r=$rlag)"
	    else
	        sk = round(skewness(all_samples), digits=2)
	        "$(vset.label) Distribution ($txt)\n(μ=$avg, σ=$sd, r=$rlag, γ=$sk)"
	    end
	    
	    ax1 = Axis(fig[1, 1],
	               xlabel="$(vset.label) ($(vset.unit))",
	               ylabel="Density",
	               title=title_str)
	    
	    hist!(ax1, all_samples, bins=30, normalization=:pdf,
	          color=(:skyblue, 0.7), strokecolor=:black, strokewidth=1)
	    
	    x_min, x_max = extrema(all_samples)
	    x_range_pdf = range(x_min, x_max, length=N_SAMPLES)
	    
	    # For wind (Weibull), always use broadcasting; for temp, check skewness
	    if is_wind
	        y_range_pdf = pdf.(all_dist, x_range_pdf)
	    else
	        sk = skewness(all_samples)
	        bNormalSkew = (abs(sk) < SKEW_THRESHOLD)
	        y_range_pdf = bNormalSkew ? pdf.(all_dist, x_range_pdf) : 
	                                    pdf(all_dist, x_range_pdf)
	    end
	    
	    lines!(ax1, x_range_pdf, y_range_pdf, color=:blue, linewidth=2)
	    
	    # ========== Panel 2: Time series with Fourier fit ==========
	    total_days = length(all_samples)
	    t = collect(0:(total_days-1))
	    
	    @. fourier_model(t, p) = p[1] + 
	                             p[2]*cos(2π*t/365) + p[3]*sin(2π*t/365) +
	                             p[4]*cos(4π*t/365) + p[5]*sin(4π*t/365)
	    
	    # Different initial guesses for wind vs temperature
	    p0 = is_wind ? [mean(all_samples), 0.3, 0.3, 0.2, 0.2] :
	                   [mean(all_samples), 5.0, 5.0, 1.0, 1.0]
	    
	    fit = curve_fit(fourier_model, t, all_samples, p0)
	    full_trend_curve = fourier_model(t, fit.param)
	    
	    # Extract coefficients
	    a0 = round(fit.param[1], digits=2)
	    a1, b1, a2, b2 = fmt.(fit.param[2:end])
	    
	    # Create equation string
	    eq_str = L"f(t)=%$(a0)%$(a1)\cos(\omega t)%$(b1)\sin(\omega t)%$(a2)\cos(2\omega t)%$(b2)\sin(2\omega t)"
	    
	    # Y-axis limits: wind starts at 0, temperature allows negative
	    vmin, vmax = extrema(all_samples)
	    ymin = is_wind ? 0 : vmin * 0.95
	    ymax = vmax * 1.05
	    
	    # Create x-axis ticks: year numbers
	    tick_positions = [1 + (i-1) * 365 for i in 1:(nyears+1)]
	    tick_labels = string.(1:(nyears+1))
	    
	    ax2 = Axis(fig[2, 1],
	               xlabel="Year",
	               ylabel="$(vset.label) ($(vset.unit))",
	               title=eq_str,
	               limits=(0, length(all_samples) + 10, ymin, ymax),
	               xticks=(tick_positions, tick_labels))
	    
	    # Scatter plot of all concatenated data
	    x_range = 1:length(all_samples)
	    scatter!(ax2, x_range, all_samples, 
	             color=:red, markersize=3,
	             strokecolor=:black, strokewidth=0.5)
	    
	    # Plot trend curve
	    lines!(ax2, 1:length(full_trend_curve), full_trend_curve,
	           color=:darkgreen, linewidth=3, linestyle=:solid)
	
	    # ========== Panel 3: Monthly violins ==========
	    ax3 = Axis(fig[3, 1],
	               xlabel = "Month",
	               ylabel = "$(vset.label) ($(vset.unit))",
	               xticks = (1:12, mths()))
	    
	    violin!(ax3, df.month, all_samples,
	            datalimits = extrema,
	            color = (:skyblue, 0.7),
	            show_median = true,
	            strokecolor = :black,
	            strokewidth = 1)
	    
	    refline = hlines!(ax3, [avg], color=:red, linestyle=:dash, linewidth=2)
	    
	    # Legend
	    Legend(fig[4, 1], [refline], ["Overall mean"], 
	           framevisible=false, tellwidth=false)
	    rowsize!(fig.layout, 4, 0)
	    
	    fig
	end

	
	fig_dist_tmin = plot_distribution(df; par=:tmin, width=width)
end |> WideCell(; max_width=width)

# ╔═╡ 52768246-c7e3-4d64-a6f9-cc1e342d1950
begin
	fig_dist_tmax = plot_distribution(df; par=:tmax, width=width)
end |> WideCell(; max_width=width)	

# ╔═╡ 8393867f-17a8-4eaa-a122-3ef3dd2ddfc8
begin
	fig_dist_wind = plot_distribution(df; par=:wind, width=width)
end |> WideCell(; max_width=width)	

# ╔═╡ 51f6d474-2641-4dbb-93dc-c54ab46dff42
begin
	function plot_acf(df; par=:tmin, width=700)
	    if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
	    # Variable settings
	    var_settings = Dict(
	        :tmin => (label="Min. temp.", unit="°C", column=:tmin),
	        :tmax => (label="Max. temp.", unit="°C", column=:tmax),
	        :wind => (label="Wind speed", unit="m s⁻¹", column=:wind)
	    )
	    
	    # Get settings for chosen variable
	    vset = var_settings[par]
	    
	    # Extract all samples
	    all_samples = df[!, vset.column]
	    
	    # Get year information
	    years = unique(df.year)
	    nyears = length(years)
	    firstyear = minimum(years)
	    lastyear = maximum(years)
	    
	    fig = Figure(size=(width, 500))
	    
	    if nyears < 2
			return show_empty_chart("Need ≥2 years of data to plot.", width)
	    end
	    
	    max_lag = 400
	    acf_values = autocor(all_samples, 0:max_lag)
	    
	    n = length(all_samples)
	    conf_bound = 1.96 / sqrt(n)
	    
	    lag_ticks = [0, 60, 120, 180, 240, 300, 365, 400]
	    lag_labels = [string(x) for x in lag_ticks]
	    
	    # Year range text
	    txt = nyears > 1 ? 
	          "$nyears years: $firstyear-$lastyear" :
	          "$nyears year: $firstyear"
	    
	    ax = Axis(
	        fig[1, 1],
	        xlabel="Lag (days)",
	        ylabel="Autocorrelation",
	        title="$(vset.label) Autocorrelation ($txt)",
	        xticks=(lag_ticks, lag_labels),
	        limits=(-5, max_lag+5, nothing, nothing)
	    )
	    
	    stem!(ax, 0:max_lag, acf_values, color=:steelblue,
	          strokecolor=:steelblue, stemwidth=0.5, markersize=5)
	    
	    band!(ax, 0:max_lag, 
	          fill(-conf_bound, max_lag + 1),
	          fill(conf_bound, max_lag + 1),
	          color=(:red, 0.2), label="95% confidence interval")
	    hlines!(ax, [0], color=:black, linewidth=1)
	    
	    # Mark important lags
	    vlines!(ax, [183], color=:green, linestyle=(:dot, :dense), linewidth=1.5)
	    vlines!(ax, [365], color=:blue, linestyle=(:dot, :dense), linewidth=1.5)
	    
	    textlabel!(ax, Point2f(183, 0.95), text="½ yr", fontsize=12, font=:bold,
	               text_align=(:center, :top))
	    textlabel!(ax, Point2f(365, 0.95), text="1 yr", fontsize=12, font=:bold,
	               text_align=(:center, :top))
	    
	    axislegend(ax, position=(0.1, 0.95), framevisible=false, padding=(0,0,0,0))
	    
	    fig    
	end

	fig_acf_tmin = plot_acf(df; par=:tmin, width=width)
end  |> WideCell(; max_width=width)

# ╔═╡ 92e366d3-61d0-46e7-9c34-448697dc2aeb
begin
	fig_acf_tmax = plot_acf(df; par=:tmax, width=width)
end  |> WideCell(; max_width=width)	

# ╔═╡ 5825a5cb-a0be-49cd-be3d-c94161f8bc31
begin
	fig_acf_wind = plot_acf(df; par=:wind, width=width)
end  |> WideCell(; max_width=width)	

# ╔═╡ 8000997f-84da-4420-b26e-fac3e7497a38
begin
	function plot_hovmoller(df; par=:tmin, window=7, width=700)
	    if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
		end
	    
	    # Variable settings
	    var_settings = Dict(
	        :tmin => (label="Min. temp.", unit="°C", column=:tmin, n_colors=10),
	        :tmax => (label="Max. temp.", unit="°C", column=:tmax, n_colors=10),
	        :wind => (label="Wind speed", unit="m s⁻¹", column=:wind, n_colors=15)
	    )
	    
	    # Get settings for chosen variable
	    vset = var_settings[par]
	    
	    # Get year information
	    years = sort(unique(df.year))
	    nyears = length(years)
	    firstyear = minimum(years)
	    lastyear = maximum(years)
	    
	    if nyears < 2
			return show_empty_chart("Need ≥2 years of data to plot.", width)
		end
	    
	    # === Prepare DOY data with running mean ===
	    max_days = 365
	    hovmoller_doy = fill(NaN, nyears, max_days)
	    
	    # Running mean window size
	    half_window = window ÷ 2
	    
	    for (yn_idx, year) in enumerate(years)
	        # Get data for this year
	        year_data = filter(row -> row.year == year, df)
	        year_values = year_data[!, vset.column]
	        
	        # Only process first 365 days (skip leap day if present)
	        n_days = min(length(year_values), 365)
	        
	        for doy in 1:n_days
	            # Calculate running mean centered on this day
	            start_idx = max(1, doy - half_window)
	            end_idx = min(n_days, doy + half_window)
	            hovmoller_doy[yn_idx, doy] = mean(year_values[start_idx:end_idx])
	        end
	    end
	    
	    # === Calculate color range ===
	    all_values = df[!, vset.column]
	    data_min = minimum(all_values)
	    data_max = maximum(all_values)
	    
	    # === Create figure ===
	    year_range = firstyear:lastyear
	    panel_height = max(250, nyears * 80)
	    fig_height = panel_height + 50
	    fig = Figure(size=(width, fig_height))
	    
	    # X-axis labels: first day of each month + end of year
	    month_starts = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 365]
	    month_labels = [string(v) for v in month_starts]
	    
	    # === Running Mean ===
	    ax_doy = Axis(
	        fig[1, 1],
	        xlabel="Day of Year",
	        ylabel="Year",
	        title="$(vset.label) - $window-Day Running Mean ($nyears years: " *
	              "$(first(year_range))-$(last(year_range)))",
	        xticks=(month_starts, month_labels),
	        yticks=(1:nyears, string.(year_range))
	    )
	    
	    n_colors = vset.n_colors
	    cmap = cgrad(:coolwarm, n_colors, categorical=true)
	    hm_doy = heatmap!(ax_doy, 1:max_days, 1:nyears, hovmoller_doy',
	                      colormap=cmap, colorrange=(data_min, data_max),
	                      interpolate=false)
	    
	    # Add gridlines
	    for i in 0:nyears
	        hlines!(ax_doy, [i + 0.5], color=:black, linewidth=0.5, alpha=0.3)
	    end
	    
	    for day in month_starts
	        vlines!(ax_doy, [day + 0.5], color=:black, linewidth=0.5, alpha=0.2)
	    end
	    
	    # Calculate colorbar ticks
	    bin_width = (data_max - data_min) / n_colors
	    tick_positions = [data_min + bin_width * i for i in 0:n_colors]
	    tick_labels = [string(round(pos, digits=1)) for pos in tick_positions]
	    
	    Colorbar(fig[2, 1], hm_doy, 
	             label="$window-day average $(vset.label) ($(vset.unit))", 
	             vertical=false, flipaxis=false,
	             ticks=(tick_positions, tick_labels))
	    
	    fig
	end
	
	
	fig_hov_tmin = plot_hovmoller(df; par=:tmin, 
			  					  window=window_tmin, width=width)
end |> WideCell(; max_width=width)

# ╔═╡ 1f1d5a9e-53b4-42ef-9801-78254dbe45c5
begin
	fig_hov_tmax = plot_hovmoller(df; par=:tmax, 
			 					  window=window_tmax, width=width)
end |> WideCell(; max_width=width)	

# ╔═╡ 4bcdc54a-5591-46c0-a1fd-e2bfa8e20553
begin
	fig_hov_wind = plot_hovmoller(df; par=:wind, 
								  window=window_wind, width=width)
end |> WideCell(; max_width=width)	

# ╔═╡ 5541a862-4ba6-4c05-b9c0-eaff4227e649
begin
	function plot_rain_distribution(df; width=700)
	    if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
	    # Collect all data
	    all_samples = df[!, :rain]

	    # Get year information
	    years = unique(df.year)
	    nyears = length(years)
	    firstyear = minimum(years)
	    lastyear = maximum(years)

		totrain = round(sum(all_samples) / nyears, digits=1)
	    pww, pwd = round.(calc_pww_pwd(all_samples), digits=2)

	    # Check if there's any rain
	    wet_days = filter(>(0), all_samples)
	    n_wet = length(wet_days)
	    n_dry = length(all_samples) - n_wet

	    if n_wet == 0
			return show_empty_chart("No rainfall in any year!", width)
	    end

	    # Top plot: Histogram of WET DAYS only
		if nyears > 1
			txt = "$(nyears) years: $(firstyear)-$(lastyear))"
		else
			txt = "$(nyears) year: $(firstyear)"
		end

		mean_n_wet = round(Int, n_wet / nyears)

		fig = Figure(size=(width, 1050))
	    ax1 = Axis(fig[1, 1:2],
	               xlabel = "Daily rainfall amount (mm)",
	               ylabel = "Density",
	               title = "Rainfall ($(txt) \n" *
	                       "(Mean: total=$(totrain)mm, wet days=$mean_n_wet, " *
	                       "PWW=$(pww), PWD=$(pwd))")

	    # Histogram of wet days only
	    hist!(ax1, wet_days, bins=30, normalization=:pdf,
	          color=(:skyblue, 0.7), strokecolor=:black, strokewidth=1,
	          label="Generated")

	    # Add mean line
	    mean_wet = mean(wet_days)
	    vlines!(ax1, mean_wet, color=:red, linestyle=:dash,
	            linewidth=2, label="Mean: $(round(mean_wet, digits=1))mm")

	    axislegend(ax1, position=:rt)

		# 2nd row plot: rainfall intensity categories
		categories = ["Light\n(<10mm)", "Moderate\n(10-30mm)",
		              "Heavy\n(30-60mm)", "Very Heavy\n(>60mm)"]
		thresholds = [0, 10, 30, 60, Inf]
		
		counts = [count(t1 .< wet_days .<= t2)
		          for (t1, t2) in zip(thresholds[1:end-1], thresholds[2:end])]
		
		# Calculate percentages
		total_wet = sum(counts)
		percentages = (counts ./ total_wet) .* 100
		
		ax2 = Axis(fig[2, 1:2],
		           xlabel="Intensity category",
		           ylabel="Number of days",
		           title="Rainfall Intensity Distribution Across All Years",
		           limits=(nothing, nothing, 0, maximum(counts) * 1.15),
		           xticks=(1:4, categories))
		
		colors = Makie.wong_colors()[1:4]
		barplot!(ax2, 1:4, counts, color=colors,
		         strokecolor=:black, strokewidth=1)
		
		for (i, (count, pct)) in enumerate(zip(counts, percentages))
		    if count > 0
		        text!(ax2, i, count, 
		              text="$(round(pct, digits=1))%",
		              align=(:center, :bottom), offset=(0, 5))
		    end
		end
		
		# 3rd row: Spell lengths
	    # Calculate spell lengths
	    wet_spells = Int[]
	    dry_spells = Int[]
	    current_spell = 0
	    is_wet = all_samples[1] > 0
	    
	    for r ∈ all_samples
	        curr_wet = r > 0
	        if curr_wet == is_wet
	            current_spell += 1
	        else
	            if is_wet
	                push!(wet_spells, current_spell)
	            else
	                push!(dry_spells, current_spell)
	            end
	            current_spell = 1
	            is_wet = curr_wet
	        end
	    end
	    
	    ax3 = Axis(fig[3, 1],
	               xlabel = "Spell length (days)",
	               ylabel = "Frequency",
	               title = "Wet Spell Distribution Across All Years")
	    
	    hist!(ax3, wet_spells, bins=1:maximum(wet_spells)+1,
	          color=(:steelblue, 0.7), strokecolor=:black, strokewidth=1)
	    
	    text!(ax3, 0.97, 0.97, 
	          text="Mean: $(round(mean(wet_spells), digits=1)) days\n" *
	               "Max: $(maximum(wet_spells)) days",
	          space=:relative, fontsize=12, align=(:right, :top))
	    
	    ax4 = Axis(fig[3, 2],
	               xlabel = "Spell length (days)",
	               title = "Dry Spell Distribution Across All Years",
				   yticklabelsvisible=false, ylabelvisible=false)
			
	    hist!(ax4, dry_spells, bins=1:maximum(dry_spells)+1,
	          color=(:orange, 0.7), strokecolor=:black, strokewidth=1)
	    
	    text!(ax4, 0.97, 0.97,
	          text="Mean: $(round(mean(dry_spells), digits=1)) days\n" *
	               "Max: $(maximum(dry_spells)) days",
	          space=:relative, fontsize=12, align=(:right, :top))
		
		linkyaxes!(ax3, ax4)
		
		fig
	end

	fig_dist_rain = plot_rain_distribution(df; width=width)
end  |> WideCell(; max_width=width)	

# ╔═╡ f3aa9f71-4929-436b-938e-9d6817c23487
begin
	function plot_rain_persistence(df; width=700)
	    if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
		fig = Figure(size=(width, 450))
		title = "Rainfall Persistence Patterns\n(Probability that tomorrow's " *
				"rain follows today's pattern)"
		Label(fig[0,:], title, tellwidth=false)
		
		all_samples = df[!, :rain]
		bins = [0, 0.1, 10, 30, 60, Inf]
		labels = ["Dry", "Light\n(<10 mm)", "Moderate\n(10-30 mm)", 
				  "Heavy\n(30-60 mm)", "Very Heavy\n(>60 mm)"]
		
		n = length(bins) - 1
		transition_matrix = zeros(n, n)
		
		for i in 2:length(all_samples)
			from_bin = clamp(searchsortedlast(bins, all_samples[i-1]), 1, n)
			to_bin = clamp(searchsortedlast(bins, all_samples[i]), 1, n)
			transition_matrix[from_bin, to_bin] += 1
		end
		
		row_sums = sum(transition_matrix, dims=2)
		transition_probs = transition_matrix ./ row_sums
		transition_probs[isnan.(transition_probs)] .= 0
		
		ax = Axis(fig[1, 1],
				  xlabel="Tomorrow's State",
				  ylabel="Today's State",
				  xticks=(1:n, labels),
				  yticks=(1:n, labels),
				  xticklabelrotation=π/6)
		
		hm = heatmap!(ax, transpose(transition_probs), 
					  colormap=cgrad(:Blues, 5, categorical = true),
					  colorrange=(0,1))
		
		for i ∈ 1:n, j ∈ 1:n
			pct = transition_probs[i, j] * 100
			if pct > 0.5  # Only show if probability > 0.5%
				text_color = pct > 40 ? :white : :black
				text!(ax, j, i, 
					  text="$(round(pct, digits=1))%",
					  align=(:center, :center), 
					  fontsize=14, color=text_color, font=:bold)
			end
		end
		
		Colorbar(fig[1, 2], hm, ticks = 0:0.2:1, label="Transition Probability")

		fig
	end
	
	fig_persist_rain = plot_rain_persistence(df; width=width)
end	|> WideCell(; max_width=width)	

# ╔═╡ 780eb61b-8d27-46a8-ac0a-11565c408474
begin
	function plot_seasonal_concentration(df; width=700)
	    if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
		monthly_totals = zeros(12)
	    for month ∈ 1:12
	        monthly_totals[month] = sum(df[df.month .== month, :rain])
	    end
		
		monthly_pct = (monthly_totals ./ sum(monthly_totals)) .* 100
		
		fig = Figure(size=(width, 500))
		ax = Axis(fig[1, 1],
				  title = "Seasonal Distribution of Rainfall by Month",
				  xlabel="Month",
				  ylabel="Contribution to annual rainfall (%)",
				  xticks=1:12)

		barplot!(ax, 1:12, monthly_pct,
				 color=(:skyblue, 0.7), strokecolor=:black, strokewidth=1)
		
		# Add reference line (uniform = 8.33%)
		hl = hlines!(ax, 100/12, color=:red, linestyle=:dash, linewidth=2)

		Legend(fig[2,1], [hl], ["Uniform 8.33%"], tellwidth=false,
			   tellheight=false, framevisible=false)
		rowsize!(fig.layout, 2, 0)
	    
	    fig
	end

	fig_seasonal_rain = plot_seasonal_concentration(df; width=width)
end |> WideCell(; max_width=width)

# ╔═╡ 7b3d5e74-0289-4285-92ce-2d422589b0d2
begin
	function plot_rainfall_regularity(df; width=700)
	    if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
		years = unique(df.year)
    
	    if length(years) < 2
	        return show_empty_chart("Need ≥2 years of data to plot.", width)
	    end
	    
	    monthly_data = [Float64[] for _ in 1:12]
	    for yr ∈ years
	        for mth ∈ 1:12
	            monthly_sum = sum(df[(df.year .== yr) .& (df.month .== mth), :rain])
	            push!(monthly_data[mth], monthly_sum)
	        end
	    end	    
	    
	    # Calculate percentiles
	    medians = [median(data) for data ∈ monthly_data]
	    p25 = [quantile(data, 0.25) for data ∈ monthly_data]
	    p75 = [quantile(data, 0.75) for data ∈ monthly_data]
	    p10 = [quantile(data, 0.10) for data ∈ monthly_data]
	    p90 = [quantile(data, 0.90) for data ∈ monthly_data]
	    
	    # Calculate IQR-based variability metric
	    iqr_ratio = [(p75[i] - p25[i]) / max(medians[i], 1.0) * 100 
	                 for i ∈ 1:12]
	    
	    # Identify outliers using IQR method on iqr_ratio itself
	    q25_ratio = quantile(iqr_ratio, 0.25)
	    q75_ratio = quantile(iqr_ratio, 0.75)
	    iqr_of_ratios = q75_ratio - q25_ratio
	    outlier_threshold = q75_ratio + 1.5 * iqr_of_ratios
	    
	    # Separate outliers from non-outliers
	    outlier_mask = iqr_ratio .> outlier_threshold
	    non_outlier_values = iqr_ratio[.!outlier_mask]
	    
	    # If all values are outliers or no outliers, use full range
	    if isempty(non_outlier_values)
	        max_ratio = maximum(iqr_ratio)
	        min_ratio = minimum(iqr_ratio)
	        outlier_mask .= false  # Treat all as non-outliers
	        y_max = max_ratio * 1.1
	    else
	        max_ratio = maximum(non_outlier_values)
	        min_ratio = minimum(non_outlier_values)
	        y_max = max_ratio * 1.1  # Add 10% headroom
	    end
	    
	    # Create categorical color scheme with N classes for non-outliers
	    n_classes = 10
	    bin_edges = range(min_ratio, max_ratio, length=n_classes + 1)
	    
	    # Get discrete colors from RdYlGn colormap
	    base_colormap = cgrad(:RdYlGn, n_classes, categorical=true, rev=true)
	    outlier_color = :purple
	    
	    # Assign colors based on outlier status and bin
	    colors = map(1:12) do i
	        if outlier_mask[i]
	            outlier_color
	        else
	            ratio = iqr_ratio[i]
	            bin_idx = searchsortedfirst(bin_edges[2:end], ratio)
	            bin_idx = clamp(bin_idx, 1, n_classes)
	            base_colormap[bin_idx]
	        end
	    end
	    
	    # Clip outlier bar heights to y_max for plotting
	    iqr_ratio_clipped = copy(iqr_ratio)
	    for i in 1:12
	        if outlier_mask[i]
	            iqr_ratio_clipped[i] = y_max
	        end
	    end
	    
	    fig = Figure(size=(width, 800))
	    
	    # Top: Median with percentile ranges
	    ax1 = Axis(fig[1, 1],
	               xlabel = "Month",
	               ylabel = "Monthly rainfall (mm)",
	               title = "Median Monthly Rainfall",
	               xticks = 1:12)
	    
	    # Outer range (10th-90th percentile) - lighter
	    band!(ax1, 1:12, p10, p90, color=(:gray, 0.2))
	    
	    # Inner range (25th-75th percentile / IQR) - darker
	    band!(ax1, 1:12, p25, p75, color=(:gray, 0.5))
	    
	    # Median line and points
	    lines!(ax1, 1:12, medians, color=:black, linewidth=2)
	    scatter!(ax1, 1:12, medians, color=colors, markersize=15,
	             strokecolor=:black, strokewidth=2)
	    
	    # Legend for percentile bands
	    elem_light = [PolyElement(color=(:gray, 0.2), 
	                              strokecolor=:black, strokewidth=1)]
	    elem_dark = [PolyElement(color=(:gray, 0.5), 
	                             strokecolor=:black, strokewidth=1)]
	    Legend(fig[2, 1], [elem_light, elem_dark], 
	           ["10th-90th percentile", "25th-75th percentile (IQR)"],
	           ["Shaded regions:"], tellwidth=false, orientation=:horizontal,
	           titlefont=:regular, titleposition=:left, framevisible=false)
	    
	    # Bottom: IQR ratio with categorical colors
	    ax2 = Axis(fig[3, 1],
	               xlabel = "Month",
	               ylabel = "IQR/Median ratio (%)",
	               title = "Rainfall Variability (lower = more predictable)",
	               xticks = 1:12,
	               limits=(nothing, nothing, 0, y_max))
	    
	    barplot!(ax2, 1:12, iqr_ratio_clipped, color=colors, 
	             strokecolor=:black, strokewidth=1)
	    
	    # Add text labels showing actual values for outliers
	    for i in 1:12
	        if outlier_mask[i]
	            text!(ax2, i, y_max * 0.95,
	                  text=string(round(iqr_ratio[i], digits=1)),
	                  align=(:center, :top),
	                  fontsize=10,
	                  color=:white,
	                  font=:bold)
	        end
	    end
	    
	    # Create tick labels at bin edges (boundaries between color groups)
	    tick_labels = [string(round(edge, digits=1)) for edge ∈ bin_edges]
	    
	    # Add categorical colorbar with boundary labels (97% width)
	    Colorbar(fig[4, 1], 
	             limits=(min_ratio, max_ratio),
	             colormap=base_colormap,
	             label="IQR/Median ratio (%)",
	             ticks=(collect(bin_edges), tick_labels),
	             vertical=false,
	             width=Relative(0.97),
	             flipaxis=false)
	    
	    # Add outlier indicator if any exist
	    if any(outlier_mask)
	        outlier_elem = [PolyElement(color=outlier_color, 
										strokecolor=:black, strokewidth=1)]
	        Legend(fig[5, 1], outlier_elem, 
	               ["Outlier (>$(round(outlier_threshold, digits=1))%) " *
					   "- truncated with actual value shown"],
	               tellwidth=false, orientation=:horizontal,
	               framevisible=false)
	        rowsize!(fig.layout, 5, Auto())
	    end
	    
	    fig
	end	
	
	fig_regularity_rain = plot_rainfall_regularity(df; width=width)
end  |> WideCell(; max_width=width)

# ╔═╡ 0a606de0-f28d-4136-90e8-89168b62a561
begin
	function plot_dry_spell(df; width=700)
	    if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
		years = unique(df.year)
	    nyears = length(years)
	    max_dry_spells = Int[]
	    dry_spell_timing = Int[]  # Day of year when longest dry spell occurred
	    
	    for year ∈ years
	        samples = df[df.year .== year, :rain]
	        
	        # Find all dry spells
	        current_spell = 0
	        max_spell = 0
	        max_spell_start = 0
	        
	        for (day, rain) ∈ enumerate(samples)
	            if rain < 0.1  # Less than 0.1 mm = too dry
	                current_spell += 1
	                if current_spell > max_spell
	                    max_spell = current_spell
	                    max_spell_start = day - current_spell + 1
	                end
	            else
	                current_spell = 0
	            end
	        end
	        
	        push!(max_dry_spells, max_spell)
	        push!(dry_spell_timing, max_spell_start)
	    end
		
	    fig = Figure(size=(width, 700))
	    
	    # Top: Maximum dry spell length by year
	    ax1 = Axis(fig[1, 1],
	               xlabel = "Year",
	               ylabel = "Maximum consecutive dry days",
	               title = "Longest Dry Spell Each Year",
	               xticks = (1:nyears, string.(years)))
	    
	    barplot!(ax1, 1:nyears, max_dry_spells,
	             color=(:coral, 0.35), strokecolor=:black, strokewidth=1)
	    
	    # Critical threshold (e.g., 14 days)
	    hl = hlines!(ax1, 14, color=:red, linestyle=:dash, linewidth=2)
	    
	    Legend(fig[2,1], [hl], ["14-day critical threshold"],
			   orientation=:horizontal,
			   framevisible=false, tellwidth=false, halign=:right)
	    
	    # Bottom: When do dry spells occur?
	    ax2 = Axis(fig[3, 1],
	               xlabel = "Year",
	               ylabel = "Day of year / Month",
	               title = "When Does Maximum Dry Spell Occur?",
	               xticks = (1:nyears, string.(years)))
	    
	    stem!(ax2, 1:nyears, dry_spell_timing,
	          color=:red, markersize=12, strokecolor=:black, strokewidth=1)

		# Month markers
		DAYS_IN_MONTHS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	    month_days = cumsum([0; DAYS_IN_MONTHS]) .+ 1
	    lbls = ["$(md) / $(i)" for (i, md) ∈ enumerate(month_days)]
		ax2.yticks = (month_days, lbls)
		ylims!(ax2, 1, 365)

		rowsize!(fig.layout, 2, 0)
	    
	    fig
	end
	
	fig_dryspells = plot_dry_spell(df; width=width)
end |> WideCell(; max_width=width)

# ╔═╡ b5091909-f90e-46bf-ba43-ac9d3bbd8ea0
begin
	function plot_rain_hovmoller(df; window=30, width=700)
	    if isempty(df)
			return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
		# Extract year information
	    years = sort(unique(df.year))
	    nyears = length(years)
	    firstyear = minimum(years)
	    lastyear = maximum(years)
	    
	    # === Prepare DOY data with running sum ===
	    max_days = maximum([nrow(df[df.year .== yr, :]) for yr ∈ years])
	    hovmoller_doy = fill(NaN, nyears, max_days)
	    
	    # Running sum window size (total accumulation over window)
	    half_window = window ÷ 2
	    
	    for (yn, year) ∈ enumerate(years)
	        year_rain = df[df.year .== year, :rain]
	        n_days = length(year_rain)
	        
	        for doy ∈ 1:n_days
	            # Calculate running sum centered on this day
	            start_idx = max(1, doy - half_window)
	            end_idx = min(n_days, doy + half_window)
	            hovmoller_doy[yn, doy] = sum(year_rain[start_idx:end_idx])
	        end
	    end
	    
	    # === Prepare Monthly data (monthly totals) ===
	    hovmoller_monthly = fill(NaN, nyears, 12)
	    
	    for (yn, year) ∈ enumerate(years)
	        for month ∈ 1:12
	            month_rain = df[(df.year .== year) .& (df.month .== month), :rain]
	            if !isempty(month_rain)
	                hovmoller_monthly[yn, month] = sum(month_rain)
	            end
	        end
	    end
	    
	    # === Calculate color ranges ===
	    # For running sum
	    doy_min = minimum(filter(!isnan, hovmoller_doy))
	    doy_max = maximum(filter(!isnan, hovmoller_doy))
	    
	    # For monthly totals
	    monthly_min = minimum(filter(!isnan, hovmoller_monthly))
	    monthly_max = maximum(filter(!isnan, hovmoller_monthly))
	    
	    # === Create figure ===
	    year_range = firstyear:lastyear
	    panel_height = max(250, nyears * 80)
	    fig_height = panel_height + 50
	    fig = Figure(size=(width, fig_height))
	    
	    # X-axis labels: first day of each month + end of year
	    month_starts = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 365]
	    month_labels = [string(v) for v in month_starts]
	    
	    # === Running Sum Panel ===
	    ax_doy = Axis(
	        fig[1, 1],
	        xlabel="Day of Year",
	        ylabel="Year",
	        title="$(window)-Day Running Sum ($nyears years: " *
	              "$(first(year_range))-$(last(year_range)))",
	        xticks=(month_starts, month_labels),
	        yticks=(1:nyears, string.(year_range))
	    )
	    
	    n_colors = 10
	    colors = [get(ColorSchemes.YlGnBu, x) 
	              for x ∈ range(0, 0.8, length=n_colors)]
	    cmap = cgrad(colors, n_colors, categorical=true)
	    
	    hm_doy = heatmap!(ax_doy, 1:max_days, 1:nyears, hovmoller_doy',
	                      colormap=cmap, colorrange=(doy_min, doy_max),
	                      interpolate=false)
	    
	    # Grid lines
	    for i ∈ 0:nyears
	        hlines!(ax_doy, [i + 0.5], color=:black, linewidth=0.5, alpha=0.3)
	    end
	    
	    for day ∈ month_starts
	        vlines!(ax_doy, [day + 0.5], color=:black, linewidth=0.5, alpha=0.2)
	    end
	    
	    bin_width = (doy_max - doy_min) / n_colors
	    tick_positions = [doy_min + bin_width * i for i in 0:n_colors]
	    tick_labels = [string(round(pos, digits=1)) for pos in tick_positions]
	    
	    Colorbar(fig[2, 1], hm_doy, label="$(window)-day accumulated rainfall (mm)", 
	             vertical=false, flipaxis=false,
	             ticks=(tick_positions, tick_labels), width=Relative(0.95))
	    
	    fig
	end
	
	fig_hov_rain = plot_rain_hovmoller(df; window=window_rain, width=width)
end |> WideCell(; max_width=width)

# ╔═╡ f697d192-d434-4203-b1b8-043e61ab60a5
begin
	function plot_tmax_wind_rain(df; width=700)
	    if isempty(df)
	        return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
	    # Calculate monthly statistics
	    monthly_stats = DataFrame()
	    
	    for year ∈ unique(df.year)
	        for month ∈ 1:12
	            mask = (df.year .== year) .& (df.month .== month)
	            month_data = df[mask, :]
	            
	            if !isempty(month_data)
	                push!(monthly_stats, (
	                    year = year,
	                    month = month,
	                    avg_tmax = mean(month_data.tmax),
	                    avg_wind = mean(month_data.wind),
	                    total_rain = sum(month_data.rain)
	                ))
	            end
	        end
	    end
	    
	    if isempty(monthly_stats)
	        return show_empty_chart("Insufficient data for analysis.", width)
	    end
	    
	    # Create figure
	    fig = Figure(size=(width, 1400))
	    
	    # Panel 1: Tmax vs Rainfall
	    ax1 = Axis(fig[1, 1],
	               xlabel="Monthly total rainfall (mm)",
	               ylabel="Average monthly Tmax (°C)",
	               title="Max. Temp. (Tmax) vs Rainfall")
	    
	    scatter!(ax1, monthly_stats.total_rain, monthly_stats.avg_tmax,
	             color=:skyblue, markersize=8,
	             strokecolor=:black, strokewidth=1)
	    
	    # Add trend line
	    if length(monthly_stats.total_rain) > 2
	        X = hcat(ones(length(monthly_stats.total_rain)), 
	                 monthly_stats.total_rain)
	        β = X \ monthly_stats.avg_tmax
	        x_trend = range(minimum(monthly_stats.total_rain), 
	                       maximum(monthly_stats.total_rain), length=100)
	        y_trend = β[1] .+ β[2] .* x_trend
	        lines!(ax1, x_trend, y_trend, color=:black, linestyle=:solid, 
	               linewidth=2)
	        
	        # Calculate correlation
	        r = cor(monthly_stats.total_rain, monthly_stats.avg_tmax)
	        text!(ax1, 0.99, 0.99, 
	              text=L"r = %$(round(r, digits=3))",
	              space=:relative, fontsize=12, align=(:right, :top))
	    end
	    
	    # Panel 2: Tmax vs Wind
	    ax2 = Axis(fig[2, 1],
	               xlabel="Average monthly wind speed (m s⁻¹)",
	               ylabel="Average monthly Tmax (°C)",
	               title="Max. Temp. vs Wind Speed")
	    
	    scatter!(ax2, monthly_stats.avg_wind, monthly_stats.avg_tmax,
	             color=:lightcoral, markersize=8,
	             strokecolor=:black, strokewidth=1)
	    
	    # Add trend line
	    if length(monthly_stats.avg_wind) > 2
	        X = hcat(ones(length(monthly_stats.avg_wind)), 
	                 monthly_stats.avg_wind)
	        β = X \ monthly_stats.avg_tmax
	        x_trend = range(minimum(monthly_stats.avg_wind), 
	                       maximum(monthly_stats.avg_wind), length=100)
	        y_trend = β[1] .+ β[2] .* x_trend
	        lines!(ax2, x_trend, y_trend, color=:black, linestyle=:solid, 
	               linewidth=2)
	        
	        # Calculate correlation
	        r = cor(monthly_stats.avg_wind, monthly_stats.avg_tmax)
	        text!(ax2, 0.99, 0.99, 
	              text=L"r = %$(round(r, digits=3))",
	              space=:relative, fontsize=12, align=(:right, :top))
	    end
	    
	    # Panel 3: Wind vs Rainfall
	    ax3 = Axis(fig[3, 1],
	               xlabel="Monthly total rainfall (mm)",
	               ylabel="Average monthly wind speed (m s⁻¹)",
	               title="Wind Speed vs Rainfall")
	    
	    scatter!(ax3, monthly_stats.total_rain, monthly_stats.avg_wind,
	             color=:lightgreen, markersize=8,
	             strokecolor=:black, strokewidth=1)
	    
	    # Add trend line
	    if length(monthly_stats.total_rain) > 2
	        X = hcat(ones(length(monthly_stats.total_rain)), 
	                 monthly_stats.total_rain)
	        β = X \ monthly_stats.avg_wind
	        x_trend = range(minimum(monthly_stats.total_rain), 
	                       maximum(monthly_stats.total_rain), length=100)
	        y_trend = β[1] .+ β[2] .* x_trend
	        lines!(ax3, x_trend, y_trend, color=:black, linestyle=:solid, 
	               linewidth=2)
	        
	        # Calculate correlation
	        r = cor(monthly_stats.total_rain, monthly_stats.avg_wind)
	        text!(ax3, 0.99, 0.99, 
	              text=L"r = %$(round(r, digits=3))",
	              space=:relative, fontsize=12, align=(:right, :top))
	    end
	    
	    # Panel 4: Seasonal patterns
	    ax4 = Axis(fig[4, 1],
	               xlabel="Month",
	               ylabel="Normalized value",
	               title="Seasonal Patterns",
	               xticks=(1:12, ["J","F","M","A","M","J","J","A","S","O","N","D"]))
	    
	    # Aggregate by month across all years
	    monthly_avg = combine(groupby(monthly_stats, :month),
	                         :avg_tmax => mean => :tmax,
	                         :avg_wind => mean => :wind,
	                         :total_rain => mean => :rain)
	    sort!(monthly_avg, :month)
	    
	    # Normalize for comparison
	    tmax_norm = (monthly_avg.tmax .- minimum(monthly_avg.tmax)) ./ 
	                (maximum(monthly_avg.tmax) - minimum(monthly_avg.tmax))
	    wind_norm = (monthly_avg.wind .- minimum(monthly_avg.wind)) ./ 
	                (maximum(monthly_avg.wind) - minimum(monthly_avg.wind))
	    rain_norm = (monthly_avg.rain .- minimum(monthly_avg.rain)) ./ 
	                (maximum(monthly_avg.rain) - minimum(monthly_avg.rain))
	    
	    l1 = lines!(ax4, 1:12, tmax_norm, color=:red, linewidth=2)
	    l2 = lines!(ax4, 1:12, wind_norm, color=:blue, linewidth=2)
	    l3 = lines!(ax4, 1:12, rain_norm, color=:green, linewidth=2)
	    
	    Legend(fig[5, 1], [l1, l2, l3],
	           ["Tmax", "Wind", "Rainfall"],
	           "Normalized (0-1):", titleposition=:left, 
	           tellwidth=false, framevisible=false, orientation=:horizontal)
	    
	    rowsize!(fig.layout, 5, 0)
	    
	    fig
	end
	
		
	fig_twf = plot_tmax_wind_rain(df; width=width)
end |> WideCell(; max_width=width)

# ╔═╡ 824d7572-067e-4d7e-a958-5c9e3b942e2a
begin
	function plot_rain_anomaly(df; window=60, width=700)
	    if isempty(df)
	        return show_empty_chart("No results yet; no chart to plot.", width)
	    end
	    
	    # Sort by year and doy to ensure proper order
	    df_sorted = sort(df, [:year, :doy])
	    
	    # Calculate window-day rolling sum of rainfall
	    n = nrow(df_sorted)
	    rolling_rain = zeros(n)
	    
	    for i ∈ 1:n
	        start_idx = max(1, i - window + 1)
	        rolling_rain[i] = sum(df_sorted.rain[start_idx:i])
	    end
	    
	    # Calculate mean window-day rainfall as reference
	    mean_window_rain = mean(rolling_rain[window:end])  
		
	    # Calculate deficit (positive = drier than normal, negative = wetter)
	    deficit = mean_window_rain .- rolling_rain
	    
	    # Get corresponding Tmax values
	    tmax_values = df_sorted.tmax
	    
	    # Remove initial ramp-up period where rolling sum isn't complete
	    valid_idx = window:n
	    deficit_valid = deficit[valid_idx]
	    tmax_valid = tmax_values[valid_idx]
	    
	    # Create figure
	    fig = Figure(size=(width, 900))
	    
	    # Panel 1: Scatter plot of Tmax vs Deficit
	    ax1 = Axis(fig[1, 1],
	               xlabel="$(window)-day cumulative rainfall anomaly (mm)",
	               ylabel="Daily Tmax (°C)",
	               title="Max. Temp. (Tmax) vs Rainfall Anomaly\n" *
	                     "(Positive = drier than average)")
	    
	    scatter!(ax1, deficit_valid, tmax_valid,
	             color=:coral, markersize=4, alpha=0.5,
	             strokecolor=:black, strokewidth=0.3)
	    
	    # Add trend line
	    if length(deficit_valid) > 2
	        X = hcat(ones(length(deficit_valid)), deficit_valid)
	        β = X \ tmax_valid
	        x_trend = range(minimum(deficit_valid), 
	                       maximum(deficit_valid), length=100)
	        y_trend = β[1] .+ β[2] .* x_trend
	        lines!(ax1, x_trend, y_trend, color=:black, linestyle=:solid, 
	               linewidth=2)
	        
	        # Calculate correlation
	        r = cor(deficit_valid, tmax_valid)
	        text!(ax1, 0.01, 0.99, 
	              text=L"r = %$(round(r, digits=3))",
	              space=:relative, fontsize=12, align=(:left, :top))
	    end
	    
	    # Add vertical line at zero deficit (average conditions)
	    vlines!(ax1, [0], color=:red, linestyle=:dash, linewidth=1.5)
	    
		# Panel 2: Time series of deficit
		ax2 = Axis(fig[2, 1],
		           xlabel="Days",
		           ylabel="$(window)-day rainfall anomaly (mm)",
		           title="Rainfall Anomaly Over Time")
		
		lines!(ax2, valid_idx, deficit_valid, color=:blue, linewidth=1.5)
		hlines!(ax2, [0], color=:red, linestyle=:dash, linewidth=1.5,
		        label="Average (zero anomaly)")
		
		# Create color array based on deficit sign
		deficit_colors = [d > 0 ? :coral : :skyblue for d in deficit_valid]
		
		band!(ax2, valid_idx, zeros(length(valid_idx)), deficit_valid,
		      color=deficit_colors, alpha=0.35)
		
	    # Panel 3: Distribution of deficit values
	    ax3 = Axis(fig[3, 1],
	               xlabel="$(window)-day rainfall anomaly (mm)",
	               ylabel="Frequency",
	               title="Distribution of Anomaly Values")
	    
	    hist!(ax3, deficit_valid, bins=40, normalization=:pdf,
	          color=(:steelblue, 0.6), strokecolor=:black, strokewidth=1)
	    
	    vlines!(ax3, [0], color=:red, linestyle=:dash, linewidth=1.5)
	    vlines!(ax3, [mean(deficit_valid)], color=:red, linestyle=:dash, 
	            linewidth=1.5, label="Mean")
	    
	    # Add statistics text
	    deficit_std = std(deficit_valid)
	    text!(ax3, 0.01, 0.99,
	          text="SD=$(round(deficit_std, digits=1)) mm",
	          space=:relative, fontsize=11, align=(:left, :top))

	    fig
	end
	
	fig_rain_anomaly = plot_rain_anomaly(df; window=window_rain_decifit, width=width)
end |> WideCell(; max_width=width)

# ╔═╡ bd8f5ed4-7a66-4256-a4ea-690280cca8a0
begin
	function awc_input(c, s, depth_in_meters=1)
		total = c + s
		if total <= 100.0
			awc = est_awc(c, s)
		else
			awc = 0.1462   # AWC for default 30% clay and 30% sand
			@warn "Clay + Sand cannot exceed 100%. AWC set to 146.2 mm."
		end
		awc * depth_in_meters * 1000   # convert to mm
	end

	kc_val = crop_db[croptype].kc
	if !isnothing(tryparse(Float64, init.kc))
		v = parse(Float64, init.kc)
		if v <= 0
			@warn "Crop coefficient must be >0. Using default value $(kc_val)"
		else
			kc_val = v
		end
	else
		@warn "Invalid crop coefficient value. Using default value $(kc_val)"
	end
			
	dg_val = crop_db[croptype].dg               
	if !isnothing(tryparse(Float64, init.dg))
		v = parse(Float64, init.dg)
		if v <= 0
			@warn "Root depth must be >0. Using default value $(dg_val)"
		else
			dg_val = v
		end
	else
		@warn "Invalid root depth value. Using default value $(dg_val)"
	end
	
	stress_val = crop_db[croptype].stress
	if !isnothing(tryparse(Float64, init.stress))
		v = parse(Float64, init.stress)
		if v < 0 || v > 1
			@warn "Stress threshold be between 0 and 1. Using default value " *
				  "$(stress_val)"
		else
			stress_val = v
		end
	else
		@warn "Invalid stress threshold. Using default value $(stress_val)"
	end

	df.etc = df.et0 * kc_val	# update actual crop ET (ETc)
	awc = round(awc_input(clay, sand, dg_val); digits=1)
	nothing
end

# ╔═╡ ffc702bf-2b17-4168-a423-826ab0821d47
begin
	function plot_waterstorage(df, awc, stress_threshold; width=700)
	    if isempty(df)
	        return show_empty_chart("No results yet; no charts to plot.", width)
	    end
	    
	    df_sorted = sort(df, [:year, :doy])
	    years = sort(unique(df.year))
	    max_doy = 366
	    nyears = length(years)
	    firstyear = minimum(years)
	    lastyear = maximum(years)
	    
	    # Create matrix: rows = years, cols = days
	    water_matrix = fill(NaN, nyears, max_doy)
	    
	    # Calculate soil water for entire time series (continuous)
	    n_total = nrow(df_sorted)
	    soil_water_all = zeros(n_total)
	    
	    # Start first day at 50% AWC
	    soil_water_all[1] = awc / 2.0
	    
	    for i ∈ 2:n_total
	        # Daily water balance
	        daily_balance = df_sorted.rain[i] - df_sorted.etc[i]
	        
	        # Update soil water storage
	        soil_water_all[i] = soil_water_all[i-1] + daily_balance
	        
	        # Apply constraints
	        if soil_water_all[i] > awc
	            soil_water_all[i] = awc  # Excess drains away
	        elseif soil_water_all[i] < 0.0
	            soil_water_all[i] = 0.0  # Can't go below zero
	        end
	    end
	    
	    # Fill matrix from continuous calculation
	    for i ∈ 1:n_total
	        year = df_sorted.year[i]
	        doy = df_sorted.doy[i]
	        year_idx = findfirst(==(year), years)
	        
	        if !isnothing(year_idx) && doy <= max_doy
	            water_matrix[year_idx, doy] = soil_water_all[i]
	        end
	    end
	    
	    year_range = firstyear:lastyear
	    panel_height = max(250, nyears * 80)
	    fig_height = panel_height + 50  # Extra space for legend
	    fig = Figure(size=(width, fig_height))
	    
	    # Panel 1: Heatmap
		stress_level = stress_threshold * awc
	    month_starts = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 365]
	    month_labels = [string(v) for v ∈ month_starts]
	    ax1 = Axis(fig[1, 1],
	              xlabel="Day of Year",
	              ylabel="Year",
	              title="Soil Water Storage (AWC = $(awc) mm, " *
					    "Critical point = $(round(stress_level; digits=1)) mm)",
	              xticks=(month_starts, month_labels),
	              yticks=(1:nyears, string.(year_range)))
	    
		# Calculate zones
		stress_level = stress_threshold * awc
		n_total = 10
		n_stress = clamp(round(Int, n_total * stress_threshold), 1, n_total - 1)
		n_safe = n_total - n_stress
		
		# Helper function for safe color generation
		function get_colors_safe(scheme, n, intensity_range=(0.25, 0.85))
		    if n == 1
		        # Single color: use middle-high intensity
		        return [get(scheme, 0.6)]
		    else
		        # Multiple colors: use full range
		        return [get(scheme, x) for x in range(intensity_range[2], intensity_range[1], length=n)]
		    end
		end
		
		# Generate colors
		stress_colors = get_colors_safe(ColorSchemes.Reds_9, n_stress, (0.25, 0.85))
		safe_colors = get_colors_safe(ColorSchemes.Blues_9, n_safe, (0.25, 0.85))
		all_colors = vcat(stress_colors, safe_colors)
		
		stress_pos = collect(range(0.0, stress_threshold, length=n_stress + 1))
		safe_pos = collect(range(stress_threshold, 1.0, length=n_safe + 1))[2:end]
		color_pos = vcat(stress_pos, safe_pos)
		cmap = cgrad(all_colors, color_pos)
		
		hm = heatmap!(ax1, 1:max_doy, 1:nyears, water_matrix',
		              colormap=cmap,
		              colorrange=(0, awc))
		
		stress_ticks_mm = collect(range(0, stress_level, length=n_stress + 1))
		safe_ticks_mm = collect(range(stress_level, awc, length=n_safe + 1))[2:end]
		tick_positions = vcat(stress_ticks_mm, safe_ticks_mm)
		tick_labels = string.(Int.(round.(tick_positions)))
		
		Colorbar(fig[2, 1], hm, 
		         label="Soil Water Storage (mm)",
		         vertical=false, 
		         flipaxis=false,
		         ticks=(tick_positions, tick_labels),
		         width=Relative(0.95),
		         ticklabelsize=10)
		
	    fig
	end	

	fig_waterstorage = plot_waterstorage(df, awc, stress_val; width=width)
end |> WideCell(; max_width=width)

# ╔═╡ 8968e9d2-5e33-457d-8931-18432977d1c3
begin
	savefigs

	function save_all()
		if (savefigs==0) || isempty(csv_path) || locksave
			return
		end
		
		fnames = [
			"tmin_dist.png", "tmin_acf.png", "tmin_hov.png",
			"tmax_dist.png", "tmax_acf.png", "tmax_hov.png",
			"wind_dist.png", "wind_acf.png", "wind_hov.png",
			"rain_dist.png", "rain_persistance.png", "rain_seasonal.png",
			"rain_regularity.png", "rain_dryspells.png", "rain_hov.png",
			"rain_temp_wind.png", "rain_anomaly.png", "rain_waterstorage.png"
		]
		
		figs = [
			fig_dist_tmin, fig_acf_tmin, fig_hov_tmin,
			fig_dist_tmax, fig_acf_tmax, fig_hov_tmax,
			fig_dist_wind, fig_acf_wind, fig_hov_wind,
			fig_dist_rain, fig_persist_rain, fig_seasonal_rain, 
			fig_regularity_rain, fig_dryspells, fig_hov_rain,
			fig_twf, fig_rain_anomaly, fig_waterstorage
		]

		prefix = inputs.usetype == "generate" ? "gen_" : "obs_"
		fnames = prefix .* fnames
		site_path = dirname(csv_path)
		fnames = joinpath.(Ref(site_path), fnames)

		foreach(z->save(z[1], z[2]), zip(fnames, figs))
	
		msg = "Saved figures to: $(site_path)"
		quick_msg(msg)
	end

	save_all()
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
ColorSchemes = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
KernelDensity = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
LsqFit = "2fda8390-95c7-5789-9bda-21331edee243"
OrderedCollections = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
Parameters = "d96e819e-fc66-5662-9728-84c9c7592b0a"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

[compat]
CSV = "~0.10.15"
CairoMakie = "~0.15.6"
ColorSchemes = "~3.31.0"
DataFrames = "~1.8.1"
Distributions = "~0.25.122"
HypertextLiteral = "~0.9.5"
KernelDensity = "~0.6.10"
LaTeXStrings = "~1.4.0"
LsqFit = "~0.15.1"
OrderedCollections = "~1.8.1"
Parameters = "~0.12.3"
PlutoUI = "~0.7.73"
SpecialFunctions = "~2.6.1"
StatsBase = "~0.34.7"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.1"
manifest_format = "2.0"
project_hash = "24a3414ca0ccd51c9f643dc4c87f7d7be45681e0"

[[deps.ADTypes]]
git-tree-sha1 = "27cecae79e5cc9935255f90c53bb831cc3c870d7"
uuid = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
version = "1.18.0"

    [deps.ADTypes.extensions]
    ADTypesChainRulesCoreExt = "ChainRulesCore"
    ADTypesConstructionBaseExt = "ConstructionBase"
    ADTypesEnzymeCoreExt = "EnzymeCore"

    [deps.ADTypes.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "Test"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "7e35fca2bdfba44d797c53dfe63a51fabf39bfc0"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.4.0"
weakdeps = ["SparseArrays", "StaticArrays"]

    [deps.Adapt.extensions]
    AdaptSparseArraysExt = "SparseArrays"
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AdaptivePredicates]]
git-tree-sha1 = "7e651ea8d262d2d74ce75fdf47c4d63c07dba7a6"
uuid = "35492f91-a3bd-45ad-95db-fcad7dcfedb7"
version = "1.2.0"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e092fa223bf66a3c41f9c022bd074d916dc303e7"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "d81ae5489e13bc03567d4fbbb06c546a5e53c857"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.22.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = ["CUDSS", "CUDA"]
    ArrayInterfaceChainRulesCoreExt = "ChainRulesCore"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceMetalExt = "Metal"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    Metal = "dde4c033-4e86-420c-a63e-0dd931031962"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Automa]]
deps = ["PrecompileTools", "SIMD", "TranscodingStreams"]
git-tree-sha1 = "a8f503e8e1a5f583fbef15a8440c8c7e32185df2"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "1.1.0"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "4126b08903b777c88edf1754288144a0492c05ad"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.8"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BaseDirs]]
git-tree-sha1 = "bca794632b8a9bbe159d56bf9e31c422671b35e0"
uuid = "18cc8868-cbac-4acf-b575-c8ff214dc66f"
version = "1.3.2"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CRC32c]]
uuid = "8bf52ea8-c179-5cab-976a-9e18b702a9bc"
version = "1.11.0"

[[deps.CRlibm]]
deps = ["CRlibm_jll"]
git-tree-sha1 = "66188d9d103b92b6cd705214242e27f5737a1e5e"
uuid = "96374032-68de-5a5b-8d9e-752f78720389"
version = "1.0.2"

[[deps.CRlibm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e329286945d0cfc04456972ea732551869af1cfc"
uuid = "4e9b3aee-d8a1-5a3d-ad8b-7d824db253f0"
version = "1.0.1+0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "deddd8725e5e1cc49ee205a1964256043720a6c3"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.15"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "71aa551c5c33f1a4415867fe06b7844faadb0ae9"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.1.1"

[[deps.CairoMakie]]
deps = ["CRC32c", "Cairo", "Cairo_jll", "Colors", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "PrecompileTools"]
git-tree-sha1 = "f8caabc5a1c1fb88bcbf9bc4078e5656a477afd0"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.15.6"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "fde3bf89aead2e723284a8ff9cdf5b551ed700e8"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.5+0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "e4c6a16e77171a5f5e25e9646617ab1c276c5607"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.26.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON"]
git-tree-sha1 = "07da79661b919001e6863b81fc572497daa58349"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.2"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b0fd3f56fa442f81e0a47815c92245acfaaa4e34"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.31.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "8b3b6f87ce8f65a2b4f857528fd8d70086cd72b1"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "37ea44092930b1811e666c3bc38065d7d87fcc74"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.1"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

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

[[deps.ComputePipeline]]
deps = ["Observables", "Preferences"]
git-tree-sha1 = "cb1299fee09da21e65ec88c1ff3a259f8d0b5802"
uuid = "95dc2771-c249-4cd0-9c9f-1f3b4330693c"
version = "0.1.4"

[[deps.ConstructionBase]]
git-tree-sha1 = "b4b092499347b18a015186eae3042f72267106cb"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.6.0"
weakdeps = ["IntervalSets", "LinearAlgebra", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

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
git-tree-sha1 = "d8928e9169ff76c6281f39a659f9bca3a573f24c"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.8.1"

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

[[deps.DelaunayTriangulation]]
deps = ["AdaptivePredicates", "EnumX", "ExactPredicates", "Random"]
git-tree-sha1 = "5620ff4ee0084a6ab7097a27ba0c19290200b037"
uuid = "927a84f5-c5f4-47a5-9785-b46e178433df"
version = "1.6.4"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.DifferentiationInterface]]
deps = ["ADTypes", "LinearAlgebra"]
git-tree-sha1 = "529bebbc74b36a4cfea09dd2aecb1288cd713a6d"
uuid = "a0c0ee7d-e4b9-4e03-894e-1c5f64a51d63"
version = "0.7.9"

    [deps.DifferentiationInterface.extensions]
    DifferentiationInterfaceChainRulesCoreExt = "ChainRulesCore"
    DifferentiationInterfaceDiffractorExt = "Diffractor"
    DifferentiationInterfaceEnzymeExt = ["EnzymeCore", "Enzyme"]
    DifferentiationInterfaceFastDifferentiationExt = "FastDifferentiation"
    DifferentiationInterfaceFiniteDiffExt = "FiniteDiff"
    DifferentiationInterfaceFiniteDifferencesExt = "FiniteDifferences"
    DifferentiationInterfaceForwardDiffExt = ["ForwardDiff", "DiffResults"]
    DifferentiationInterfaceGPUArraysCoreExt = "GPUArraysCore"
    DifferentiationInterfaceGTPSAExt = "GTPSA"
    DifferentiationInterfaceMooncakeExt = "Mooncake"
    DifferentiationInterfacePolyesterForwardDiffExt = ["PolyesterForwardDiff", "ForwardDiff", "DiffResults"]
    DifferentiationInterfaceReverseDiffExt = ["ReverseDiff", "DiffResults"]
    DifferentiationInterfaceSparseArraysExt = "SparseArrays"
    DifferentiationInterfaceSparseConnectivityTracerExt = "SparseConnectivityTracer"
    DifferentiationInterfaceSparseMatrixColoringsExt = "SparseMatrixColorings"
    DifferentiationInterfaceStaticArraysExt = "StaticArrays"
    DifferentiationInterfaceSymbolicsExt = "Symbolics"
    DifferentiationInterfaceTrackerExt = "Tracker"
    DifferentiationInterfaceZygoteExt = ["Zygote", "ForwardDiff"]

    [deps.DifferentiationInterface.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DiffResults = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
    Diffractor = "9f5e2b26-1114-432f-b630-d3fe2085c51c"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"
    FastDifferentiation = "eb9bf01b-bf85-4b60-bf87-ee5de06c00be"
    FiniteDiff = "6a86dc24-6348-571c-b903-95158fe2bd41"
    FiniteDifferences = "26cc04aa-876d-5657-8c51-4c34ba976000"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    GTPSA = "b27dd330-f138-47c5-815b-40db9dd9b6e8"
    Mooncake = "da2b9cff-9c12-43a0-ae48-6db2b0edb7d6"
    PolyesterForwardDiff = "98d1487c-24ca-40b6-b7ab-df2af84e126b"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SparseConnectivityTracer = "9f842d2f-2579-4b1d-911e-f412cf18a3f5"
    SparseMatrixColorings = "0a514795-09f3-496d-8182-132a7b665d35"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    Symbolics = "0c5d862f-8b57-4792-8d23-62f2024744c7"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "3bc002af51045ca3b47d2e1787d6ce02e68b943a"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.122"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EnumX]]
git-tree-sha1 = "bddad79635af6aec424f53ed8aad5d7555dc6f00"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.5"

[[deps.ExactPredicates]]
deps = ["IntervalArithmetic", "Random", "StaticArrays"]
git-tree-sha1 = "83231673ea4d3d6008ac74dc5079e77ab2209d8f"
uuid = "429591f6-91af-11e9-00e2-59fbe8cec110"
version = "2.2.9"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "27af30de8b5445644e8ffe3bcb0d72049c089cf1"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.7.3+0"

[[deps.Extents]]
git-tree-sha1 = "b309b36a9e02fe7be71270dd8c0fd873625332b4"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.6"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "eaa040768ea663ca695d442be1bc97edfe6824f2"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "6.1.3+0"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "Libdl", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "97f08406df914023af55ade2f843c39e99c5d969"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.10.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6d6219a004b8cf1e0b4dbe27a2860b8e04eba0be"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.11+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "d60eb76f37d7e5a40cc2e7c36974d864b82dc802"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.17.1"

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

    [deps.FileIO.weakdeps]
    HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"

[[deps.FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport", "Requires"]
git-tree-sha1 = "919d9412dbf53a2e6fe74af62a73ceed0bce0629"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.8.3"

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

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "173e4d8f14230a7523ae11b9a3fa9edb3e0efd78"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.14.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Setfield"]
git-tree-sha1 = "9340ca07ca27093ff68418b7558ca37b05f8aeb1"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.29.0"

    [deps.FiniteDiff.extensions]
    FiniteDiffBandedMatricesExt = "BandedMatrices"
    FiniteDiffBlockBandedMatricesExt = "BlockBandedMatrices"
    FiniteDiffSparseArraysExt = "SparseArrays"
    FiniteDiffStaticArraysExt = "StaticArrays"

    [deps.FiniteDiff.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "f85dac9a96a01087df6e3a749840015a0ca3817d"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.17.1+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "ba6ce081425d0afb2bedd00d9884464f764a9225"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "1.2.2"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "907369da0f8e80728ab49c1c7e09327bf0d6d999"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.1.1"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "2c5512e11c791d1baed2049c5652441b28fc6a31"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.4+0"

[[deps.FreeTypeAbstraction]]
deps = ["BaseDirs", "ColorVectorSpace", "Colors", "FreeType", "GeometryBasics", "Mmap"]
git-tree-sha1 = "4ebb930ef4a43817991ba35db6317a05e59abd11"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.10.8"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7a214fdac5ed5f59a22c2d9a885a16da1c74bbc7"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.17+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "Extents", "IterTools", "LinearAlgebra", "PrecompileTools", "Random", "StaticArrays"]
git-tree-sha1 = "1f5a80f4ed9f5a4aada88fc2db456e637676414b"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.5.10"

    [deps.GeometryBasics.extensions]
    GeometryBasicsGeoInterfaceExt = "GeoInterface"

    [deps.GeometryBasics.weakdeps]
    GeoInterface = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"

[[deps.GettextRuntime_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll"]
git-tree-sha1 = "45288942190db7c5f760f59c04495064eedf9340"
uuid = "b0724c58-0f36-5564-988d-3bb0596ebc4a"
version = "0.22.4+0"

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "GettextRuntime_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "50c11ffab2a3d50192a228c313f05b5b5dc5acb2"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.86.0+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "a641238db938fff9b2f60d08ed9030387daf428c"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.3"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a6dbda1fd736d60cc477d99f2e7a042acfa46e8"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.15+0"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "93d5c27c8de51687a2c70ec0716e6e76f298416f"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.11.2"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "f923f9a774fcf3f5cb761bfa43aeadd689714813"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.5.1+0"

[[deps.HypergeometricFunctions]]
deps = ["LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "68c173f4f449de5b438ee67ed0c9c748dc31a2ec"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.28"

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
git-tree-sha1 = "0ee181ec08df7d7c911901ea38baf16f755114dc"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "1.0.0"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "e12629406c6c4442539436581041d372d69c55ba"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.12"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "8c193230235bbcee22c8066b0374f63b5683c2d3"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.5"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs", "WebP"]
git-tree-sha1 = "696144904b76e1ca433b886b4e7edd067d76cbf7"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.9"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "2a81c3897be6fbcde0802a0ebe6796d0562f63ec"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.10"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0936ba688c6d201805a83da835b55c61a180db52"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.11+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

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

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "ec1debd61c300961f98064cfb21287613ad7f303"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2025.2.0+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "65d505fa4c0d7072990d659ef3fc086eb6da8208"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.16.2"
weakdeps = ["ForwardDiff", "Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsForwardDiffExt = "ForwardDiff"
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalArithmetic]]
deps = ["CRlibm", "MacroTools", "OpenBLASConsistentFPCSR_jll", "Printf", "Random", "RoundingEmulator"]
git-tree-sha1 = "bf0210c01fb7d67c31fed97d7c1d1716b98ea689"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "1.0.1"

    [deps.IntervalArithmetic.extensions]
    IntervalArithmeticArblibExt = "Arblib"
    IntervalArithmeticDiffRulesExt = "DiffRules"
    IntervalArithmeticForwardDiffExt = "ForwardDiff"
    IntervalArithmeticIntervalSetsExt = "IntervalSets"
    IntervalArithmeticLinearAlgebraExt = "LinearAlgebra"
    IntervalArithmeticRecipesBaseExt = "RecipesBase"
    IntervalArithmeticSparseArraysExt = "SparseArrays"

    [deps.IntervalArithmetic.weakdeps]
    Arblib = "fb37089c-8514-4489-9461-98f9c8763369"
    DiffRules = "b552c78f-8df3-52c6-915a-8e097449b14b"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.IntervalSets]]
git-tree-sha1 = "5fbb102dcb8b1a858111ae81d56682376130517d"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.11"

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

    [deps.IntervalSets.weakdeps]
    Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.InverseFunctions]]
git-tree-sha1 = "a779299d77cd080bf77b97535acecd73e1c5e5cb"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.17"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.IrrationalConstants]]
git-tree-sha1 = "b2d91fe939cae05960e760110b328288867b5758"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.6"

[[deps.Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

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

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "9496de8fb52c224a2e3f9ff403947674517317d9"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.6"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "4255f0032eafd6451d707a51d5f0248b8a165e4d"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.3+0"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "ba51324b894edaf1df3ab16e2cc6bc3280a2f1a7"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.10"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aaafe88dccbd957a8d82f7d05be9b69172e0cee3"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.0.1+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eb62a3deb62fc6d8822c0c4bef73e4412419c5d8"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.8+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1c602b1127f4751facb671441ca72715cc95938a"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.3+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

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

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c8da7e6a91781c41a863611c7e966098d783c57a"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.4.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "d36c21b9e7c172a44a10484125024495e2625ac0"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.1+1"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "3acf07f130a76f87c041cfb2ff7d7284ca67b072"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.41.2+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "f04133fe05eff1667d2054c53d59f9122383fe05"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.2+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "2a7a12fc0a4e7fb773450d17975322aa77142106"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.41.2+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "13ca9e2586b89836fd20cccf56e57e2b9ae7f38f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.29"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LsqFit]]
deps = ["Distributions", "ForwardDiff", "LinearAlgebra", "NLSolversBase", "Printf", "StatsAPI"]
git-tree-sha1 = "f386224fa41af0c27f45e2f9a8f323e538143b43"
uuid = "2fda8390-95c7-5789-9bda-21331edee243"
version = "0.15.1"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "282cadc186e7b2ae0eeadbd7a4dffed4196ae2aa"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2025.2.0+0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Makie]]
deps = ["Animations", "Base64", "CRC32c", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "ComputePipeline", "Contour", "Dates", "DelaunayTriangulation", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG_jll", "FileIO", "FilePaths", "FixedPointNumbers", "Format", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageBase", "ImageIO", "InteractiveUtils", "Interpolations", "IntervalSets", "InverseFunctions", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MacroTools", "Markdown", "MathTeXEngine", "Observables", "OffsetArrays", "PNGFiles", "Packing", "Pkg", "PlotUtils", "PolygonOps", "PrecompileTools", "Printf", "REPL", "Random", "RelocatableFolders", "Scratch", "ShaderAbstractions", "Showoff", "SignedDistanceFields", "SparseArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun", "Unitful"]
git-tree-sha1 = "368542cde25d381e44d84c3c4209764f05f4ef19"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.24.6"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "UnicodeFun"]
git-tree-sha1 = "a370fef694c109e1950836176ed0d5eabbb65479"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.6.6"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.5.20"

[[deps.NLSolversBase]]
deps = ["ADTypes", "DifferentiationInterface", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "25a6638571a902ecfb1ae2a18fc1575f86b1d4df"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.10.0"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "9b8215b1ee9e78a293f99797cd31375471b2bcae"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.3"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.Observables]]
git-tree-sha1 = "7438a59546cf62428fc9d1bc94729146d37a7225"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.5"

[[deps.OffsetArrays]]
git-tree-sha1 = "117432e406b5c023f665fa73dc26e79ec3630151"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.17.0"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6aa4566bb7ae78498a5e68943863fa8b5231b59"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.6+0"

[[deps.OpenBLASConsistentFPCSR_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "567515ca155d0020a45b05175449b499c63e7015"
uuid = "6cdc7f73-28fd-5e50-80fb-958a8875b1af"
version = "0.3.29+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "97db9e07fe2091882c765380ef58ec553074e9c7"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.3"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "8292dd5c8a38257111ada2174000a33745b06d4e"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.2.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.7+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.1+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c392fc5dd032381919e3b22dd32d6443760ce7ea"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.5.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.44.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "d922b4d80d1e12c658da7785e754f4796cc1d60d"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.36"
weakdeps = ["StatsBase"]

    [deps.PDMats.extensions]
    StatsBaseExt = "StatsBase"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "cf181f0b1e6a18dfeb0ee8acc4a9d1672499626c"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.4"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "bc5bf2ea3d5351edf285a06b0016788a121ce92c"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.5.1"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1f7f9bbd5f7a2e5a9f7d96e51c9754454ea7f60b"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.56.4+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "db76b1ecd5e9715f3d043cec13b2ec93ce015d53"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.44.2+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.12.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f9501cc0430a26bc3d156ae1b5b0c1b47af4d6da"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.3"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "3ca9a356cd2e113c420f2c13bea19f8d3fb1cb18"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.3"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "3faff84e6f97a7f18e0dd24373daa229fd358db5"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.73"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "07a921781cab75691315adc645096ed5e370cb77"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.3"

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

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "fbb92c6c56b34e1a2c4c36058f68f332bec840e7"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.11.0"

[[deps.PtrArrays]]
git-tree-sha1 = "1d36ef11a9aaf1e8b74dacc6a731dd1de8fd493d"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.3.0"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "8b3fc30bc0390abdce15f8822c889f669baed73d"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.1"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "9da16da70037ba9d701192e27befedefb91ec284"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.11.2"

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

    [deps.QuadGK.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"

[[deps.REPL]]
deps = ["InteractiveUtils", "JuliaSyntaxHighlighting", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "5b3d50eb374cea306873b371d3f8d3915a018f0b"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.9.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "58cdd8fb2201a6267e1db87ff148dd6c1dbd8ad8"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.5.1+0"

[[deps.RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "e24dc23107d426a096d3eae6c165b921e74c18e4"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.2"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "712fb0231ee6f9120e005ccd56297abbc053e7e0"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.8"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "c5391c6ace3bc430ca630251d02ea9687169ca68"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.2"

[[deps.ShaderAbstractions]]
deps = ["ColorTypes", "FixedPointNumbers", "GeometryBasics", "LinearAlgebra", "Observables", "StaticArrays"]
git-tree-sha1 = "818554664a2e01fc3784becb2eb3a82326a604b6"
uuid = "65257c39-d410-5151-9873-9b3e5be5013e"
version = "0.5.0"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SignedDistanceFields]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "be8eeac05ec97d379347584fa9fe2f5f76795bcb"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.5"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "0494aed9501e7fb65daba895fb7fd57cc38bc743"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.5"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "64d974c2e6fdf07f8155b5b2ca2ffa9069b608d9"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.2"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.12.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "f2685b435df2613e25fc10ad8c26dddb8640f547"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.6.1"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "95af145932c2ed859b63329952ce8d633719f091"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.3"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be1cf4eb0ac528d96f5115b4ed80c26a8d8ae621"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.2"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "b8693004b385c842357406e3af647701fe783f98"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.15"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6ab403037779dae8c514bad259f32a447262455a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.4"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9d72a13a3f4dd3795a195ac5a44d7d6ff5f552ff"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.1"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "a136f98cefaf3e2924a66bd75173d1c891ab7453"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.7"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "91f091a8716a6bb38417a6e6f274602a19aaa685"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.5.2"
weakdeps = ["ChainRulesCore", "InverseFunctions"]

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "725421ae8e530ec29bcbdddbe91ff8053421d023"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.1"

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "a2c37d815bf00575332b7bd0389f771cb7987214"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.7.2"

    [deps.StructArrays.extensions]
    StructArraysAdaptExt = "Adapt"
    StructArraysGPUArraysCoreExt = ["GPUArraysCore", "KernelAbstractions"]
    StructArraysLinearAlgebraExt = "LinearAlgebra"
    StructArraysSparseArraysExt = "SparseArrays"
    StructArraysStaticArraysExt = "StaticArrays"

    [deps.StructArrays.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.8.3+2"

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

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "98b9352a24cb6a2066f9ababcc6802de9aed8ad8"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.6"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "372b90fe551c019541fafc6ff034199dc19c8436"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.12"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "83360bda12f61c250835830cc40b64f487cc2230"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.25.1"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    ForwardDiffExt = "ForwardDiff"
    InverseFunctionsUnitfulExt = "InverseFunctions"
    LatexifyExt = ["Latexify", "LaTeXStrings"]
    PrintfExt = "Printf"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"
    LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
    Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
    Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WebP]]
deps = ["CEnum", "ColorTypes", "FileIO", "FixedPointNumbers", "ImageCore", "libwebp_jll"]
git-tree-sha1 = "aa1ca3c47f119fbdae8770c29820e5e6119b83f2"
uuid = "e3aaa7dc-3e4b-44e0-be63-ffb868ccd7c1"
version = "0.1.3"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fee71455b0aaa3440dfdd54a9a36ccef829be7d4"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.1+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "b5899b25d17bf1889d25906fb9deed5da0c15b3b"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.12+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "52858d64353db33a56e13c341d7bf44cd0d7b309"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.6+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "a4c0ee07ad36bf8bbce1c3bb52d21fb1e0b987fb"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.7+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "7ed9347888fac59a618302ee38216dd0379c480d"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.12+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXau_jll", "Xorg_libXdmcp_jll"]
git-tree-sha1 = "bfcaf7ec088eaba362093393fe11aa141fa15422"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.1+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a63799ff68005991f9d9491b6e95bd3478d783cb"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.6.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.1+2"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "371cc681c00a3ccc3fbc5c0fb91f58ba9bec1ecf"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.13.1+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "125eedcb0a4a0bba65b657251ce1d27c8714e9d6"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.4+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "07b6a107d926093898e82b3b1db657ebe33134ec"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.50+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll"]
git-tree-sha1 = "11e1772e7f3cc987e9d3de991dd4f6b2602663a5"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.8+0"

[[deps.libwebp_jll]]
deps = ["Artifacts", "Giflib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libglvnd_jll", "Libtiff_jll", "libpng_jll"]
git-tree-sha1 = "4e4282c4d846e11dce56d74fa8040130b7a95cb3"
uuid = "c5f90fcd-3b7e-5836-afba-fc50a0988cb2"
version = "1.6.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.64.0+1"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "1350188a69a6e46f799d3945beef36435ed7262f"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2022.0.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.5.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "14cc7083fc6dff3cc44f2bc435ee96d06ed79aa7"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.1+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e7b67590c14d487e734dcb925924c5dc43ec85f3"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "4.1.0+0"
"""

# ╔═╡ Cell order:
# ╟─d37b6946-11d7-459f-838e-5d84c80b0f11
# ╟─a42ede34-6c38-4106-9145-544cc0bd4e48
# ╟─62e69d33-1902-47a2-8d6d-9401a0ff065d
# ╟─5368f1ab-afd4-467d-82a5-d79b47676cd3
# ╟─bef2592b-048f-4407-a26b-58444953a85f
# ╟─3402bb40-b3d7-11f0-a219-b375107af3f7
# ╟─c6d848be-a3f0-4279-ba1b-df4f1ed2f026
# ╟─b50f3995-152f-44ca-926b-42dc893798ef
# ╟─0c287c83-2dad-4303-a9fd-343c821468b0
# ╟─6152f922-0342-48bb-bf48-c6206c6a3cf6
# ╟─5b0cc9ca-f269-4d74-9968-afb479cd2969
# ╟─fa2a3c3c-6aa1-40e7-b8a2-ec15ba4069cb
# ╟─8968e9d2-5e33-457d-8931-18432977d1c3
# ╟─0c722376-bbfd-45a9-bfa8-1aa8739f9a85
# ╟─59d16002-60a5-4bfe-a17f-932c3fd96aa8
# ╟─3dc912ad-cf32-42a2-a6b6-a4b21c122c7a
# ╟─add04be8-dce7-49f0-8390-3dea2076d2d7
# ╟─eca15e5f-33bf-4837-98d3-9ba64c9fcdf3
# ╟─245ca246-0aea-4b0a-a4bf-4c45e9ebfc4f
# ╟─51f6d474-2641-4dbb-93dc-c54ab46dff42
# ╟─32d4784a-d59b-4f6a-9f46-c53dc93f40e7
# ╟─e675760c-c2c7-4743-a96a-18b72a455435
# ╟─8000997f-84da-4420-b26e-fac3e7497a38
# ╟─fbce7664-c0de-496d-be00-10f76dea43b6
# ╟─43113a8f-5841-4789-b9fb-adcb2c48807b
# ╟─dd6fe4f1-7060-4dff-af11-d5f2c50f77c2
# ╟─a9987d0b-ca5e-4063-8ba7-128021588710
# ╟─52768246-c7e3-4d64-a6f9-cc1e342d1950
# ╟─462b1e0c-1232-4b2e-9365-d01b2e28be0d
# ╟─c87244ea-48b5-4766-ab5c-52b637ed13a9
# ╟─92e366d3-61d0-46e7-9c34-448697dc2aeb
# ╟─1e557802-e526-42dd-b9a2-63839e867eea
# ╟─7672cf1c-0219-45ea-ac50-8d724cb25483
# ╟─1f1d5a9e-53b4-42ef-9801-78254dbe45c5
# ╟─b7a4e62b-a2ad-407b-91a3-fdea7843d14f
# ╟─d1076ae7-56a8-4e35-9ab0-41455acd893b
# ╟─d231b4a7-7cd8-4497-8c70-231ff3783761
# ╟─a110527e-7fdf-4167-84e4-3c440a91f016
# ╟─8393867f-17a8-4eaa-a122-3ef3dd2ddfc8
# ╟─fb1f648c-5d2e-434d-b456-1d2b08f193e8
# ╟─269c9adf-2597-46cd-a7c7-297bc9c44681
# ╟─5825a5cb-a0be-49cd-be3d-c94161f8bc31
# ╟─1429b63b-8122-4351-9407-72272e782b6c
# ╟─5630d61f-d01a-4cf4-b569-0cc0bc00e66f
# ╟─4bcdc54a-5591-46c0-a1fd-e2bfa8e20553
# ╟─1c50fe2b-23df-4ba1-8d7e-9a67850f5c9a
# ╟─bf717e4b-1ac1-4101-81bf-f82e461133ba
# ╟─cffe1909-2e95-4019-bb2f-2afdec26d44e
# ╟─0999ebf3-6b38-4214-be53-f118c67b7c95
# ╟─5541a862-4ba6-4c05-b9c0-eaff4227e649
# ╟─d69144f5-2aaa-4fb3-a654-02c86aa1126a
# ╟─1ed28912-0a8c-4642-96e2-40a32a83c28c
# ╟─f3aa9f71-4929-436b-938e-9d6817c23487
# ╟─c0f892f0-f11c-4354-9699-577b4c13b2d4
# ╟─78c3cc81-0828-46d6-a9e6-88f25982a65f
# ╟─780eb61b-8d27-46a8-ac0a-11565c408474
# ╟─e8e881ba-96fb-41b3-8b5b-a27151635ee9
# ╟─27df242c-4752-4898-91cc-24832865827b
# ╟─7b3d5e74-0289-4285-92ce-2d422589b0d2
# ╟─13429b2e-dac8-46ee-85c4-143945d07074
# ╟─893df8c0-d71f-4b45-9de0-674975974403
# ╟─0a606de0-f28d-4136-90e8-89168b62a561
# ╟─d3b95b82-3786-4c19-a135-c4c85dbc4ff1
# ╟─8b0504e1-f480-4191-a4f4-cfe236bee4ef
# ╟─b5091909-f90e-46bf-ba43-ac9d3bbd8ea0
# ╟─f7ceb2cd-bb36-47dc-b3d3-4952149ff453
# ╟─8094903f-4a19-4643-8b18-5c7eb0b8adfb
# ╟─db705dba-8da8-4d56-bb6a-6ca96a737808
# ╟─58e9b26d-d62e-4b9e-976f-d1b49a90fc16
# ╟─f697d192-d434-4203-b1b8-043e61ab60a5
# ╟─ff9b154e-7440-4095-ae5d-490c632714b4
# ╟─0ac6a248-ea47-4274-a043-3923aefef296
# ╟─824d7572-067e-4d7e-a958-5c9e3b942e2a
# ╟─b63dacdf-b6f1-4844-b1ea-b0944f2ac206
# ╟─f9393768-1fad-4327-ab2f-4b2221b92bf5
# ╟─1b871b02-3dbd-4388-b5ee-d9ab39f5e7b9
# ╟─ffc702bf-2b17-4168-a423-826ab0821d47
# ╠═4fe9fbb9-d10b-400f-96d9-05bf799f6879
# ╟─52bd99e5-64c0-4520-a4bf-cb4c40dbc720
# ╟─bd8f5ed4-7a66-4256-a4ea-690280cca8a0
# ╟─63f62bc8-7673-49c5-ba40-18c3a1dbebcf
# ╟─8a062689-2c97-4e06-8693-b7fa93699a34
# ╟─8230d169-70d3-4668-abde-5d652d2ccf07
# ╟─e20a1060-ab8a-4577-a251-ce0e5f89a023
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
