.PHONY: check test test-replay test-long dashboard reproduce-notes reference-data reproduce-14a-orbit reproduce-15a-orbit reproduce-8a-small-orbits reproduce-8a-related-start reproduce-4a-orbit reproduce-seguin-3a-components reproduce-seguin-3a-total reproduce-koenig-orbit reproduce-koenig-c2-bridge reproduce-koenig-f19-newton reproduce-koenig-f19-a reproduce-koenig-f19-family reproduce-koenig-f19-global reproduce-koenig-f19-passport reproduce-koenig-f19-monodromy reproduce-koenig-19adic reproduce-koenig-19adic-family reproduce-koenig-19adic-highorder reproduce-8a-conditioning-census check-lean check-native-kernel check-native-sqlite-ledger check-native-sqlite-queued-writer check-native-replay-ledger check-native-5a-census check-native-5a-walk check-cuda-batch check-5a-generation-masks check-m24-genus11-model check-m24-genus11-boundary check-m24-genus11-unit-charts check-m24-genus11-local-elimination check-m24-genus11-minus2-shards check-m24-genus11-minus2-clusters check-m24-genus11-tropical-exhaustion check-8a-continuation check-8a-conditioning-census check-8a-seed-transfer check-8a-related-start check-8a-exact-algebra check-8a-exact-recognition check-8a-coefficient-field check-8a-reciprocal-descent check-8a-absolute-orbit check-8a-fixed-field-galois check-8a-interval-monodromy check-8a-barth-wenz check-belyi-carnoldi check-magma-8a-pilot check-sharded-engine check-5a-bridge check-5a-homogeneous check-6a-bridge check-8a-bridge check-seguin-3a-components check-seguin-3a-total check-koenig-orbit check-koenig-c2-bridge check-koenig-artifacts check-koenig-modular-genus check-koenig-component-map check-koenig-f19-anchor check-koenig-f19-deformation check-koenig-f19-newton check-koenig-f19-a check-koenig-f19-a-long check-koenig-f19-family check-koenig-f19-family-long check-koenig-f19-global check-koenig-f19-global-long check-koenig-f19-passport check-koenig-f19-monodromy check-koenig-19adic check-koenig-19adic-family check-koenig-19adic-highorder check-koenig-relation-lift-gates check-koenig-relation-lift-pilot check-koenig-relation-ambient-digit2 check-koenig-relation-ambient-digits4 check-koenig-relation-degree110-digit4 check-koenig-relation-homogeneous-degree110 check-koenig-relation-homogeneous-degree110-digits5 check-koenig-relation-homogeneous-degree110-digits6 check-koenig-relation-homogeneous-degree110-digits7 check-koenig-relation-homogeneous-degree110-digits8 check-koenig-relation-homogeneous-degree110-digits9 check-koenig-relation-homogeneous-degree110-digits10 check-koenig-relation-homogeneous-degree110-digits13 check-koenig-relation-subspace-reconstruction check-koenig-relation-subspace-reconstruction-digits8 check-koenig-relation-subspace-reconstruction-digits9 check-koenig-relation-subspace-reconstruction-digits10 check-koenig-relation-subspace-lattice check-koenig-relation-subspace-lattice-digits10 check-koenig-relation-subspace-annihilator check-koenig-relation-numerator-filtration check-koenig-relation-supported-subspace check-koenig-relation-supported-quotient check-koenig-relation-supported-invariants check-koenig-relation-supported-invariant-stages check-koenig-relation-supported-invariant-stages-digits13 check-koenig-relation-supported-free-quotient check-koenig-relation-supported-free-quotient-digits10 check-koenig-relation-supported-free-lattice check-koenig-relation-supported-hard-lattice check-koenig-second-prime-feasibility check-koenig-f19-positive-control sharded-4a

check:
	@./scripts/check-environment.sh

