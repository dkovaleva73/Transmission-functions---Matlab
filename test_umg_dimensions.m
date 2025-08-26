% Test UMG dimension handling specifically

Config = transmission.inputConfig('default');
Lam = transmission.utils.makeWavelengthArray(Config);

fprintf('Input Lam dimensions: %d × %d\n', size(Lam));
fprintf('Input Lam shape: ');
if size(Lam, 1) > size(Lam, 2)
    fprintf('column vector\n');
else
    fprintf('row vector\n');
end

% Test UMG directly
Trans_umg = transmission.atmospheric.umgTransmittance(Lam, Config);
fprintf('UMG output dimensions: %d × %d\n', size(Trans_umg));

% Check the condition in the fix
fprintf('\nDimension fix condition check:\n');
fprintf('size(Lam, 1) = %d\n', size(Lam, 1));
fprintf('size(Trans, 1) = %d\n', size(Trans_umg, 1));
fprintf('size(Lam, 1) > 1 = %s\n', string(size(Lam, 1) > 1));
fprintf('size(Trans, 1) == 1 = %s\n', string(size(Trans_umg, 1) == 1));

% The fix should be: if input is column, output should be column
if size(Lam, 1) > size(Lam, 2)
    fprintf('Input is column vector, output should also be column\n');
else
    fprintf('Input is row vector, output should also be row\n');
end