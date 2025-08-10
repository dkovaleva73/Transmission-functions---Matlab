function [SpecTrans, Wavelength, TransFunc] = applyTransmissionToCalibrators(Spec, Metadata, Config)
    % Apply transmission function to calibrator spectra
    % Extends Gaia spectra from 336-1020 nm to 300-1100 nm with flux extrapolation
    % Input :  - Spec - Cell array {N x 2} from findCalibratorsWithCoords:
    %              - Column 1: Flux values (343 wavelength points, 336-1020 nm)
    %              - Column 2: Flux error values (343 wavelength points)
    %          - Metadata - Structure with observation metadata from findCalibratorsWithCoords
    %                Optional key-value pairs:
    %              - 'Config' - Transmission configuration (default: use Metadata values)
    %              - 'ApplyTransmission' - Apply transmission function (default: true)
    %              - 'Verbose' - Display progress (default: true)
    % Output : - SpecTrans - Cell array {N x 2} with:
    %              - Column 1: Flux values with transmission applied (401 points, 300-1100 nm)
    %              - Column 2: Flux error values with transmission applied
    %   Wavelength - Wavelength array (300-1100 nm, 401 points)
    %   TransFunc  - Total transmission function array (401 points)
    % Reference : Garrappa et al. 2025, A&A 699, A50.
    % Author: D. Kovaleva
    % Date: Jul 2025
    % Example:  [Spec, ~, ~, Metadata] = transmission.data.findCalibratorsWithCoords(CatFile);
    %           [SpecTrans, Wavelength, TransFunc] = transmission.data.applyTransmissionToCalibrators(Spec, Metadata);
    %
    % 
    
    arguments
        Spec = []
        Metadata = []
        Config   = transmission.inputConfig()
    end
    
    % If Spec or Metadata not provided, get them from findCalibratorsWithCoords
    if isempty(Spec) || isempty(Metadata)
        [DefaultSpec, ~, ~, ~, DefaultMetadata] = transmission.data.findCalibratorsWithCoords();
        if isempty(Spec)
            Spec = DefaultSpec;
        end
        if isempty(Metadata)
            Metadata = DefaultMetadata;
        end
    end   
 
%tic
     % Define wavelength grids
    Gaiawvl = Config.Utils.Gaia_wavelength;
  %  Gaiawvl = Gaiawvl(:);

    ZenithAngle = acosd(1/Metadata.airMassFromLAST); 
    Config.Atmospheric.Zenith_angle_deg = ZenithAngle;
    
    % Target wavelength grid: 300-1100 nm in 2 nm steps (401 points)
    % This matches the default transmission function wavelength grid
    Wavelength = transmission.utils.makeWavelengthArray(Config);
   %  Wavelength = Wavelength(:); % Make column vector
    
    % Number of spectra
    Nspec = size(Spec, 1);
    
    % Initialize output
    SpecTrans = cell(Nspec, 2);
        
    Config.Atmospheric.Temperature = Metadata.Temperature;
    
    % At the moment, AstroHeader of template files does not contain Pressure
    if ~isnan(Metadata.Pressure)
        Config.Atmospheric.Pressure = Metadata.Pressure;
    end

    % Calculate transmission function
    TransFunc = transmission.totalTransmission(Wavelength, Config);
 
    % Find indices for mapping Gaia wavelengths to extended grid
    % Gaia starts at 336 nm, our grid starts at 300 nm
    start_idx = find(Wavelength == Gaiawvl(1));
    end_idx = find(Wavelength == Gaiawvl(end));

    % Process each spectrum
    for i = 1:Nspec
        % Extract Gaia flux and error
        gaia_flux = Spec{i, 1}(:);      % Ensure column vector
        gaia_error = Spec{i, 2}(:);
        
        % Initialize extended arrays with zeros
        extended_flux = repmat(0,size(Wavelength));%#ok<*RPMT0> 
        extended_error = repmat(0,size(Wavelength));%#ok<*RPMT0> 
        %% 
   %     disp(length(gaia_flux));
        % Fill in the Gaia data in the appropriate range
        extended_flux(start_idx:end_idx) = gaia_flux;
        extended_error(start_idx:end_idx) = gaia_error;
        
        % Extrapolate flux at 336 nm down to 300 nm
        if start_idx > 1
            extended_flux(1:start_idx-1) = gaia_flux(1);
            extended_error(1:start_idx-1) = gaia_error(1);
        end
        
        % Extrapolate flux at 1020 nm up to 1100 nm
        if end_idx < length(Wavelength)
            extended_flux(end_idx+1:end) = gaia_flux(end);
            extended_error(end_idx+1:end) = gaia_error(end);
        end
        
        % Apply transmission function
        flux_trans = extended_flux .* TransFunc;
        error_trans = extended_error .* TransFunc;
        
        % Store results
        SpecTrans{i, 1} = flux_trans;
        SpecTrans{i, 2} = error_trans;
       
    end
% toc       
  end
    
