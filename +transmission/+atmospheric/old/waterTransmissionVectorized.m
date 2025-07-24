function transmission = waterTransmissionVectorized(Z_, Pw_, Pressure, Lam, varargin)
    % Memory-optimized scalar water transmission calculation
    % Optimized for repeated calls with varying water vapor (Pw_) in atmospheric fitting
    %
    % Parameters:
    %   Z_ (scalar): Zenith angle in degrees
    %   Pw_ (scalar): Precipitable water in cm  
    %   Pressure (scalar): Pressure in mbar
    %   Lam (array): Wavelength array in nm [M x 1] or [1 x M]
    %   
    % Optional Parameters:
    %   'AbsData' - Pre-loaded absorption data structure
    %   'InterpolationMethod' - 'linear' (default) or 'cubic'
    %
    % Returns:
    %   transmission (array): [M x 1] transmission values for each wavelength
    %                        Optimized for atmospheric fitting pipelines
    
    % Parse input arguments
    p = inputParser;
    addParameter(p, 'AbsData', [], @isstruct);
    addParameter(p, 'InterpolationMethod', 'linear', @ischar);
    parse(p, varargin{:});
    
    abs_data = p.Results.AbsData;
    interp_method = p.Results.InterpolationMethod;
    
    % Load absorption data if not provided
    if isempty(abs_data)
        abs_data = transmission.data.loadAbsorptionDataVectorized([], {'H2O'}, false);
    end
    
    % Input validation
    if ~isscalar(Z_) || ~isscalar(Pw_) || ~isscalar(Pressure)
        error('Z_, Pw_, and Pressure must be scalar values');
    end
    
    % Ensure wavelength array is column vector
    Lam = Lam(:);                  % [M x 1]
    
    % Extract H2O data (optimized structure)
    h2o = abs_data.H2O;
    
    % SCALAR CALCULATION: Direct processing optimized for atmospheric fitting
    
    % Direct airmass calculation
    cosz = cos(deg2rad(Z_));
    am_ = 1.0 / (cosz + 0.10648 * (Z_^0.11423) * (93.781 - Z_)^(-1.9203));
    
    % Calculate transmission (vectorized over wavelengths)
    transmission = calculateSingleSource(h2o, Z_, Pw_, Pressure, am_, Lam, interp_method);
end