test: check
	@python3 scripts/wayfinder_status.py >/dev/null
	@./scripts/check-lean.sh
	@python3 scripts/test_run_monitor.py
	@python3 scripts/test_quotient_ledger.py
	@python3 scripts/test_quotient_snapshot.py
	@python3 scripts/test_quotient_shards.py
	@python3 scripts/test_summarize_quotient_shards.py
	@python3 scripts/test_parallel_quotient_verification.py
	@python3 scripts/test_freeze_quotient_candidate.py
	@python3 scripts/test_import_native_ledger_batch.py
	@python3 scripts/test_partition_native_replay.py
	@python3 scripts/test_native_sqlite_monitor_snapshot.py
	@python3 scripts/test_summarize_native_mixed_wave.py
	@python3 scripts/test_native_full_cursor_plan.py
	@python3 scripts/test_independent_native_gap_audit.py
	@python3 scripts/test_verify_belyi_candidate.py
	@python3 scripts/test_extract_magma_belyi_candidate.py
	@python3 scripts/test_check_magma_8a_serialization_smoke.py
	@python3 scripts/test_census_8a_belyi_conditioning.py
	@python3 scripts/test_select_8a_belyi_seed.py
	@python3 scripts/test_analyze_8a_infinity_endpoints.py
	@python3 scripts/check_8a_exact_algebra_benchmark.py
	@python3 scripts/test_barth_wenz_preprocess.py
	@python3 scripts/test_prepare_barth_wenz_matlab.py
	@python3 scripts/check_barth_wenz_matlab_bundles.py
	@python3 scripts/check_barth_wenz_matlab_result.py
	@python3 scripts/check_barth_wenz_matlab_result.py data/derived/m23_8a_barth_wenz_class1_domain2_dessin.tsv
	@python3 scripts/test_prepare_barth_wenz_root_seed.py
	@python3 scripts/test_refine_barth_wenz_root_seed.py
	@python3 scripts/check_barth_wenz_refinement.py
	@python3 scripts/check_barth_wenz_candidate.py data/derived/m23_8a_barth_wenz_domain2_certified_endpoint-path1.tsv
	@python3 scripts/check_8a_high_precision_coefficients.py
	@python3 scripts/check_8a_cover_monodromy.py data/derived/m23_8a_belyi_class1_cover_monodromy.tsv
	@python3 scripts/check_8a_exact_recognition.py
	@./scripts/run-8a-sage.sh --python scripts/verify_belyi_candidate_sage.sage data/derived/m23_8a_belyi_class1_exact_candidate.json >/dev/null
	@./scripts/run-8a-sage.sh --python scripts/analyze_8a_coefficient_field.sage data/derived/m23_8a_belyi_class1_exact_candidate.json >/dev/null
	@python3 scripts/check_8a_coefficient_field.py data/derived/m23_8a_belyi_class1_coefficient_field.tsv
	@./scripts/run-8a-sage.sh --python scripts/analyze_8a_reciprocal_descent.sage data/derived/m23_8a_belyi_class1_exact_candidate.json data/derived/m23_8a_belyi_class1_interval_monodromy.tsv >/dev/null
	@python3 scripts/check_8a_reciprocal_descent.py data/derived/m23_8a_belyi_class1_reciprocal_descent.tsv data/derived/m23_8a_class1_degree14_descended_cover.json
	@./scripts/run-8a-sage.sh --python scripts/verify_8a_descended_cover.sage data/derived/m23_8a_class1_degree14_descended_cover.json >/dev/null
	@./scripts/run-8a-sage.sh --python scripts/analyze_8a_absolute_orbit.sage data/derived/m23_8a_belyi_class1_exact_candidate.json data/derived/m23_8a_class1_degree14_descended_cover.json data/derived/m23_8a_8a_2a_inner_classes.tsv >/dev/null
	@./scripts/run-8a-sage.sh --python scripts/check_8a_absolute_orbit.sage data/derived/m23_8a_belyi_absolute_orbit.tsv >/dev/null
	@./scripts/check-8a-fixed-field-galois.sh >/dev/null
	@./scripts/run-8a-sage.sh --python scripts/certify_8a_interval_monodromy.sage data/derived/m23_8a_belyi_class1_exact_candidate.json data/derived/m23_8a_belyi_class1_number_field_recovery.tsv data/derived/m23_8a_belyi_class1_high_precision_coefficients_16384.tsv --precision-bits 512 --steps-per-loop 8192 --probe-only >/dev/null
	@python3 scripts/check_8a_interval_monodromy.py data/derived/m23_8a_belyi_class1_interval_monodromy.tsv
	@bash -n scripts/setup-barth-wenz-octave.sh
	@bash -n scripts/check-barth-wenz-octave-incompatibility.sh
	@python3 scripts/check_8a_belyi_conditioning_census.py data/derived/m23_8a_belyi_conditioning_census.tsv data/derived/m23_8a_belyi_conditioning_seeds.tsv
	@python3 scripts/check_8a_belyi_seed_transfer.py
	@bash -n scripts/check-belyi-carnoldi.sh
	@python3 scripts/check_magma_8a_serialization_smoke.py notes/magma_8a_serialization_smoke.txt >/dev/null
	@python3 scripts/test_magma_8a_pilot.py
	@python3 scripts/test_m23_adversarial_review.py
	@python3 scripts/test_verify_koenig_m23_artifacts.py
	@python3 scripts/check_koenig_f19_global_certificate.py
	@python3 scripts/check_koenig_f19_passport_point.py
	@python3 scripts/check_koenig_19adic_anchor.py
	@python3 scripts/check_koenig_19adic_family.py
	@python3 scripts/check_koenig_19adic_highorder.py
	@python3 scripts/check_koenig_relation_lift_gates.py
	@python3 scripts/check_koenig_relation_lift_pilot.py
	@python3 scripts/check_koenig_relation_ambient_digit2.py
	@python3 scripts/check_koenig_relation_ambient_digits4.py
	@python3 scripts/check_koenig_relation_degree110_digit4.py
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --self-test
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_subspace_lattice.sage --self-test
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_subspace_annihilator.sage --self-test
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_relation_numerator_filtration.sage --self-test
	@python3 scripts/check_koenig_relation_numerator_filtration.py --self-test
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_relation_supported_subspace.sage --self-test
	@python3 scripts/check_koenig_relation_supported_subspace.py --self-test
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_supported_quotient.sage --self-test
	@python3 scripts/check_koenig_relation_supported_quotient.py --self-test
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_relation_supported_invariants.sage --self-test
	@python3 scripts/check_koenig_relation_supported_invariants.py --self-test
	@python3 scripts/check_koenig_relation_supported_invariant_stages.py --self-test
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_supported_free_quotient.sage --self-test
	@python3 scripts/check_koenig_relation_supported_free_quotient.py --self-test
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_supported_free_lattice.sage --self-test
	@python3 scripts/check_koenig_relation_supported_free_lattice.py
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_supported_hard_lattice.sage --self-test
	@python3 scripts/check_koenig_relation_supported_hard_lattice.py
	@./scripts/run-8a-sage.sh --python scripts/export_koenig_second_prime_msolve.sage --self-test
	@./scripts/run-8a-sage.sh --python scripts/export_koenig_f19_positive_control_msolve.sage --self-test
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_f19_positive_control.sage --self-test
	@python3 scripts/check_koenig_f19_positive_control.py
	@python3 scripts/check_koenig_second_prime_feasibility.py
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits5.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits5_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod2476099.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits6.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits6_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod47045881.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits7.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits7_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod893871739.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits8.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits8_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod16983563041.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits9.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits9_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod322687697779.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod6131066257801.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod42052983462257059.tsv
	@python3 scripts/check_koenig_relation_supported_subspace.py --summary data/derived/m23_koenig_a_relation_supported_beta77_digits13.tsv --representatives data/derived/m23_koenig_a_relation_supported_beta77_digits13_representatives.npz --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13_reduced.npz
	@python3 scripts/check_koenig_relation_supported_invariant_stages.py --summary data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to13.tsv --archive data/derived/m23_koenig_a_relation_supported_beta77_numerator_stage_images_digits4to13.npz --support-summary data/derived/m23_koenig_a_relation_supported_beta77_digits13.tsv --support-representatives data/derived/m23_koenig_a_relation_supported_beta77_digits13_representatives.npz --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13_reduced.npz
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_supported_free_quotient.sage --stage-summary data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to13.tsv --stage-archive data/derived/m23_koenig_a_relation_supported_beta77_numerator_stage_images_digits4to13.npz --check-summary data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_digits10.tsv
	@python3 scripts/check_koenig_relation_supported_free_quotient.py --summary data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_digits10.tsv --chart data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_chart_digits10.npz --stage-summary data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to13.tsv --stage-archive data/derived/m23_koenig_a_relation_supported_beta77_numerator_stage_images_digits4to13.npz
	@python3 scripts/check_koenig_relation_subspace_reconstruction.py
	@python3 scripts/check_koenig_relation_subspace_reconstruction.py --summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits8.tsv
	@python3 scripts/check_koenig_relation_subspace_reconstruction.py --summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits9.tsv
	@python3 scripts/check_koenig_relation_subspace_reconstruction.py --summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits10.tsv
	@python3 scripts/check_koenig_relation_subspace_lattice.py
	@python3 scripts/check_koenig_relation_subspace_lattice.py --summary data/derived/m23_koenig_a_relation_subspace_lattice_pilot_digits10.tsv
	@python3 scripts/check_koenig_relation_subspace_annihilator.py
	@./scripts/reproduce-koenig-c2-bridge.sh check
	@./scripts/reproduce-koenig-f19-monodromy-gate.sh check
	@python3 scripts/test_hybrid_benchmark.py
	@python3 scripts/test_summarize_native_stratified_ledger.py
	@python3 scripts/test_seed_native_stratified_frontier.py
	@python3 scripts/test_compare_native_ledgers.py
	@python3 scripts/test_summarize_quotient_profile.py
	@python3 scripts/test_summarize_direct_pair_refinements.py
	@python3 scripts/test_sample_process_trees.py
	@./scripts/test_quotient_worker_resources.sh
	@./scripts/check-native-kernel.sh
	@./scripts/check-native-sqlite-ledger.sh
	@./scripts/check-native-sqlite-queued-writer.sh
	@./scripts/check-native-replay-ledger.sh
	@./scripts/check-5a-generation-masks.sh
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_model.sage --self-test
	@python3 scripts/check_m24_genus11_model.py
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_boundary.sage --self-test
	@python3 scripts/check_m24_genus11_boundary.py
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_unit_charts.sage --self-test
	@python3 scripts/check_m24_genus11_unit_charts.py
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_local_elimination.sage --self-test
	@python3 scripts/check_m24_genus11_local_elimination.py
	@./scripts/run-8a-sage.sh --python scripts/run_m24_genus11_minus2_shards.sage --self-test
	@python3 scripts/check_m24_genus11_minus2_shards.py
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_minus2_clusters.sage --self-test
	@python3 scripts/check_m24_genus11_minus2_clusters.py
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_tropical_exhaustion.sage --self-test
	@python3 scripts/check_m24_genus11_tropical_exhaustion.py
	@./scripts/reproduce-notes.sh --check
	@./scripts/check-data-manifests.sh
	@python3 scripts/verify_reference_data.py
	@python3 scripts/verify_homogeneous_pair_block_census.py
	@python3 scripts/verify_14a_orbit.py
	@python3 scripts/verify_15a_orbit.py
	@python3 scripts/verify_8a_small_orbits.py
	@./scripts/check-8a-related-start.sh
	@./scripts/check-8a-belyi-passport-audit.sh
	@./scripts/check-8a-belyi-equations.sh
	@./scripts/check-degree23-local-groups.sh
	@python3 scripts/verify_4a_orbit.py
	@./scripts/check-seguin-example.sh
	@python3 scripts/verify_seguin_3a_certificates.py
	@python3 scripts/verify_koenig_orbit.py
	@python3 scripts/verify_sharded_4a.py data/derived/m23_4a_sharded_orbit.tsv data/derived/m23_4a_sharded_certificate.tsv
	@python3 scripts/verify_5a_bridge.py
	@python3 scripts/verify_6a_bridge.py
	@python3 scripts/verify_8a_bridge.py
	@python3 scripts/verify_homogeneous_bridge.py

