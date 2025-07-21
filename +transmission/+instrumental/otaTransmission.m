function Ota_transmission = otaTransmission(Lam, Qe_params, Mirror_params, Corrector_params)
    % Calculate complete OTA (Optical Telescope Assembly) transmission
    %
    % Parameters:
    %   Lam (double array): Wavelength array in nm
    %   Qe_params (struct): Quantum efficiency parameters with fields:
    %     - amplitude, center, sigma, gamma (SkewedGaussian)
    %     - l0, l1, l2, l3, l4, l5, l6, l7, l8 (Legendre coefficients)
    %   Mirror_params (struct): Mirror reflectance parameters with fields:
    %     - use_orig_xlt (logical): Use data file (true) or polynomial (false)
    %     - r0, r1, r2, r3, r4 (polynomial coefficients, if use_orig_xlt = false)
    %   Corrector_params (struct): Corrector transmission parameters with fields:
    %     - c0, c1, c2, c3, c4 (polynomial coefficients)
    %
    % Returns:
    %   Ota_transmission (double array): Complete OTA transmission (0-1)
    %
    % Example:
    %   Lam = transmission.utils.makeWavelengthArray(350, 1000, 651);
    %   Qe_params = struct('amplitude', 328.19, 'center', 570.97, 'sigma', 139.77, 'gamma', -0.1517, ...
    %                      'l0', -0.30, 'l1', 0.34, 'l2', -1.89, 'l3', -0.82, 'l4', -3.73, ...
    %                      'l5', -0.669, 'l6', -2.06, 'l7', -0.24, 'l8', -0.60);
    %   Mirror_params = struct('use_orig_xlt', true, 'r0', 0, 'r1', 0, 'r2', 0, 'r3', 0, 'r4', 0);
    %   Corrector_params = struct('c0', 0, 'c1', 0, 'c2', 0, 'c3', 0, 'c4', 0);
    %   Ota = transmission.instrumental.otaTransmission(Lam, Qe_params, Mirror_params, Corrector_params);
    
    arguments
        Lam (:,1) double
        Qe_params (1,1) struct
        Mirror_params (1,1) struct
        Corrector_params (1,1) struct
    end
    
    % Import instrumental functions
    import transmission.instrumental.quantumEfficiency
    import transmission.instrumental.mirrorReflectance
    import transmission.instrumental.correctorTransmission
    
    % Set default parameters if not provided
    if ~isfield(Qe_params, 'amplitude'), Qe_params.amplitude = 328.19; end
    if ~isfield(Qe_params, 'center'), Qe_params.center = 570.97; end
    if ~isfield(Qe_params, 'sigma'), Qe_params.sigma = 139.77; end
    if ~isfield(Qe_params, 'gamma'), Qe_params.gamma = -0.1517; end
    if ~isfield(Qe_params, 'l0'), Qe_params.l0 = -0.30; end
    if ~isfield(Qe_params, 'l1'), Qe_params.l1 = 0.34; end
    if ~isfield(Qe_params, 'l2'), Qe_params.l2 = -1.89; end
    if ~isfield(Qe_params, 'l3'), Qe_params.l3 = -0.82; end
    if ~isfield(Qe_params, 'l4'), Qe_params.l4 = -3.73; end
    if ~isfield(Qe_params, 'l5'), Qe_params.l5 = -0.669; end
    if ~isfield(Qe_params, 'l6'), Qe_params.l6 = -2.06; end
    if ~isfield(Qe_params, 'l7'), Qe_params.l7 = -0.24; end
    if ~isfield(Qe_params, 'l8'), Qe_params.l8 = -0.60; end
    
    if ~isfield(Mirror_params, 'use_orig_xlt'), Mirror_params.use_orig_xlt = true; end
    if ~isfield(Mirror_params, 'r0'), Mirror_params.r0 = 0.0; end
    if ~isfield(Mirror_params, 'r1'), Mirror_params.r1 = 0.0; end
    if ~isfield(Mirror_params, 'r2'), Mirror_params.r2 = 0.0; end
    if ~isfield(Mirror_params, 'r3'), Mirror_params.r3 = 0.0; end
    if ~isfield(Mirror_params, 'r4'), Mirror_params.r4 = 0.0; end
    
    if ~isfield(Corrector_params, 'c0'), Corrector_params.c0 = 0.0; end
    if ~isfield(Corrector_params, 'c1'), Corrector_params.c1 = 0.0; end
    if ~isfield(Corrector_params, 'c2'), Corrector_params.c2 = 0.0; end
    if ~isfield(Corrector_params, 'c3'), Corrector_params.c3 = 0.0; end
    if ~isfield(Corrector_params, 'c4'), Corrector_params.c4 = 0.0; end
    
    % Calculate individual components
    Qe = quantumEfficiency(Lam, Qe_params.amplitude, Qe_params.center, Qe_params.sigma, Qe_params.gamma, ...
                          Qe_params.l0, Qe_params.l1, Qe_params.l2, Qe_params.l3, Qe_params.l4, ...
                          Qe_params.l5, Qe_params.l6, Qe_params.l7, Qe_params.l8);
    
    Ref_mirror = mirrorReflectance(Lam, Mirror_params.use_orig_xlt, Mirror_params.r0, Mirror_params.r1, ...
                                  Mirror_params.r2, Mirror_params.r3, Mirror_params.r4);
    
    Trans_corrector = correctorTransmission(Lam, Corrector_params.c0, Corrector_params.c1, ...
                                           Corrector_params.c2, Corrector_params.c3, Corrector_params.c4);
    
    % Calculate total OTA transmission
    Ota_transmission = Qe .* Ref_mirror .* Trans_corrector;
    
    % Ensure values are in valid range [0, 1]
    Ota_transmission = max(0, min(1, Ota_transmission));
end