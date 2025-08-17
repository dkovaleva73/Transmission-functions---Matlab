function [Spec, Mag, Coords, LASTData, Metadata] = findCalibratorsWithCoordsNew_fixed(CatFile, SearchRadius)
    % Find Gaia sources with low-resolution spectra around LAST source positions
    % Using imProc.match.match_catsHTM for efficient batch matching
    % Input :  - CatFile - Path to LAST catalog FITS file
    %          - SearchRadius - Search radius in arcsec (default: 1)
    % Output:  - Spec - Cell array {N x 2} with:
    %             - Column 1: Flux values (343 wavelength points)
    %             - Column 2: Flux error values (343 wavelength points)
    %             - Mag - Array of LAST PSF magnitudes for matched sources
    %             - Coords - Structure array with coordinate information:
    %                .Gaia_RA - Gaia DR3 RA (deg)
    %                .Gaia_Dec - Gaia DR3 Dec (deg)
    %                .LAST_RA - LAST catalog RA (deg)
    %                .LAST_Dec - LAST catalog Dec (deg)
    %                .LAST_X - LAST pixel X coordinate
    %                .LAST_Y - LAST pixel Y coordinate
    %                .LAST_idx - Original index in LAST catalog
    %          - LASTData - Array with LAST catalog data for matched sources
    %          - Metadata - Structure with LAST observation metadata:
    %                .airMassFromLAST - air mass (if available)
    %                .Temperature - Temperature in Celsius (if available)
    %                .Pressure - Atmospheric pressure in hPa (if available)
    %                .ExpTime - Exposure time in seconds
    %                .JD - Julian Date
    %                .CatalogFile - Name of LAST catalog file
    % Reference : Garrappa et al. 2025, A&A 699, A50.
    % Author: A. Krassilshchikov, D. Kovaleva
    % Date: Jul 2025
    % Example:  CatFile = '/path/to/LAST_catalog.fits';
    %           [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoordsNew_fixed(CatFile, 3);
   
    
    arguments
        CatFile = transmission.inputConfig().Data.LAST_catalog_file
        SearchRadius = transmission.inputConfig().Data.Search_radius_arcsec
    end
    
    tic
    RAD = constant.RAD;
    
    % Load LAST catalog
    AC = AstroCatalog(CatFile);
    %
    AC = cropXY(AC, [1000 1050 1000 1050]);
    %
    if contains(CatFile,"coadd") 
        % filter by MergedCatMask
        F = bitget(AC.Table.MergedCatMask,1) > 0; % test the 1st bit of the mask (corresponds to GAIA DR3 objects)
        Tab = AC.Table(F,:);
    else 
        Tab = AC.Table(:,:);   
    end

    % No filtering - use the original table as is
    fprintf('Using %d LAST sources without filtering\n', height(Tab));
    
    % match_catsHTM 
    [Result, SelObj, ResInd, CatH] = imProc.match.match_catsHTM(AC, 'GAIADR3spec', ...
        'Coo', [Tab.RA/RAD, Tab.Dec/RAD], 'CooUnits', 'rad', 'Radius', SearchRadius, ...
        'CatRadius',3,'RadiusUnits', 'arcsec');
    
    % CatH contains the Gaia catalog matches
    % Result contains the input catalog with added columns
    % SelObj contains only the matched LAST sources
    % ResInd contains the matching indices
    
    % Check if we have matches
    if isempty(CatH) || isempty(CatH.Table)
        % No matches found
        Spec = {};
        Mag = [];
        Coords = struct([]);
        LASTData = table();
        Metadata = struct();
        fprintf('No Gaia matches found\n');
        toc
        return;
    end
    
    % Get Gaia catalog data
    GaiaTab = CatH.Table;
    GaiaArray = table2array(GaiaTab);
    Nsrc_gaia = height(GaiaTab);
    
    % Get matched LAST sources
    if ~isempty(Result) && ~isempty(Result.Table)
        % Result.Table has ALL LAST sources with additional columns
        % The Nmatch column indicates how many Gaia matches each source has
        FullTab = Result.Table;
        
        % Find which LAST sources have matches (based on Nmatch column if added)
        if ismember('Nmatch', FullTab.Properties.VariableNames)
            hasMatch = FullTab.Nmatch > 0;
        else
            % If no Nmatch column, check SelObj for matched sources
            if ~isempty(SelObj) 
                % SelObj contains only matched sources
                hasMatch = false(height(FullTab), 1);
                % We need to identify which sources in FullTab are in SelObj
                % This is complex without proper indices
            else
                hasMatch = false(height(FullTab), 1);
            end
        end
        
        % Get indices of matched LAST sources
        matchedIndices = find(hasMatch);
        Nmatched = length(matchedIndices);
    else
        Nmatched = 0;
        matchedIndices = [];
        FullTab = table();
    end
    
    fprintf('Found %d LAST sources with Gaia matches (total %d Gaia sources)\n', Nmatched, Nsrc_gaia);
    
    % Initialize arrays based on number of matched LAST sources
    SrcSpec = cell(Nmatched, 2);
    MagPSF = zeros(Nmatched, 1);
    
    % Initialize coordinate arrays
    Gaia_RA = NaN(Nmatched, 1);
    Gaia_Dec = NaN(Nmatched, 1);
    LAST_RA = NaN(Nmatched, 1);
    LAST_Dec = NaN(Nmatched, 1);
    LAST_X = NaN(Nmatched, 1);
    LAST_Y = NaN(Nmatched, 1);
    LAST_idx = zeros(Nmatched, 1);
    
    % Process each matched LAST source
    for i = 1:Nmatched
        lastIdx = matchedIndices(i);
        
        % Find corresponding Gaia source
        % ResInd.Obj1_IndInObj2 should map LAST indices to Gaia indices
        if ~isempty(ResInd) && isfield(ResInd, 'Obj1_IndInObj2')
            gaiaIdx = ResInd.Obj1_IndInObj2(lastIdx);
            
            if gaiaIdx > 0 && gaiaIdx <= Nsrc_gaia
                % Extract spectra from Gaia
                SrcSpec{i,1} = GaiaArray(gaiaIdx, 7:349);    % F
                SrcSpec{i,2} = GaiaArray(gaiaIdx, 350:692);  % Ferr
                
                % Store Gaia coordinates (convert from radians to degrees)
                Gaia_RA(i) = GaiaArray(gaiaIdx, 1) * RAD;   % Column 1 is RA in radians
                Gaia_Dec(i) = GaiaArray(gaiaIdx, 2) * RAD;  % Column 2 is Dec in radians
            end
        end
        
        % Store LAST source information
        MagPSF(i) = FullTab.MAG_PSF(lastIdx);
        LAST_RA(i) = FullTab.RA(lastIdx);
        LAST_Dec(i) = FullTab.Dec(lastIdx);
        LAST_X(i) = FullTab.X(lastIdx);
        LAST_Y(i) = FullTab.Y(lastIdx);
        LAST_idx(i) = lastIdx;
    end
    
    % Filter out any invalid entries
    validMask = MagPSF > 0 & ~isnan(Gaia_RA);
    
    % Extract valid entries
    Spec = SrcSpec(validMask, :);
    Mag = MagPSF(validMask);
    
    % Extract LAST catalog data for valid entries
    validIndices = matchedIndices(validMask);
    if ~isempty(validIndices)
        LASTData = FullTab(validIndices, :);
    else
        LASTData = table();
    end
    
    % Create coordinate structure for valid entries
    valid_Gaia_RA = Gaia_RA(validMask);
    valid_Gaia_Dec = Gaia_Dec(validMask);
    valid_LAST_RA = LAST_RA(validMask);
    valid_LAST_Dec = LAST_Dec(validMask);
    valid_LAST_X = LAST_X(validMask);
    valid_LAST_Y = LAST_Y(validMask);
    valid_LAST_idx = LAST_idx(validMask);
    
    Coords = struct();
    numValid = sum(validMask);
    
    for i = 1:numValid
        Coords(i).Gaia_RA = valid_Gaia_RA(i);
        Coords(i).Gaia_Dec = valid_Gaia_Dec(i);
        Coords(i).LAST_RA = valid_LAST_RA(i);
        Coords(i).LAST_Dec = valid_LAST_Dec(i);
        Coords(i).LAST_X = valid_LAST_X(i);
        Coords(i).LAST_Y = valid_LAST_Y(i);
        Coords(i).LAST_idx = valid_LAST_idx(i);
    end
    
    % Display summary
    fprintf('Final: %d valid LAST-Gaia matches\n', numValid);
    fprintf('Search radius: %.1f arcsec\n', SearchRadius);
    
    % Extract metadata from LAST catalog header using AstroHeader
    try
        Header = AstroHeader(CatFile, 3);
    catch
        Header = [];
    end
    
    Metadata = struct();
    
    % Extract exposure time and JD (always available)
    if ~isempty(Header)
        try
            Metadata.ExpTime = Header.getVal('EXPTIME');
        catch
            Metadata.ExpTime = NaN;
        end
        
        try
            Metadata.JD = Header.getVal('JD');
        catch
            Metadata.JD = NaN;
        end
        
        % Extract airmass from LAST 
        try
            Metadata.airMassFromLAST = Header.getVal('AIRMASS');
        catch
            Metadata.airMassFromLAST = NaN;
        end
        
        % Extract temperature from MNTTEMP field only
        try
            Metadata.Temperature = Header.getVal('MNTTEMP');
        catch
            Metadata.Temperature = NaN;
        end
        
        % Extract pressure (if available)
        try
            Metadata.Pressure = Header.getVal('PRESSURE');
        catch
            try
                Metadata.Pressure = Header.getVal('PRESS');
            catch
                Metadata.Pressure = NaN;
            end
        end
        
        % Add field center coordinates
        try
            Metadata.FieldRA = Header.getVal('RA');
        catch
            Metadata.FieldRA = NaN;
        end
        
        try
            Metadata.FieldDec = Header.getVal('DEC');
        catch
            Metadata.FieldDec = NaN;
        end
    else
        % Header failed to load - set all to NaN
        Metadata.ExpTime = NaN;
        Metadata.JD = NaN;
        Metadata.airMassFromLAST = NaN;
        Metadata.Temperature = NaN;
        Metadata.Pressure = NaN;
        Metadata.FieldRA = NaN;
        Metadata.FieldDec = NaN;
    end
    
    % Add catalog filename to metadata
    [~, filename, ext] = fileparts(CatFile);
    Metadata.CatalogFile = [filename ext];
    
    fprintf('\nMetadata extracted: AirMass=%.3f, Temp=%.1f°C, ExpTime=%.1fs\n', ...
            Metadata.airMassFromLAST, Metadata.Temperature, Metadata.ExpTime);
    toc
end