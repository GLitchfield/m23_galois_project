Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_maximal_subgroup_masks.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT) then
  Error("M23_PAIR_CHECKPOINT must name the 5A homogeneous pair checkpoint");
fi;
if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated certificate TSV");
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
if checkpoint.target_order <> 5 then
  Error("generation-mask certificate requires the 5A pair checkpoint");
fi;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
classNames := AtlasClassNames(CharacterTable(G));;
targetClassIndex := Position(classNames, "5A");;
if targetClassIndex = fail or
   Size(classes[targetClassIndex]) <> checkpoint.target_class_size then
  Error("could not align the permutation and character-table 5A classes");
fi;
targetClass := classes[targetClassIndex];;
target := Representative(targetClass);;
incidence := M23BuildFixedTargetMaximalSubgroups(G, targetClass, target);;
if Length(incidence.rows) <> 7 or Length(incidence.subgroups) <> 14 then
  Error("unexpected M23 fixed-5A maximal-subgroup incidence shape");
fi;
if M23FixedTargetIncidenceMask(incidence, target) <> 2 ^ 14 - 1 then
  Error("fixed 5A target is not present in every incidence bit");
fi;

M23MasksHaveBit := function(masks, bit)
  local mask;
  for mask in masks do
    if QuoInt(mask, 2 ^ (bit - 1)) mod 2 <> 1 then
      return false;
    fi;
  od;
  return true;
end;;

testedTuples := 0;;
actualGenerating := 0;;
maskGenerating := 0;;
disagreements := 0;;
distinctMasks := [];;
testedClasses := 0;;
for segment in M23MacroblockSegments(checkpoint) do
  if segment.first_ordinal = 1 then
    continue;
  fi;
  block := M23DecodeMacroblock(checkpoint, segment.first_ordinal);
  materialized := M23MaterializeMacroblock(G, classes, checkpoint, block);
  testedClasses := testedClasses + 1;
  for tuple in materialized.tuples do
    firstTransport := RepresentativeAction(G, tuple[1], target);
    if firstTransport = fail then
      Error("validation tuple leaves the 5A target class");
    fi;
    fixedTuple := SimultaneousConjugate(tuple, firstTransport);
    if fixedTuple[1] <> target then
      Error("validation tuple did not normalize its first coordinate");
    fi;
    masks := List(fixedTuple, element ->
      M23FixedTargetIncidenceMask(incidence, element));
    UniteSet(distinctMasks, Set(masks));
    commonBits := [];
    for bit in [1..Length(incidence.subgroups)] do
      if M23MasksHaveBit(masks, bit) then
        Add(commonBits, bit);
      fi;
    od;
    predictedGenerating := Length(commonBits) = 0;
    generated := IsGeneratingTuple(G, tuple);
    testedTuples := testedTuples + 1;
    if generated then actualGenerating := actualGenerating + 1; fi;
    if predictedGenerating then maskGenerating := maskGenerating + 1; fi;
    if generated <> predictedGenerating then
      disagreements := disagreements + 1;
    fi;
  od;
od;
if disagreements <> 0 or actualGenerating <> maskGenerating then
  Error("maximal-subgroup masks disagree with direct group generation");
fi;

pairHash := "unknown";;
if IsBound(GAPInfo.SystemEnvironment.M23_PAIR_SHA256) then
  pairHash := GAPInfo.SystemEnvironment.M23_PAIR_SHA256;
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
PrintTo(output,
  "# generated_by\tscripts/gap/certify_5a_generation_masks.g\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# group\tMathieuGroup(23)\n",
  "# group_order\t", Size(G), "\n",
  "# target_class\t5A\n",
  "# target_class_size\t", Size(targetClass), "\n",
  "# source_checkpoint_sha256\t", pairHash, "\n",
  "# mask_bits\t", Length(incidence.subgroups), "\n",
  "# criterion\ta fixed-first tuple generates M23 iff its coordinate masks have zero common incidence bit\n",
  "maximal_class\tsubgroup_order\tconjugacy_class_size\torder5_elements\tpredicted_target_incidence\tenumerated_target_incidence\tfirst_bit\tlast_bit\n");
for row in incidence.rows do
  AppendTo(output,
    row.maximal_class, "\t", row.subgroup_order, "\t",
    row.conjugacy_class_size, "\t", row.order_element_count, "\t",
    row.predicted_target_incidence, "\t",
    row.enumerated_target_incidence, "\t", row.first_bit, "\t",
    row.last_bit, "\n");
od;
AppendTo(output,
  "# validation_product_classes\t", testedClasses, "\n",
  "# validation_tuples\t", testedTuples, "\n",
  "# validation_distinct_masks\t", Length(distinctMasks), "\n",
  "# validation_direct_generating\t", actualGenerating, "\n",
  "# validation_mask_generating\t", maskGenerating, "\n",
  "# validation_disagreements\t", disagreements, "\n");
QUIT;