test-replay: test
	@./scripts/check-reference-data.sh
	@M23_SKIP_DERIVED_MANIFEST=1 ./scripts/check-14a-orbit.sh
	@M23_SKIP_DERIVED_MANIFEST=1 ./scripts/check-15a-orbit.sh
	@M23_SKIP_DERIVED_MANIFEST=1 ./scripts/check-8a-small-orbits.sh
	@M23_SKIP_DERIVED_MANIFEST=1 ./scripts/check-4a-orbit.sh
	@./scripts/check-seguin-3a-components.sh
	@./scripts/check-seguin-3a-total.sh
	@./scripts/check-koenig-orbit.sh
	@./scripts/check-sharded-engine.sh

test-long: test-replay check-5a-bridge check-6a-bridge check-native-5a-walk

dashboard:
	@python3 scripts/m23_dashboard.py runs

reproduce-notes: check
	@./scripts/reproduce-notes.sh

reference-data: check
	@./scripts/generate-reference-data.sh

reproduce-14a-orbit: check
	@./scripts/reproduce-14a-orbit.sh

reproduce-15a-orbit: check
	@./scripts/reproduce-15a-orbit.sh

reproduce-8a-small-orbits: check
	@./scripts/reproduce-8a-small-orbits.sh

reproduce-8a-related-start: check
	@./scripts/reproduce-8a-related-start.sh

