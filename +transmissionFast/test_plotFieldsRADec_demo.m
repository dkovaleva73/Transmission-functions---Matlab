function test_plotFieldsRADec_demo()
    % Simple demonstration of the enhanced plotFieldsRADec function
    % Creates synthetic field data to test both scatter and contour plotting styles
    % and both RA/Dec and X/Y coordinate systems

    fprintf('=== Testing Enhanced transmissionFast.plotFieldsRADec ===\n');

    % Create synthetic data for 24 subimages
    catalogs = cell(24, 1);

    % Base parameters for synthetic data
    numStarsPerField = 50;
    baseRA = 180;  % degrees
    baseDec = 30;  % degrees
    fieldSize = 2;  % degrees
    subimageSize = 1756;  % pixels

    fprintf('Creating synthetic catalog data for 24 fields...\n');

    for fieldNum = 1:24
        % Calculate field position in 4x6 grid
        row = ceil(fieldNum / 6);  % 1-4 from bottom to top
        col = mod(fieldNum - 1, 6) + 1;  % 1-6 from left to right

        % Generate random star positions
        % RA/Dec coordinates
        fieldRA = baseRA + (col - 3.5) * fieldSize/6 + (rand(numStarsPerField, 1) - 0.5) * fieldSize/6;
        fieldDec = baseDec + (row - 2.5) * fieldSize/4 + (rand(numStarsPerField, 1) - 0.5) * fieldSize/4;

        % X/Y pixel coordinates (within each subimage)
        fieldX = rand(numStarsPerField, 1) * subimageSize;
        fieldY = rand(numStarsPerField, 1) * subimageSize;

        % Generate synthetic photometry with realistic DIFF_MAG pattern
        % Create a gradient pattern for DIFF_MAG to simulate systematic effects
        centerX = subimageSize / 2;
        centerY = subimageSize / 2;
        distances = sqrt((fieldX - centerX).^2 + (fieldY - centerY).^2);
        maxDistance = sqrt(2) * subimageSize / 2;

        % DIFF_MAG increases towards edges (typical for field effects)
        DIFF_MAG = 0.05 + 0.15 * (distances / maxDistance) + 0.02 * randn(numStarsPerField, 1);

        % Other magnitude columns
        MAG_ZP = 25.0 + 0.1 * randn(numStarsPerField, 1);
        MAG_PSF_AB = 16 + 2 * rand(numStarsPerField, 1);

        % Create catalog table
        catalogs{fieldNum} = table(fieldRA, fieldDec, fieldX, fieldY, ...
                                 DIFF_MAG, MAG_ZP, MAG_PSF_AB, ...
                                 'VariableNames', {'RA', 'Dec', 'X', 'Y', ...
                                 'DIFF_MAG', 'MAG_ZP', 'MAG_PSF_AB'});
    end

    fprintf('Generated catalogs with %d stars per field\n', numStarsPerField);

    % Test 1: Original scatter plot with RA/Dec coordinates
    fprintf('\n--- Test 1: Scatter plot with RA/Dec coordinates ---\n');
    try
        fig1 = transmissionFast.plotFieldsRADec(catalogs, ...
            'PlotStyle', 'scatter', ...
            'CoordinateSystem', 'radec', ...
            'ColorField', 'DIFF_MAG', ...
            'Title', 'Test 1: Scatter Plot (RA/Dec, DIFF_MAG)');
        fprintf('✓ Scatter plot with RA/Dec successful\n');
        pause(2);
    catch ME
        fprintf('✗ Scatter plot with RA/Dec failed: %s\n', ME.message);
    end

    % Test 2: New contour plot with RA/Dec coordinates
    fprintf('\n--- Test 2: Contour plot with RA/Dec coordinates ---\n');
    try
        fig2 = transmissionFast.plotFieldsRADec(catalogs, ...
            'PlotStyle', 'contour', ...
            'CoordinateSystem', 'radec', ...
            'ColorField', 'DIFF_MAG', ...
            'Title', 'Test 2: Contour Plot (RA/Dec, DIFF_MAG)');
        fprintf('✓ Contour plot with RA/Dec successful\n');
        pause(2);
    catch ME
        fprintf('✗ Contour plot with RA/Dec failed: %s\n', ME.message);
    end

    % Test 3: Scatter plot with X/Y coordinates (joint figure)
    fprintf('\n--- Test 3: Scatter plot with X/Y coordinates (joint figure) ---\n');
    try
        fig3 = transmissionFast.plotFieldsRADec(catalogs, ...
            'PlotStyle', 'scatter', ...
            'CoordinateSystem', 'xy', ...
            'ColorField', 'DIFF_MAG', ...
            'SubimageSize', subimageSize, ...
            'Title', 'Test 3: Scatter Plot (X/Y Joint Figure, DIFF_MAG)');
        fprintf('✓ Scatter plot with X/Y coordinates successful\n');
        pause(2);
    catch ME
        fprintf('✗ Scatter plot with X/Y coordinates failed: %s\n', ME.message);
    end

    % Test 4: Contour plot with X/Y coordinates (joint figure)
    fprintf('\n--- Test 4: Contour plot with X/Y coordinates (joint figure) ---\n');
    try
        fig4 = transmissionFast.plotFieldsRADec(catalogs, ...
            'PlotStyle', 'contour', ...
            'CoordinateSystem', 'xy', ...
            'ColorField', 'DIFF_MAG', ...
            'SubimageSize', subimageSize, ...
            'Title', 'Test 4: Contour Plot (X/Y Joint Figure, DIFF_MAG)');
        fprintf('✓ Contour plot with X/Y coordinates successful\n');
        pause(2);
    catch ME
        fprintf('✗ Contour plot with X/Y coordinates failed: %s\n', ME.message);
    end

    % Test 5: Different color field
    fprintf('\n--- Test 5: Contour plot with different color field ---\n');
    try
        fig5 = transmissionFast.plotFieldsRADec(catalogs, ...
            'PlotStyle', 'contour', ...
            'CoordinateSystem', 'xy', ...
            'ColorField', 'MAG_ZP', ...
            'SubimageSize', subimageSize, ...
            'Title', 'Test 5: Contour Plot (X/Y, MAG_ZP)');
        fprintf('✓ Contour plot with MAG_ZP successful\n');
        pause(2);
    catch ME
        fprintf('✗ Contour plot with MAG_ZP failed: %s\n', ME.message);
    end

    fprintf('\n=== Testing completed ===\n');
    fprintf('Enhanced plotFieldsRADec features demonstrated:\n');
    fprintf('  ✓ PlotStyle: "scatter" (original) and "contour" (new)\n');
    fprintf('  ✓ CoordinateSystem: "radec" (original) and "xy" (new with rescaling)\n');
    fprintf('  ✓ ColorField: works with DIFF_MAG and other magnitude fields\n');
    fprintf('  ✓ X/Y rescaling: creates joint figure from 24 subimages\n');
    fprintf('\nYou should see 5 figures demonstrating the new functionality!\n');

end