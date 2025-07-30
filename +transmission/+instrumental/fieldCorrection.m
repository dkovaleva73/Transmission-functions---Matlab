function Field_corr = fieldCorrection(X_coord, Y_coord, Field_params)
    % Calculate field-dependent corrections using Chebyshev polynomials
    % Input  : - X_coord (double array): X coordinates of sources (pixels)
    %          - Y_coord (double array): Y coordinates of sources (pixels)
    %          - Field_params (struct): Field correction parameters with fields:
    %            .kx0, ky0 (double): Constant offset
    %            .kx, .kx2, .kx3, .kx4 (double): Chebyshev coefficients for X
    %            .ky, .ky2, .ky3, .ky4 (double): Chebyshev coefficients for Y
    %            .kxy (double): Cross-term coefficient
    %            .enable (logical, optional): Enable corrections (default: true)
    % Output : - Field_corr (double array): Field corrections (magnitude units)
    % Author : D. Kovaleva (Jul 2025)
    % Reference : Garrappa et al. 2025, A&A 699, A50.
    % Example: % Single source at detector center
    %          Field_params = struct('kx0', 0.1, 'ky0', 0.0,'kx', 0.02, 'kx2', -0.01, ...
    %                               'kx3', 0.005, 'kx4', -0.002, ...
    %                               'ky', 0.01, 'ky2', -0.005, ...
    %                               'ky3', 0.002, 'ky4', -0.001, ...
    %                               'kxy', 0.003);
    %          fc = transmission.instrumental.fieldCorrection(863, 863, Field_params);
    %          % Multiple sources
    %          X = [100, 863, 1626];
    %          Y = [100, 863, 1626];
    %          fc = transmission.instrumental.fieldCorrection(X, Y, Field_params);
    
    arguments
        X_coord 
        Y_coord 
        Field_params 
    end
    
    % Check if corrections are enabled
    if isfield(Field_params, 'enable') && ~Field_params.enable
        Field_corr = repmat(0, size(X_coord));%#ok<*RPMT0>
        return;
    end
    
    % Set default values for missing parameters
    if ~isfield(Field_params, 'kx0'), Field_params.kx0 = 0.0; end
    if ~isfield(Field_params, 'ky0'), Field_params.ky0 = 0.0; end
    if ~isfield(Field_params, 'kx'), Field_params.kx = 0.0; end
    if ~isfield(Field_params, 'kx2'), Field_params.kx2 = 0.0; end
    if ~isfield(Field_params, 'kx3'), Field_params.kx3 = 0.0; end
    if ~isfield(Field_params, 'kx4'), Field_params.kx4 = 0.0; end
    if ~isfield(Field_params, 'ky'), Field_params.ky = 0.0; end
    if ~isfield(Field_params, 'ky2'), Field_params.ky2 = 0.0; end
    if ~isfield(Field_params, 'ky3'), Field_params.ky3 = 0.0; end
    if ~isfield(Field_params, 'ky4'), Field_params.ky4 = 0.0; end
    if ~isfield(Field_params, 'kxy'), Field_params.kxy = 0.0; end
    
    % Normalize coordinates to [-1, 1] range 

    Xcoor_ = transmission.utils.rescaleInputData(X_coord, 0, 1726, -1, 1);
    Ycoor_ = transmission.utils.rescaleInputData(Y_coord, 0, 1726, -1, 1);
    
    % Calculate Chebyshev polynomials for X
    % First coefficient is 0 (skip T_0), matching Python: Chebyshev([0., kx, kx2, kx3, kx4])
    Coeff_x = [0., Field_params.kx, Field_params.kx2, Field_params.kx3, Field_params.kx4];
    Cheb_x_val = transmission.utils.chebyshevModel(Xcoor_, 4, Coeff_x, 'X', 'zp');
    
    % Calculate Chebyshev polynomials for Y
    Coeff_y = [0., Field_params.ky, Field_params.ky2, Field_params.ky3, Field_params.ky4];
    Cheb_y_val = transmission.utils.chebyshevModel(Ycoor_, 4, Coeff_y, 'X', 'zp');
    
    % Calculate cross-term Chebyshev polynomials
    % Python: Chebyshev([0., kxy])
    Coeff_xy = [0., Field_params.kxy];
    Cheb_xy_x = transmission.utils.chebyshevModel(Xcoor_, 1, Coeff_xy, 'X', 'zp');
    Cheb_xy_y = transmission.utils.chebyshevModel(Ycoor_, 1, Coeff_xy, 'X', 'zp');
    
    % Calculate total field correction 
    Field_corr = Cheb_x_val + Cheb_y_val + Field_params.kx0 + Field_params.ky0 + Cheb_xy_x .* Cheb_xy_y;
end