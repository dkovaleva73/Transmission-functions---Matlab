function totalFlux = calculateTotalFluxCalibrators(Wavelength, TransmittedFlux, Metadata, Args)
    % Calculate total transmitted flux in photons for calibrators
    % Uses output from applyTransmissionToCalibrators as input (flux already multiplied by transmission)
    % Input:  - Wavelength - Wavelength array (nm) from applyTransmissionToCalibrators
    %         - TransmittedFlux - Transmitted flux spectra from applyTransmissionToCalibrators (cell array or single array)
    %         - Metadata - Structure from findCalibratorsWithCoords containing ExpTime
    %         * ...,key,val,...
    %           'dt' - Time interval (default: uses Metadata.ExpTime if available, else 20.0 seconds)
    %           'Ageom' - Geometric area of telescope aperture (default: π*(0.1397)² m² for LAST)
    % Output   : - totalFlux - Total transmitted flux in photons (array, one value per spectrum)
    % Reference: Garrappa et al. 2025, A&A 699, A50.
    % Author   : D. Kovaleva (Aug 2025)
    % Example: totalFlux = transmission.calibrators.calculateTotalFluxCalibrators(); % Uses defaults
    %          [SpecTrans, Wavelength, ~] = transmission.calibrators.applyTransmissionToCalibrators();
    %          totalFlux = transmission.calibrators.calculateTotalFluxCalibrators(Wavelength, SpecTrans{1,1});
    
    arguments
        Wavelength double = transmission.utils.makeWavelengthArray(transmission.inputConfig())  % nm 
        TransmittedFlux double = []                   % Transmitted flux spectrum (flux * transmission already applied) - double array [Nspec x Nwavelength]
        Metadata = []                                 % Metadata structure from findCalibratorsWithCoords
        Args.dt = 20                                  % Time interval (seconds)
        Args.Ageom double = []                        % Geometric area (m²) - uses Config.Instrumental.Telescope.Aperture_area_m2 if empty
        Args.Norm_ = transmission.inputConfig().General.Norm_ % Normalization constant, to be fitted
        Args.ZeroPointMode logical = false            % If true: B=H, Dt=1 for zero-point calculation
    end
    
 % tic    
    % If TransmittedFlux or Metadata not provided, get them automatically
    if isempty(TransmittedFlux) || isempty(Metadata)
        % Get calibrator data and apply transmission
        [Spec, ~, ~, ~, DefaultMetadata] = transmission.data.findCalibratorsWithCoords();
        [SpecTrans, DefaultWavelength, ~] = transmission.calibrators.applyTransmissionToCalibrators(Spec, DefaultMetadata);
        
        if isempty(TransmittedFlux)
            TransmittedFlux = SpecTrans; % Use all spectra (cell array)
            Wavelength = DefaultWavelength;   % Use wavelength from applyTransmissionToCalibrators
        end
        if isempty(Metadata)
            Metadata = DefaultMetadata;
        end
    end
        
    % Determine Dt: use provided value, or Metadata.ExpTime, or default
    if ~isnan(Args.dt)
        Dt = Args.dt;
%    elseif ~isempty(Metadata) && isfield(Metadata, 'ExpTime') && ~isnan(Metadata.ExpTime)
%        Dt = Metadata.ExpTime;
    else 
        Dt = 20.0;  % Default 
 %   else 
 %     Dt = 1.0; 
    end
    
    % Determine Ageom: use provided value or get from Config
    if isempty(Args.Ageom)
        Config = transmission.inputConfig();
        Ageom = Config.Instrumental.Telescope.Aperture_area_m2;
    else
        Ageom = Args.Ageom;
    end
   
    % Physical constants using AstroPack
    H = constant.h('SI');      % Planck constant [SI]
    C = constant.c('SI');      % Speed of light [SI]

  % Convert wavelength from nm to cm for calculation
     
    % Handle multiple spectra (double array [Nspec x Nwavelength])
    if isempty(TransmittedFlux)
        totalFlux = [];
        return;
    end
    
    % Convert cell array to double matrix (from applyTransmissionToCalibrators)
    if iscell(TransmittedFlux)
        numSpectra = length(TransmittedFlux);
        if numSpectra > 0
            numWavelengths = length(TransmittedFlux{1});
            doubleArray = zeros(numSpectra, numWavelengths);
            for i = 1:numSpectra
                doubleArray(i, :) = TransmittedFlux{i}(:)';
            end
            TransmittedFlux = doubleArray;
        else
            TransmittedFlux = [];
        end
    end
    
    Nspectra = size(TransmittedFlux, 1);
    totalFlux = zeros(Nspectra, 1);
    
    % Calculate flux for each spectrum
    for i = 1 : Nspectra
        % Calculate the integrand: transmitted_flux * wavelength (in nm)
        % (transmission already applied in applyTransmissionToCalibrators)
        Integrand = TransmittedFlux(i, :) .* Wavelength(:)';
        
        % Integrate using trapezoidal rule 
        A = trapz(Wavelength, Integrand);
        
        % Calculate normalization factor based on mode
        if Args.ZeroPointMode
            % Zero-point mode: B = H, no photon conversion
            B = H;  % No nm to m conversion
            % For zero-point: Dt = 1
            totalFlux(i) = Args.Norm_ * A / B;
        else
            % Normal mode: convert to photons
            B = H * C * 1e9;  % H*C with nm to m conversion
            totalFlux(i) = Args.Norm_ * Dt * Ageom * A / B;
        end
    end
% toc   
end