reproduce-4a-orbit: check
	@./scripts/reproduce-4a-orbit.sh

reproduce-seguin-3a-components: check
	@./scripts/reproduce-seguin-3a-components.sh

check-seguin-3a-components: check
	@./scripts/check-seguin-3a-components.sh

reproduce-seguin-3a-total: check
	@./scripts/reproduce-seguin-3a-total.sh

check-seguin-3a-total: check
	@./scripts/check-seguin-3a-total.sh

reproduce-koenig-orbit: check
	@./scripts/reproduce-koenig-2a2a3a5a.sh

reproduce-koenig-c2-bridge: check
	@./scripts/reproduce-koenig-c2-bridge.sh write

reproduce-koenig-f19-newton: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_f19_newton.sage "$(KOENIG_ARCHIVE)" --output data/derived/m23_koenig_f19_newton_summary.tsv

reproduce-koenig-f19-a: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/recover_koenig_f19_a.sage "$(KOENIG_ARCHIVE)" --check-candidate data/derived/m23_koenig_f19_a_relation.tsv --check-basis data/derived/m23_koenig_f19_a_relation_basis.npz
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_a.sage data/derived/m23_koenig_f19_a_relation.tsv --precision 32768 --check-summary data/derived/m23_koenig_f19_a_validation.tsv

reproduce-koenig-f19-family: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/recover_koenig_f19_family.sage "$(KOENIG_ARCHIVE)" data/derived/m23_koenig_f19_a_relation_basis.npz --check-family data/derived/m23_koenig_f19_family.tsv
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_family.sage data/derived/m23_koenig_f19_family.tsv --precision 32768 --check-summary data/derived/m23_koenig_f19_family_validation.tsv

reproduce-koenig-f19-global: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-koenig-f19-global-certificate.sh data/derived/m23_koenig_f19_family.tsv "$(KOENIG_ARCHIVE)" data/derived/m23_koenig_f19_global_certificate.tsv

reproduce-koenig-f19-passport: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_f19_passport.sage data/derived/m23_koenig_f19_family.tsv "$(KOENIG_ARCHIVE)" data/derived/m23_koenig_f19_global_certificate.tsv --check-summary data/derived/m23_koenig_f19_passport_point.tsv

reproduce-koenig-f19-monodromy: check
	@./scripts/reproduce-koenig-f19-monodromy-gate.sh write

reproduce-koenig-19adic: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_19adic_anchor.sage "$(KOENIG_ARCHIVE)" --digits 32 --output data/derived/m23_koenig_19adic_anchor.tsv

reproduce-koenig-19adic-family: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_19adic_family.sage "$(KOENIG_ARCHIVE)" --digits 32 --precision 64 --output data/derived/m23_koenig_19adic_family.tsv

