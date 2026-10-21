function run_class1()
% Run the pinned Barth--Wenz class-1 numerical handoff without visible plots.

set(0, 'DefaultFigureVisible', 'off');
addpath(genpath(fullfile(pwd, 'sc-toolbox-3.1.3')));
diary('matlab_transcript.txt');

try
    run('Step2_DrawDessin.m');

    map_accuracy = accuracy(sc_map);
    finite_output = all(isfinite(real(zeros_dessin(:)))) ...
        && all(isfinite(imag(zeros_dessin(:)))) ...
        && all(isfinite(real(ones_dessin(:)))) ...
        && all(isfinite(imag(ones_dessin(:)))) ...
        && all(isfinite(real(poles_dessin(:)))) ...
        && all(isfinite(imag(poles_dessin(:))));

    save('m23_class1_dessin.mat', ...
        'zeros_dessin', 'ones_dessin', 'poles_dessin', ...
        'permx', 'permy', 'permz', ...
        'map_accuracy', 'finite_output', '-v7');
    writematrix( ...
        [real(zeros_dessin(:)), imag(zeros_dessin(:))], ...
        'zeros_dessin.csv');
    writematrix( ...
        [real(ones_dessin(:)), imag(ones_dessin(:))], ...
        'ones_dessin.csv');
    writematrix( ...
        [real(poles_dessin(:)), imag(poles_dessin(:))], ...
        'poles_dessin.csv');

    summary = fopen('matlab_summary.tsv', 'w');
    fprintf(summary, 'key\tvalue\n');
    fprintf(summary, 'status\tcompleted\n');
    fprintf(summary, 'degree\t%d\n', degree);
    fprintf(summary, 'domain_index\t%d\n', index);
    fprintf(summary, 'sc_map_accuracy\t%.17g\n', map_accuracy);
    fprintf(summary, 'finite_output\t%d\n', finite_output);
    fprintf(summary, 'zero_count\t%d\n', numel(zeros_dessin));
    fprintf(summary, 'one_count\t%d\n', numel(ones_dessin));
    fprintf(summary, 'pole_count\t%d\n', numel(poles_dessin));
    fclose(summary);
    fprintf('M23_BARTH_WENZ_STAGE=completed\n');
catch ME
    failure = fopen('matlab_failure.txt', 'w');
    fprintf(failure, '%s\n', getReport(ME, 'extended'));
    fclose(failure);
    fprintf('M23_BARTH_WENZ_STAGE=failed\n');
    diary off;
    rethrow(ME);
end

diary off;
end