function trans_row = calculateSingleSource(h2o, Z_, Pw_, Pressure, am_, Lam, interp_method)
    % Calculate transmission for a single source (vectorized over wavelengths)
    % This function contains the core SMARTS 2.9.5 logic
        
        % VECTORIZED BW CORRECTION (operates on all wavelengths simultaneously)
        pww0 = Pw_ - h2o.pw0_lookup;                                       % [L x 1] vectorized
        bw = 1.0 + h2o.Bw_coeffs(:,1) .* pww0 + h2o.Bw_coeffs(:,2) .* (pww0.^2); % [L x 1]
        
        % Apply BW fitting functions (vectorized with logical indexing)
        mask1 = (h2o.ifitw == 1);
        if any(mask1)
            bw(mask1) = bw(mask1) ./ (1.0 + h2o.Bw_coeffs(mask1,3) .* pww0(mask1));
        end
        
        mask2 = (h2o.ifitw == 2);
        if any(mask2)
            bw(mask2) = bw(mask2) ./ (1.0 + h2o.Bw_coeffs(mask2,3) .* (pww0(mask2).^2));
        end
        
        mask6 = (h2o.ifitw == 6);
        if any(mask6)
            bw(mask6) = h2o.Bw_coeffs(mask6,1) + h2o.Bw_coeffs(mask6,2) .* pww0(mask6);
        end
        
        % Apply constraints (vectorized)
        bw(h2o.absorption <= 0) = 1.0;
        bw = max(0.05, min(7.0, bw));                                      % Vectorized clipping
        
        % VECTORIZED BM CORRECTION
        am1 = am_ - 1.0;
        am12 = am1^2;
        bm = ones(size(h2o.ifitm));                                        % [L x 1]
        
        % Apply BM fitting functions (vectorized)
        mask0 = (h2o.ifitm == 0);
        if any(mask0)
            bm(mask0) = h2o.Bm_coeffs(mask0,2) .* (am_.^h2o.Bm_coeffs(mask0,3));
        end
        
        % BM fitting type 1 (vectorized)
        mask1 = (h2o.ifitm == 1);
        if any(mask1)
            bmx = (1.0 + h2o.Bm_coeffs(mask1,1)*am1 + h2o.Bm_coeffs(mask1,2)*am12) ./ ...
                  (1.0 + h2o.Bm_coeffs(mask1,3)*am1);
            bm(mask1) = bmx;
        end
        
        % BM fitting type 2 (vectorized)  
        mask2 = (h2o.ifitm == 2);
        if any(mask2)
            bmx = (1.0 + h2o.Bm_coeffs(mask2,1)*am1 + h2o.Bm_coeffs(mask2,2)*am12) ./ ...
                  (1.0 + h2o.Bm_coeffs(mask2,3)*am12);
            bm(mask2) = bmx;
        end
        
        % BM fitting type 3 (vectorized)
        mask3 = (h2o.ifitm == 3);
        if any(mask3)
            bmx = (1.0 + h2o.Bm_coeffs(mask3,1)*am1 + h2o.Bm_coeffs(mask3,2)*am12) ./ ...
                  (1.0 + h2o.Bm_coeffs(mask3,3)*sqrt(am1));
            bm(mask3) = bmx;
        end
        
        % BM fitting type 5 (vectorized)
        mask5 = (h2o.ifitm == 5);
        if any(mask5)
            bmx = (1.0 + h2o.Bm_coeffs(mask5,1)*(am1^0.25)) ./ ...
                  (1.0 + h2o.Bm_coeffs(mask5,3)*(am1^0.1));
            bm(mask5) = bmx;
        end
        
        % Apply BM constraints (vectorized)
        bm(h2o.absorption <= 0) = 1.0;
        bm = max(0.05, min(7.0, bm));
        
        % BMW CORRECTION (complete SMARTS implementation, vectorized)
        bmw = bm .* bw;                                                    % [L x 1] basic multiplication
        
        % Define conditions where simple multiplication applies (vectorized)
        cond1 = abs(bw - 1) < 1e-6;
        cond2 = ((h2o.ifitm ~= 0) | (h2o.absorption <= 0)) & (abs(bm - 1) < 1e-6);
        cond3 = ((h2o.ifitm == 0) | (h2o.absorption <= 0)) & (bm > 0.968) & (bm < 1.0441);
        cond4 = (h2o.ifitmw == -1) | (h2o.absorption <= 0);
        combined_cond = cond1 | cond2 | cond3 | cond4;
        
        % For complex cases, use advanced fitting
        complex_mask = ~combined_cond;
        if any(complex_mask)
            % Reference water values by band (use precomputed lookup)
            amw = am_ * (Pw_ ./ h2o.pw0_lookup);
            amw1 = amw - 1;
            amw12 = amw1.^2;
            
            bmwx = ones(size(bmw));
            
            % Ifitmw = 0 fitting
            mask0 = (h2o.ifitmw == 0) & (h2o.absorption > 0);
            if any(mask0)
                bmwx(mask0) = h2o.Bmw_coeffs(mask0,2) .* (amw(mask0).^h2o.Bmw_coeffs(mask0,3));
            end
            
            % Ifitmw = 1 fitting
            mask1 = (h2o.ifitmw == 1) & (h2o.absorption > 0);
            if any(mask1)
                bmwx(mask1) = (1.0 + h2o.Bmw_coeffs(mask1,1).*amw1(mask1) + h2o.Bmw_coeffs(mask1,2).*amw12(mask1)) ./ ...
                              (1.0 + h2o.Bmw_coeffs(mask1,3).*amw1(mask1));
            end
            
            % Ifitmw = 2 fitting
            mask2 = (h2o.ifitmw == 2) & (h2o.absorption > 0);
            if any(mask2)
                bmwx(mask2) = (1.0 + h2o.Bmw_coeffs(mask2,1).*amw1(mask2) + h2o.Bmw_coeffs(mask2,2).*amw12(mask2)) ./ ...
                              (1.0 + h2o.Bmw_coeffs(mask2,3).*amw12(mask2));
            end
            
            % Apply advanced fitting where conditions are not met
            bmw(complex_mask) = bmwx(complex_mask);
        end
        
        % Clip to valid range
        bmw = max(0.05, min(7.0, bmw));
        
        % VECTORIZED BP CORRECTION (complete SMARTS implementation)
        pwm = Pw_ * am_;
        pp0 = Pressure / 1013.25;
        pp01 = max(0.65, pp0);
        pp02 = pp01^2;
        qp = 1.0 - pp0;
        qp1 = min(0.35, qp);
        qp2 = qp1^2;
        
        % Default BP values (vectorized)
        bp = (1.0 + 0.1623 * qp) * ones(size(h2o.band));                  % [L x 1]
        
        % Band-specific BP corrections (vectorized)
        mask2_bp = (h2o.band == 2) & (h2o.absorption > 0);
        if any(mask2_bp)
            bp(mask2_bp) = 1.0 + 0.08721 * qp1;
        end
        
        mask3_bp = (h2o.band == 3) & (h2o.absorption > 0);
        if any(mask3_bp)
            A = 1.0 - h2o.Bp_coeffs(mask3_bp,1) * qp1 - h2o.Bp_coeffs(mask3_bp,2) * qp2;
            bp(mask3_bp) = A;
        end
        
        mask4_bp = (h2o.band == 4) & (h2o.absorption > 0);
        if any(mask4_bp)
            A4 = 1.0 - h2o.Bp_coeffs(mask4_bp,1) * qp1 - h2o.Bp_coeffs(mask4_bp,2) * qp2;
            B4 = 1.0 - pwm * exp(-0.63486 + 6.9149*pp01 - 13.853*pp02);
            bp(mask4_bp) = A4 .* B4;
        end
        
        mask5_bp = (h2o.band == 5) & (h2o.absorption > 0);
        if any(mask5_bp)
            A5 = 1.0 - h2o.Bp_coeffs(mask5_bp,1) * qp1 - h2o.Bp_coeffs(mask5_bp,2) * qp2;
            B5 = 1.0 - pwm * exp(8.9243 - 18.197*pp01 + 2.4141*pp02);
            bp(mask5_bp) = A5 .* B5;
        end
        
        % BP constraints (vectorized)
        bp((abs(qp) < 1e-5) | (h2o.absorption <= 0)) = 1.0;
        bp = max(0.3, min(1.7, bp));
        
        % FINAL OPTICAL DEPTH CALCULATION (vectorized)
        pwm_final = (Pw_ * am_).^0.9426;
        tauw_l = bmw .* bp .* h2o.absorption .* pwm_final;                 % [L x 1] vectorized
        
        % OPTIMIZED INTERPOLATION: Single call for current source
        tauw_interp = interp1(h2o.wavelength, tauw_l, Lam, interp_method, 0.0);
        
        % FINAL TRANSMISSION CALCULATION
        trans_row = exp(-tauw_interp);                                     % [M x 1] vectorized
        trans_row = max(0.0, min(1.0, trans_row));                        % [M x 1] vectorized clipping
end