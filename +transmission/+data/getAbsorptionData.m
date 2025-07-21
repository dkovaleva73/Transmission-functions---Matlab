function [wavelength, absorption, metadata] = getAbsorptionData(abs_data, species, varargin)
    % Extract absorption data for a specific molecular species
    %
    % Usage:
    %   [wvl, abs] = transmission.data.getAbsorptionData(abs_data, 'O3UV')
    %   [wvl, abs] = transmission.data.getAbsorptionData(abs_data, 'H2O', 'WavelengthRange', [300, 800])
    %   [wvl, abs, meta] = transmission.data.getAbsorptionData(abs_data, 'CO2', 'Interpolate', true)
    %
    % Parameters:
    %   abs_data - Data structure from loadAbsorptionData()
    %   species  - Molecular species name (e.g., 'O3UV', 'H2O', 'CO2')
    %   'WavelengthRange' - [min, max] wavelength range to extract [nm]
    %   'Interpolate'     - If true, return interpolation function instead of raw data
    %   'Units'           - Output wavelength units: 'nm' (default), 'Ang', 'um'
    %
    % Returns:
    %   wavelength - Wavelength array [specified units]
    %   absorption - Absorption coefficients/cross-sections
    %   metadata   - Additional information about the species data
    %
    % Example:
    %   abs_data = transmission.data.loadAbsorptionData();
    %   [wvl, abs_coeff] = transmission.data.getAbsorptionData(abs_data, 'O3UV');
    %   ozone_transmission = exp(-airmass * abs_coeff * ozone_column);
    %
    % Author: D. Kovaleva (July 2025)
    
    %% Parse inputs
    p = inputParser;
    addRequired(p, 'abs_data', @isstruct);
    addRequired(p, 'species', @(x) ischar(x) || isstring(x));
    addParameter(p, 'WavelengthRange', [], @(x) isempty(x) || (isnumeric(x) && length(x) == 2));
    addParameter(p, 'Interpolate', false, @islogical);
    addParameter(p, 'Units', 'nm', @(x) ismember(lower(x), {'nm', 'ang', 'a', 'um', 'μm'}));
    parse(p, abs_data, species, varargin{:});
    
    species = char(p.Results.species);
    wvl_range = p.Results.WavelengthRange;
    do_interpolate = p.Results.Interpolate;
    output_units = lower(p.Results.Units);
    
    %% Validate inputs
    if ~isfield(abs_data, 'species')
        error('Invalid absorption data structure. Use loadAbsorptionData() first.');
    end
    
    if ~ismember(species, abs_data.species)
        error('Species "%s" not found in absorption data.\nAvailable species: %s', ...
              species, strjoin(abs_data.species, ', '));
    end
    
    %% Extract species data
    species_data = abs_data.(species);
    wavelength = species_data.wavelength;
    absorption = species_data.absorption;
    
    % Create metadata
    metadata = struct();
    metadata.species = species;
    metadata.filename = species_data.filename;
    metadata.format = species_data.format;
    metadata.n_points = length(wavelength);
    metadata.wavelength_range = [min(wavelength), max(wavelength)];
    metadata.absorption_range = [min(absorption), max(absorption)];
    
    %% Apply wavelength range filter
    if ~isempty(wvl_range)
        mask = wavelength >= wvl_range(1) & wavelength <= wvl_range(2);
        wavelength = wavelength(mask);
        absorption = absorption(mask);
        
        metadata.filtered = true;
        metadata.filter_range = wvl_range;
        metadata.n_points_filtered = length(wavelength);
    else
        metadata.filtered = false;
    end
    
    %% Convert wavelength units
    if ~strcmp(output_units, 'nm')
        switch output_units
            case {'ang', 'a'}
                wavelength = wavelength * 10;  % nm to Angstroms
                metadata.wavelength_units = 'Angstrom';
            case {'um', 'μm'}
                wavelength = wavelength / 1000;  % nm to micrometers
                metadata.wavelength_units = 'micrometer';
            otherwise
                error('Unsupported wavelength units: %s', output_units);
        end
    else
        metadata.wavelength_units = 'nanometer';
    end
    
    %% Create interpolation function if requested
    if do_interpolate
        % Create interpolation function for the data
        interp_func = @(query_wavelength) interp1(wavelength, absorption, query_wavelength, 'linear', 0);
        
        % Return function instead of arrays
        wavelength = interp_func;
        absorption = [];  % Not applicable for interpolation function
        
        metadata.interpolation = true;
        metadata.interpolation_method = 'linear';
        metadata.extrapolation_value = 0;
    else
        metadata.interpolation = false;
    end
    
    %% Validate output
    if ~do_interpolate
        if isempty(wavelength) || isempty(absorption)
            warning('No data points found in specified wavelength range [%.1f, %.1f] nm', ...
                    wvl_range(1), wvl_range(2));
        end
        
        if length(wavelength) ~= length(absorption)
            error('Wavelength and absorption arrays have inconsistent lengths');
        end
    end
end