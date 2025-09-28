function T = chebyshevPolynomial(X, Order)
    % Calculate single Chebyshev polynomial T_order(x) using recursive
    % generation:  T_n(x) = 2*x*T_{n-1}(x) - T_{n-2}(x)
    % Starting values: T_0(x) = 1, T_1(x) = x
    % Input :  - X (array): normalized coordinates in [-1, 1] range
    %          - Order (scalar): polynomial order (0, 1, 2, 3, ...)
    % Output:  - T (array): T_Order(X) values, same size as X
    % Author:  D. Kovaleva (Sep 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50
    % Example:   x = linspace(-1, 1, 100);
    %            T3 = astro.atmosphere.chebyshevPolynomial(x, 3);  % T_3(x) = 4x^3 - 3x
    
    arguments
        X (:,:) double  % Input coordinates (any array size)
        Order double {mustBeNonnegative, mustBeInteger} % Polynomial order
    end
    
    % Handle special cases
    switch Order
        case 0
            T = repmat(1, size(X)); %#ok<*RPMT1>
            return;
        case 1
            T = X;
            return;
    end
    
    % For order >= 2, use recursive generation
    % Initialize with T_0 and T_1
    T_prev2 = repmat(1, size(X));  % T_0(x) = 1
    T_prev1 = X;                   % T_1(x) = x
    
    % Generate T_2, T_3, ..., T_order using recurrence relation
    for n = 2:Order
        T_curr = 2 * X .* T_prev1 - T_prev2;  % T_n(x) = 2*x*T_{n-1}(x) - T_{n-2}(x)
        
        % Update for next iteration
        T_prev2 = T_prev1;
        T_prev1 = T_curr;
    end
    
    T = T_prev1;  % T_order(x)
end