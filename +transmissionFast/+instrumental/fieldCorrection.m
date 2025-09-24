function Field_corr = fieldCorrection(X_coord, Y_coord, Config, Args)
    % Calculate field-dependent corrections using Chebyshev polynomials
    % Input  : - X_coord (double array): X coordinates of sources (pixels)
    %          - Y_coord (double array): Y coordinates of sources (pixels)
    %          - Config (struct): Configuration from inputConfig containing:
    %            Config.FieldCorrection.Python.{kx0, ky0, kx, ky, kx2, ky2, kx3, ky3, kx4, ky4, kxy}
    %            Config.Instrumental.Detector.{Min_coordinate, Max_coordinate}
    %          - Args (optional): Additional arguments
    %            'Enable' (logical): Enable corrections (default: true)
    % Output : - Field_corr (double array): Field corrections (magnitude units)
    % Author : D. Kovaleva (Jul 2025)
    % Reference : Garrappa et al. 2025, A&A 699, A50.
    % Example: % With Config
    %          Config = transmissionFast.inputConfig();
    %          Config.FieldCorrection.Python.kx0 = 0.1;
    %          Config.FieldCorrection.Python.kx = 0.02;
    %          % ... set other parameters
    %          fc = transmissionFast.instrumental.fieldCorrection([100, 863], [100, 863], Config);
    
    arguments
        X_coord 
        Y_coord 
        Config 
        Args.Enable logical = true
    end
    
    % Check if corrections are enabled
    if ~Args.Enable
        Field_corr = zeros(size(X_coord));
        return;
    end
    
    % Use field correction parameters directly from Config
    if ~isfield(Config, 'FieldCorrection')
        Field_corr = zeros(size(X_coord));
        return;
    end
    
    FieldParams = Config.FieldCorrection;
    
    % Normalize coordinates to [-1, 1] range using detector dimensions from Config
    min_coor = Config.Instrumental.Detector.Min_coordinate;
    max_coor = Config.Instrumental.Detector.Max_coordinate;
    lower_bound = Config.Utils.RescaleInputData.Target_min;
    upper_bound = Config.Utils.RescaleInputData.Target_max;
    
    Xcoor_ = transmissionFast.utils.rescaleInputData(X_coord, min_coor, max_coor, lower_bound, upper_bound);
    Ycoor_ = transmissionFast.utils.rescaleInputData(Y_coord, min_coor, max_coor, lower_bound, upper_bound);
    
    % Use Config.FieldCorrection for calculations
    % The Config already contains all the Chebyshev configuration we need
    
    % Get parameter values with defaults from FieldParams
    kx0 = getFieldValue(FieldParams, 'kx0', 0.0);
    ky0 = getFieldValue(FieldParams, 'ky0', 0.0);
    kx = getFieldValue(FieldParams, 'kx', 0.0);
    ky = getFieldValue(FieldParams, 'ky', 0.0);
    kx2 = getFieldValue(FieldParams, 'kx2', 0.0);
    ky2 = getFieldValue(FieldParams, 'ky2', 0.0);
    kx3 = getFieldValue(FieldParams, 'kx3', 0.0);
    ky3 = getFieldValue(FieldParams, 'ky3', 0.0);
    kx4 = getFieldValue(FieldParams, 'kx4', 0.0);
    ky4 = getFieldValue(FieldParams, 'ky4', 0.0);
    kxy = getFieldValue(FieldParams, 'kxy', 0.0);
    
    % Calculate Chebyshev polynomials directly using evaluateChebyshevPolynomial
    % X terms: T1(x), T2(x), T3(x), T4(x)
    Cheb_x_val = kx * transmissionFast.utils.evaluateChebyshevPolynomial(Xcoor_, 1) + ...
                 kx2 * transmissionFast.utils.evaluateChebyshevPolynomial(Xcoor_, 2) + ...
                 kx3 * transmissionFast.utils.evaluateChebyshevPolynomial(Xcoor_, 3) + ...
                 kx4 * transmissionFast.utils.evaluateChebyshevPolynomial(Xcoor_, 4);

    % Y terms: T1(y), T2(y), T3(y), T4(y)
    Cheb_y_val = ky * transmissionFast.utils.evaluateChebyshevPolynomial(Ycoor_, 1) + ...
                 ky2 * transmissionFast.utils.evaluateChebyshevPolynomial(Ycoor_, 2) + ...
                 ky3 * transmissionFast.utils.evaluateChebyshevPolynomial(Ycoor_, 3) + ...
                 ky4 * transmissionFast.utils.evaluateChebyshevPolynomial(Ycoor_, 4);

    % Cross-term: T1(x) * T1(y)
    Cheb_xy_x = transmissionFast.utils.evaluateChebyshevPolynomial(Xcoor_, 1);
    Cheb_xy_y = transmissionFast.utils.evaluateChebyshevPolynomial(Ycoor_, 1);
    
    % Calculate total field correction
    Field_corr = Cheb_x_val + Cheb_y_val + kx0 + ky0 + kxy * (Cheb_xy_x .* Cheb_xy_y);
end

function value = getFieldValue(structure, fieldname, defaultValue)
    % Safe field extraction with default value
    if isfield(structure, fieldname)
        value = structure.(fieldname);
    else
        value = defaultValue;
    end
end