reproduce-koenig-19adic-highorder: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_19adic_family.sage "$(KOENIG_ARCHIVE)" --digits 32 --precision 16384 --method digitwise --output data/derived/m23_koenig_19adic_family_16384.tsv

check-koenig-orbit: check
	@./scripts/check-koenig-orbit.sh

check-koenig-c2-bridge: check
	@./scripts/reproduce-koenig-c2-bridge.sh check

check-koenig-artifacts: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@python3 scripts/verify_koenig_m23_artifacts.py "$(KOENIG_ARCHIVE)"
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_hurwitz_curve.sage "$(KOENIG_ARCHIVE)"

check-koenig-modular-genus: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/certify_koenig_modular_genus.sage "$(KOENIG_ARCHIVE)"

check-koenig-component-map: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_component_map.sage "$(KOENIG_ARCHIVE)"

check-koenig-f19-anchor: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_anchor.sage "$(KOENIG_ARCHIVE)"

check-koenig-f19-deformation: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_f19_deformation.sage "$(KOENIG_ARCHIVE)"

check-koenig-f19-newton: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_f19_newton.sage "$(KOENIG_ARCHIVE)" --check-summary data/derived/m23_koenig_f19_newton_summary.tsv

check-koenig-f19-a: check
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_a.sage data/derived/m23_koenig_f19_a_relation.tsv

check-koenig-f19-a-long: check
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_a.sage data/derived/m23_koenig_f19_a_relation.tsv --precision 32768 --check-summary data/derived/m23_koenig_f19_a_validation.tsv

check-koenig-f19-family: check
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_family.sage data/derived/m23_koenig_f19_family.tsv

check-koenig-f19-family-long: check
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_family.sage data/derived/m23_koenig_f19_family.tsv --precision 32768 --check-summary data/derived/m23_koenig_f19_family_validation.tsv

check-koenig-f19-global: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_global.sage data/derived/m23_koenig_f19_family.tsv "$(KOENIG_ARCHIVE)" data/derived/m23_koenig_f19_global_certificate.tsv --replay-count 1

check-koenig-f19-global-long: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/verify_koenig_f19_global.sage data/derived/m23_koenig_f19_family.tsv "$(KOENIG_ARCHIVE)" data/derived/m23_koenig_f19_global_certificate.tsv --replay-all

check-koenig-f19-passport: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_f19_passport.sage data/derived/m23_koenig_f19_family.tsv "$(KOENIG_ARCHIVE)" data/derived/m23_koenig_f19_global_certificate.tsv --check-summary data/derived/m23_koenig_f19_passport_point.tsv

check-koenig-f19-monodromy: check
	@./scripts/reproduce-koenig-f19-monodromy-gate.sh check

check-koenig-19adic: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_19adic_anchor.sage "$(KOENIG_ARCHIVE)" --digits 32 --check-summary data/derived/m23_koenig_19adic_anchor.tsv

check-koenig-19adic-family: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_19adic_family.sage "$(KOENIG_ARCHIVE)" --digits 32 --precision 64 --check-summary data/derived/m23_koenig_19adic_family.tsv

check-koenig-19adic-highorder: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_19adic_family.sage "$(KOENIG_ARCHIVE)" --digits 32 --precision 16384 --method digitwise --check-summary data/derived/m23_koenig_19adic_family_16384.tsv

check-koenig-relation-lift-gates: check
	@test -n "$(KOENIG_ARCHIVE)" || { echo "set KOENIG_ARCHIVE" >&2; exit 2; }
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_relation_lift_space.sage "$(KOENIG_ARCHIVE)" --check-summary data/derived/m23_koenig_relation_lift_space.tsv
	@./scripts/run-8a-sage.sh --python scripts/probe_koenig_a_relation_lift.sage --digits 4 --precision 64 --check-summary data/derived/m23_koenig_a_centered_lift_probe.tsv

check-koenig-relation-lift-pilot: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_pilot.sage --check-summary data/derived/m23_koenig_a_relation_lift_pilot.tsv

check-koenig-relation-ambient-digit2: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_ambient_digit2.sage --check-summary data/derived/m23_koenig_a_relation_ambient_digit2.tsv

check-koenig-relation-ambient-digits4: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_ambient_digits4.sage --check-summary data/derived/m23_koenig_a_relation_ambient_digits4.tsv

check-koenig-relation-degree110-digit4: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_degree110_digit4.sage --check-summary data/derived/m23_koenig_a_relation_degree110_digit4.tsv

check-koenig-relation-homogeneous-degree110: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110.tsv

check-koenig-relation-homogeneous-degree110-digits5: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 5 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits5.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits5.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits5_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod2476099.tsv

check-koenig-relation-homogeneous-degree110-digits6: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 6 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits6.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits6.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits6_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod47045881.tsv

check-koenig-relation-homogeneous-degree110-digits7: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 7 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits7.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits7.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits7_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod893871739.tsv

check-koenig-relation-homogeneous-degree110-digits8: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 8 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits8.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits8.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits8_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod16983563041.tsv

check-koenig-relation-homogeneous-degree110-digits9: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 9 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits9.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits9.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits9_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod322687697779.tsv

