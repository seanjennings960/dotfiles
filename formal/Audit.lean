import DevCreation.Proofs

-- These print the logical axioms on which the kernel-checked results depend.
-- The expected dependencies are Lean's standard logical axioms, never sorryAx.
#print axioms DevCreation.execute_preserves_wellFormed
#print axioms DevCreation.reachable_effects_safe
#print axioms DevCreation.download_has_explicit_grant
#print axioms DevCreation.creation_effects_have_no_network
#print axioms DevCreation.creation_never_downloads
#print axioms DevCreation.creation_preserves_store
#print axioms DevCreation.failure_preserves_store
#print axioms DevCreation.no_overlapping_operations
#print axioms DevCreation.active_inputs_cannot_be_evicted
