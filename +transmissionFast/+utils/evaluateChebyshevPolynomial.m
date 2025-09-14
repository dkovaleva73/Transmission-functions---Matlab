function T = evaluateChebyshevPolynomial(x, order)
    % Calculate single Chebyshev polynomial T_order(x) using recursive generation
    % Input:  - x (array): normalized coordinates in [-1, 1] range
    %         - order (scalar): polynomial order (0, 1, 2, 3, ...)
    % Output: - T (array): T_order(x) values, same size as x
    %
    % Uses recursive relation: T_n(x) = 2*x*T_{n-1}(x) - T_{n-2}(x)
    % Starting values: T_0(x) = 1, T_1(x) = x
    %
    % Author: D. Kovaleva (Sep 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50
    % Example:
    %   x = linspace(-1, 1, 100);
    %   T3 = transmissionFast.utils.evaluateChebyshevPolynomial(x, 3);  % T_3(x) = 4x^3 - 3x
    
    arguments
        x (:,:) double  % Input coordinates (any array size)
        order (1,1) double {mustBeNonnegative, mustBeInteger} % Polynomial order
    end
    
    % Handle special cases
    switch order
        case 0
            % T_0(x) = 1
            T = ones(size(x));
            return;
        case 1
            % T_1(x) = x
            T = x;
            return;
    end
    
    % For order >= 2, use recursive generation
    % Initialize with T_0 and T_1
    T_prev2 = ones(size(x));  % T_0(x) = 1
    T_prev1 = x;              % T_1(x) = x
    
    % Generate T_2, T_3, ..., T_order using recurrence relation
    for n = 2:order
        T_curr = 2 * x .* T_prev1 - T_prev2;  % T_n(x) = 2*x*T_{n-1}(x) - T_{n-2}(x)
        
        % Update for next iteration
        T_prev2 = T_prev1;
        T_prev1 = T_curr;
    end
    
    T = T_prev1;  % T_order(x)
end