check-koenig-relation-homogeneous-degree110-digits10: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 10 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod6131066257801.tsv

check-koenig-relation-homogeneous-degree110-digits13: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 13 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13.tsv
	@./scripts/run-8a-sage.sh --python scripts/check_koenig_relation_homogeneous_degree110.sage --summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13.tsv --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13_reduced.npz --coefficients data/derived/m23_koenig_a_relation_homogeneous_degree110_coefficients_mod42052983462257059.tsv

check-koenig-relation-subspace-reconstruction: check
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_subspace.sage --check-summary data/derived/m23_koenig_a_relation_subspace_reconstruction.tsv
	@python3 scripts/check_koenig_relation_subspace_reconstruction.py

check-koenig-relation-subspace-reconstruction-digits8: check
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_subspace.sage --maximum-digits 8 --check-summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits8.tsv
	@python3 scripts/check_koenig_relation_subspace_reconstruction.py --summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits8.tsv

check-koenig-relation-subspace-reconstruction-digits9: check
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_subspace.sage --maximum-digits 9 --check-summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits9.tsv
	@python3 scripts/check_koenig_relation_subspace_reconstruction.py --summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits9.tsv

check-koenig-relation-subspace-reconstruction-digits10: check
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_subspace.sage --maximum-digits 10 --check-summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits10.tsv
	@python3 scripts/check_koenig_relation_subspace_reconstruction.py --summary data/derived/m23_koenig_a_relation_subspace_reconstruction_digits10.tsv

check-koenig-relation-subspace-lattice: check
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_subspace_lattice.sage --check-summary data/derived/m23_koenig_a_relation_subspace_lattice_pilot.tsv
	@python3 scripts/check_koenig_relation_subspace_lattice.py

check-koenig-relation-subspace-lattice-digits10: check
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_subspace_lattice.sage --maximum-digits 10 --check-summary data/derived/m23_koenig_a_relation_subspace_lattice_pilot_digits10.tsv
	@python3 scripts/check_koenig_relation_subspace_lattice.py --summary data/derived/m23_koenig_a_relation_subspace_lattice_pilot_digits10.tsv

check-koenig-relation-subspace-annihilator: check
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_subspace_annihilator.sage --check-summary data/derived/m23_koenig_a_relation_subspace_annihilator_pilot.tsv
	@python3 scripts/check_koenig_relation_subspace_annihilator.py

check-koenig-relation-numerator-filtration: check
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_relation_numerator_filtration.sage --quiet --check-summary data/derived/m23_koenig_a_relation_numerator_filtration.tsv
	@python3 scripts/check_koenig_relation_numerator_filtration.py

check-koenig-relation-supported-subspace: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 10 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10.tsv --check-support-summary data/derived/m23_koenig_a_relation_supported_beta77_digits10.tsv
	@python3 scripts/check_koenig_relation_supported_subspace.py

check-koenig-relation-supported-quotient: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 10 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10.tsv --check-support-summary data/derived/m23_koenig_a_relation_supported_beta77_digits10.tsv --support-representatives-input data/derived/m23_koenig_a_relation_supported_beta77_digits10_representatives.npz --check-support-quotient-summary data/derived/m23_koenig_a_relation_supported_beta77_quotient_reconstruction_digits10.tsv
	@python3 scripts/check_koenig_relation_supported_quotient.py

check-koenig-relation-supported-invariants: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 10 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10.tsv --check-support-summary data/derived/m23_koenig_a_relation_supported_beta77_digits10.tsv --support-representatives-input data/derived/m23_koenig_a_relation_supported_beta77_digits10_representatives.npz --check-support-invariant-summary data/derived/m23_koenig_a_relation_supported_beta77_invariants_digits10.tsv
	@python3 scripts/check_koenig_relation_supported_invariants.py

check-koenig-relation-supported-invariant-stages: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 10 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits10.tsv --check-support-summary data/derived/m23_koenig_a_relation_supported_beta77_digits10.tsv --support-representatives-input data/derived/m23_koenig_a_relation_supported_beta77_digits10_representatives.npz --check-support-invariant-stages-summary data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to10.tsv
	@python3 scripts/check_koenig_relation_supported_invariant_stages.py

check-koenig-relation-supported-invariant-stages-digits13: check
	@./scripts/run-8a-sage.sh --python scripts/lift_koenig_a_relation_homogeneous_degree110.sage --digits 13 --check-summary data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13.tsv --check-support-summary data/derived/m23_koenig_a_relation_supported_beta77_digits13.tsv --support-representatives-input data/derived/m23_koenig_a_relation_supported_beta77_digits13_representatives.npz --check-support-invariant-stages-summary data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to13.tsv
	@python3 scripts/check_koenig_relation_supported_subspace.py --summary data/derived/m23_koenig_a_relation_supported_beta77_digits13.tsv --representatives data/derived/m23_koenig_a_relation_supported_beta77_digits13_representatives.npz --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13_reduced.npz
	@python3 scripts/check_koenig_relation_supported_invariant_stages.py --summary data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to13.tsv --archive data/derived/m23_koenig_a_relation_supported_beta77_numerator_stage_images_digits4to13.npz --support-summary data/derived/m23_koenig_a_relation_supported_beta77_digits13.tsv --support-representatives data/derived/m23_koenig_a_relation_supported_beta77_digits13_representatives.npz --reduced data/derived/m23_koenig_a_relation_homogeneous_degree110_digits13_reduced.npz

