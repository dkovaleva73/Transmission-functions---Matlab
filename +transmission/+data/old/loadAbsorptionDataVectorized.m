function Abs_data = loadAbsorptionDataVectorized(Data_dir, Gas_list, Verbose)
    % Memory-optimized vectorized absorption data loader
    % Uses original data loader then reorganizes for optimal memory layout
    %
    % Parameters:
    %   Data_dir (string): Directory containing absorption data (optional)
    %   Gas_list (cell array): List of gases to load (e.g., {'H2O'})
    %   Verbose (logical): Print loading information (default: false)
    %
    % Returns:
    %   Abs_data (struct): Absorption data optimized for vectorized operations
    
    if nargin < 1 || isempty(Data_dir)
        Data_dir = [];  % Let original loader use default
    end
    if nargin < 2
        Gas_list = {'H2O'};
    end
    if nargin < 3
        Verbose = false;
    end
    
    if Verbose
        fprintf('Loading absorption data (memory-optimized)...\n');
    end
    
    % STRATEGY: Use original loader to ensure correctness, then optimize layout
    original_data = transmission.data.loadAbsorptionData(Data_dir, Gas_list, Verbose);
    
    % Initialize output structure
    Abs_data = struct();
    
    % Process each requested gas
    for gas_idx = 1:length(Gas_list)
        gas_name = Gas_list{gas_idx};
        
        if strcmpi(gas_name, 'H2O')
            Abs_data.H2O = optimizeWaterVaporDataLayout(original_data.H2O, Verbose);
        else
            error('Gas %s not yet supported in optimized loader', gas_name);
        end
    end
    
    if Verbose
        fprintf('Memory-optimized data loading complete.\n');
    end
end

function H2O_data = optimizeWaterVaporDataLayout(original_h2o, Verbose)
    % Optimize water vapor data layout for vectorized operations
    % Takes correctly loaded data and reorganizes for optimal memory layout
    
    if Verbose
        fprintf('  Optimizing H2O data layout for vectorized operations...\n');
    end
    
    % MEMORY OPTIMIZATION: Organize data for column-major access
    % Store arrays as columns for optimal MATLAB performance
    H2O_data = struct();
    
    % Basic data (copy from original)
    H2O_data.wavelength = original_h2o.wavelength;   % Column vector (optimal)
    H2O_data.absorption = original_h2o.absorption;   % Column vector (optimal)
    H2O_data.band = original_h2o.band;               % Column vector (optimal)
    
    % Extract coefficients from fit_coeffs structure
    fit_coeffs = original_h2o.fit_coeffs;
    
    % Fitting parameters (organize as matrices for vectorized operations)
    % BW parameters
    H2O_data.ifitw = int32(fit_coeffs.Ifitw);                                    % Integer conversion
    H2O_data.Bw_coeffs = [fit_coeffs.Bwa0, fit_coeffs.Bwa1, fit_coeffs.Bwa2];  % 3-column matrix
    
    % BM parameters  
    H2O_data.ifitm = int32(fit_coeffs.Ifitm);                                    % Integer conversion
    H2O_data.Bm_coeffs = [fit_coeffs.Bma0, fit_coeffs.Bma1, fit_coeffs.Bma2];  % 3-column matrix
    
    % BMW parameters
    H2O_data.ifitmw = int32(fit_coeffs.Ifitmw);                                      % Integer conversion
    H2O_data.Bmw_coeffs = [fit_coeffs.Bmwa0, fit_coeffs.Bmwa1, fit_coeffs.Bmwa2];  % 3-column matrix
    
    % BP parameters
    H2O_data.Bp_coeffs = [fit_coeffs.Bpa1, fit_coeffs.Bpa2];  % 2-column matrix
    
    % Pre-compute commonly used values for performance
    H2O_data.num_wavelengths = length(H2O_data.wavelength);
    H2O_data.wavelength_range = [min(H2O_data.wavelength), max(H2O_data.wavelength)];
    
    % Pre-compute band-specific reference water values (vectorized lookup)
    H2O_data.pw0_lookup = computePw0Lookup(H2O_data.band);
    
    if Verbose
        fprintf('    Wavelengths: %d points, range: %.0f - %.0f nm\n', ...
                H2O_data.num_wavelengths, H2O_data.wavelength_range);
        fprintf('    Memory layout optimized for column-major access\n');
    end
end

function pw0_values = computePw0Lookup(band_array)
    % Pre-compute pw0 values for all bands (vectorized)
    
    pw0_values = 4.11467 * ones(size(band_array)); % Default value
    
    % Vectorized band-specific assignments
    pw0_values(band_array == 2) = 2.92232;
    pw0_values(band_array == 3) = 1.41642;
    pw0_values(band_array == 4) = 0.41612;
    pw0_values(band_array == 5) = 0.05663;
end