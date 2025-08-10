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
    % Author   : D. Kovaleva
    % Date: Jul 2025
    % Example: totalFlux = transmission.calibrators.calculateTotalFluxCalibrators(); % Uses defaults
    %          [SpecTrans, Wavelength, ~] = transmission.calibrators.applyTransmissionToCalibrators();
    %          totalFlux = transmission.calibrators.calculateTotalFluxCalibrators(Wavelength, SpecTrans{1,1});
    
    arguments
        Wavelength double = transmission.utils.makeWavelengthArray(transmission.inputConfig())  % nm 
        TransmittedFlux double = []                   % Transmitted flux spectrum (flux * transmission already applied)
        Metadata = []                                 % Metadata structure from findCalibratorsWithCoords
        Args.dt = NaN                          % Time interval (seconds)
        Args.Ageom double = pi * (0.1397^2)           % Geometric area (m²) - LAST telescope aperture
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
% disp(Dt);    
    % Physical constants using AstroPack
    H = constant.h('SI');      % Planck constant [SI]
    C = constant.c('SI');      % Speed of light [SI]
  %  disp(H);
  %  disp(C);
  % Convert wavelength from nm to cm for calculation
     
    % Handle both single spectrum (array) and multiple spectra (cell array)
    if iscell(TransmittedFlux)
        % Multiple spectra - process each one
        Nspectra = size(TransmittedFlux, 1);
        totalFlux = repmat(0, Nspectra, 1);%#ok<*RPMT0>
        
        for i = 1 : Nspectra
            % Calculate the integrand: transmitted_flux * wavelength (in meters)
            % (transmission already applied in applyTransmissionToCalibrators)
            Integrand = TransmittedFlux{i,1} .* Wavelength;
   %         disp(Integrand);
            
            % Integrate using trapezoidal rule 
            A = trapz(Wavelength, Integrand);
    %        disp(A);
            
            % Calculate normalization factor (nanometers to meters)
            B = H * C * 1e9;
    %        disp(B);
            % Calculate total flux in photons. Normalization ~ 0.5 to fit
            % the scale
            totalFlux(i) = 0.5* Dt * Args.Ageom * A / B;
        end
    else
        % Single spectrum - process as before
        % Calculate the integrand: transmitted_flux * wavelength (in meters)
        % (transmission already applied in applyTransmissionToCalibrators)
        Integrand = TransmittedFlux .* Wavelength;
        
        % Integrate using trapezoidal rule (equivalent to scipy.integrate.trapz)
        A = trapz(Wavelength, Integrand);
        
        % Calculate normalization factor (nanometers to meters)
        B = H * C *1e9;
        
        % Calculate total flux in photons. Normalization ~ 0.5 to fit the
        % scale.
        totalFlux =  0.5 * Dt * Args.Ageom * A / B;
    end
% toc   
end