check-koenig-relation-supported-free-quotient: check
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_supported_free_quotient.sage --check-summary data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_digits7.tsv
	@python3 scripts/check_koenig_relation_supported_free_quotient.py

check-koenig-relation-supported-free-quotient-digits10: check
	@./scripts/run-8a-sage.sh --python scripts/reconstruct_koenig_relation_supported_free_quotient.sage --stage-summary data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to13.tsv --stage-archive data/derived/m23_koenig_a_relation_supported_beta77_numerator_stage_images_digits4to13.npz --check-summary data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_digits10.tsv
	@python3 scripts/check_koenig_relation_supported_free_quotient.py --summary data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_digits10.tsv --chart data/derived/m23_koenig_a_relation_supported_beta77_free_quotient_chart_digits10.npz --stage-summary data/derived/m23_koenig_a_relation_supported_beta77_invariant_stages_digits4to13.tsv --stage-archive data/derived/m23_koenig_a_relation_supported_beta77_numerator_stage_images_digits4to13.npz

check-koenig-relation-supported-free-lattice: check
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_supported_free_lattice.sage --check-summary data/derived/m23_koenig_a_relation_supported_beta77_free_lattice_pilot.tsv
	@python3 scripts/check_koenig_relation_supported_free_lattice.py

check-koenig-relation-supported-hard-lattice: check
	@./scripts/run-8a-sage.sh --python scripts/pilot_koenig_relation_supported_hard_lattice.sage --check-summary data/derived/m23_koenig_a_relation_supported_beta77_hard_lattice_pilot.tsv
	@python3 scripts/check_koenig_relation_supported_hard_lattice.py

check-koenig-second-prime-feasibility: check
	@./scripts/run-8a-sage.sh --python scripts/export_koenig_second_prime_msolve.sage --self-test
	@python3 scripts/check_koenig_second_prime_feasibility.py

check-koenig-f19-positive-control: check
	@./scripts/run-8a-sage.sh --python scripts/export_koenig_f19_positive_control_msolve.sage --self-test
	@./scripts/run-8a-sage.sh --python scripts/audit_koenig_f19_positive_control.sage --self-test
	@python3 scripts/check_koenig_f19_positive_control.py

check-lean:
	@./scripts/check-lean.sh

check-native-kernel:
	@./scripts/check-native-kernel.sh

check-native-sqlite-ledger:
	@./scripts/check-native-sqlite-ledger.sh

check-native-sqlite-queued-writer:
	@./scripts/check-native-sqlite-queued-writer.sh

check-native-replay-ledger:
	@./scripts/check-native-replay-ledger.sh

check-native-5a-census:
	@output=$$(mktemp); \
	trap 'rm -f "$$output"' EXIT; \
	./scripts/generate-native-coordinate-table-census.sh 5 "$$output"; \
	cmp data/reference/native_5a_coordinate_table_census.tsv "$$output"

check-native-5a-walk:
	@./scripts/check-native-5a-bounded-walk.sh

check-cuda-batch:
	@./scripts/benchmark-cuda-permutation-batch.sh 1024

check-5a-generation-masks:
	@./scripts/check-5a-generation-masks.sh

check-m24-genus11-model: check
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_model.sage --self-test
	@python3 scripts/check_m24_genus11_model.py

check-m24-genus11-boundary: check
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_boundary.sage --self-test
	@python3 scripts/check_m24_genus11_boundary.py

check-m24-genus11-unit-charts: check
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_unit_charts.sage --self-test
	@python3 scripts/check_m24_genus11_unit_charts.py

check-m24-genus11-local-elimination: check
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_local_elimination.sage --self-test
	@python3 scripts/check_m24_genus11_local_elimination.py

check-m24-genus11-minus2-shards: check
	@./scripts/run-8a-sage.sh --python scripts/run_m24_genus11_minus2_shards.sage --self-test
	@python3 scripts/check_m24_genus11_minus2_shards.py

check-m24-genus11-minus2-clusters: check
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_minus2_clusters.sage --self-test
	@python3 scripts/check_m24_genus11_minus2_clusters.py

check-m24-genus11-tropical-exhaustion: check
	@./scripts/run-8a-sage.sh --python scripts/audit_m24_genus11_tropical_exhaustion.sage --self-test
	@python3 scripts/check_m24_genus11_tropical_exhaustion.py

check-8a-continuation:
	@julia --project=julia/8a_belyi julia/8a_belyi/test_continuation.jl

check-8a-conditioning-census:
	@python3 scripts/test_census_8a_belyi_conditioning.py
	@python3 scripts/check_8a_belyi_conditioning_census.py data/derived/m23_8a_belyi_conditioning_census.tsv data/derived/m23_8a_belyi_conditioning_seeds.tsv

check-8a-seed-transfer:
	@python3 scripts/check_8a_belyi_seed_transfer.py

