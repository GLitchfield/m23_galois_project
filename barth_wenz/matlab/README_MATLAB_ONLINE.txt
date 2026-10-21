M23 class-1 Barth--Wenz numerical bundle
=========================================

This bundle runs the authors' MATLAB Schwarz--Christoffel and welding stage
for the certified M23 target class 1. It is a numerical seed calculation, not
an exact Belyi-map certificate.

MATLAB Online
-------------

1. Sign in at https://matlab.mathworks.com/ with a MathWorks account.
2. Upload this zip file to MATLAB Drive and extract it.
3. Open the extracted bundle directory as the current MATLAB folder.
4. At the MATLAB prompt, run:

       run_class1

5. When it finishes, download:

       bundle_manifest.tsv
       matlab_summary.tsv
       matlab_transcript.txt
       m23_class1_dessin.mat
       zeros_dessin.csv
       ones_dessin.csv
       poles_dessin.csv

If MATLAB reports an error, download matlab_failure.txt and
matlab_transcript.txt instead. Do not rerun with changed tolerances before
recording the first result.

Desktop/headless MATLAB
-----------------------

From the parent of the extracted directory:

  matlab -batch "cd('BUNDLE_DIRECTORY'); run_class1"

Interpretation
--------------

"completed" only means that the conformal map and welding returned finite
numerical coordinates. Those coordinates must still pass the repository's
nondegeneracy gate, Newton refinement, exact recognition, ramification check,
and independent monodromy verification.