check-8a-related-start:
	@./scripts/check-8a-related-start.sh

check-8a-exact-algebra:
	@./scripts/check-8a-exact-algebra.sh

check-8a-exact-recognition:
	@python3 scripts/check_8a_exact_recognition.py
	@./scripts/run-8a-sage.sh --python scripts/verify_belyi_candidate_sage.sage data/derived/m23_8a_belyi_class1_exact_candidate.json

check-8a-coefficient-field:
	@python3 scripts/check_8a_coefficient_field.py data/derived/m23_8a_belyi_class1_coefficient_field.tsv

check-8a-reciprocal-descent:
	@python3 scripts/check_8a_reciprocal_descent.py data/derived/m23_8a_belyi_class1_reciprocal_descent.tsv data/derived/m23_8a_class1_degree14_descended_cover.json
	@./scripts/run-8a-sage.sh --python scripts/verify_8a_descended_cover.sage data/derived/m23_8a_class1_degree14_descended_cover.json

check-8a-absolute-orbit:
	@./scripts/run-8a-sage.sh --python scripts/analyze_8a_absolute_orbit.sage data/derived/m23_8a_belyi_class1_exact_candidate.json data/derived/m23_8a_class1_degree14_descended_cover.json data/derived/m23_8a_8a_2a_inner_classes.tsv >/dev/null
	@./scripts/run-8a-sage.sh --python scripts/check_8a_absolute_orbit.sage data/derived/m23_8a_belyi_absolute_orbit.tsv

check-8a-fixed-field-galois:
	@./scripts/check-8a-fixed-field-galois.sh

check-8a-interval-monodromy:
	@python3 scripts/check_8a_interval_monodromy.py data/derived/m23_8a_belyi_class1_interval_monodromy.tsv

check-8a-barth-wenz:
	@python3 scripts/test_barth_wenz_preprocess.py
	@python3 scripts/test_prepare_barth_wenz_matlab.py
	@python3 scripts/check_barth_wenz_matlab_bundles.py
	@python3 scripts/check_barth_wenz_matlab_result.py
	@python3 scripts/check_barth_wenz_matlab_result.py data/derived/m23_8a_barth_wenz_class1_domain2_dessin.tsv
	@python3 scripts/test_prepare_barth_wenz_root_seed.py
	@python3 scripts/test_refine_barth_wenz_root_seed.py
	@python3 scripts/check_barth_wenz_refinement.py
	@python3 scripts/check_barth_wenz_candidate.py data/derived/m23_8a_barth_wenz_domain2_certified_endpoint-path1.tsv
	@python3 scripts/check_8a_high_precision_coefficients.py
	@python3 scripts/check_8a_cover_monodromy.py data/derived/m23_8a_belyi_class1_cover_monodromy.tsv
	@python3 scripts/check_8a_exact_recognition.py
	@./scripts/run-8a-sage.sh --python scripts/verify_belyi_candidate_sage.sage data/derived/m23_8a_belyi_class1_exact_candidate.json >/dev/null
	@bash -n scripts/setup-barth-wenz-octave.sh
	@bash -n scripts/check-barth-wenz-octave-incompatibility.sh

reproduce-8a-conditioning-census:
	@python3 scripts/census_8a_belyi_conditioning.py \
		--output data/derived/m23_8a_belyi_conditioning_census.tsv \
		--detail-output data/derived/m23_8a_belyi_conditioning_seeds.tsv

check-belyi-carnoldi:
	@test -n "$(BELYI_CHECKOUT)" || { echo "set BELYI_CHECKOUT" >&2; exit 2; }
	@test -n "$(OUTPUT_DIR)" || { echo "set OUTPUT_DIR" >&2; exit 2; }
	@./scripts/check-belyi-carnoldi.sh "$(BELYI_CHECKOUT)" "$(OUTPUT_DIR)" $(if $(DEPENDENCY_PREFIX),"$(DEPENDENCY_PREFIX)")

check-magma-8a-pilot:
	@bash -n magma/8a_belyi/run-class1-pilot.sh
	@python3 scripts/test_extract_magma_belyi_candidate.py
	@python3 scripts/test_check_magma_8a_serialization_smoke.py
	@python3 scripts/check_magma_8a_serialization_smoke.py notes/magma_8a_serialization_smoke.txt >/dev/null
	@python3 scripts/test_magma_8a_pilot.py
	@python3 scripts/test_verify_belyi_candidate.py

check-sharded-engine: check
	@./scripts/check-sharded-engine.sh

sharded-4a: check
	@M23_JOBS=$${M23_JOBS:-2} ./scripts/run-sharded-cc2a2a.sh 4 4 \
		runs/4a-sharded data/derived/m23_4a_sharded_orbit.tsv \
		data/derived/m23_4a_sharded_certificate.tsv

check-5a-bridge: check
	@./scripts/check-5a-bridge.sh

check-5a-homogeneous: check
	@./scripts/check-5a-homogeneous.sh

check-6a-bridge: check
	@./scripts/check-6a-bridge.sh

check-8a-bridge: check
	@./scripts/check-8a-bridge.sh
