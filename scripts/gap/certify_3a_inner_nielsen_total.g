Read("src/gap/m23_homogeneous_macroblocks.g");;
Read("src/gap/m23_maximal_subgroup_masks.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT) then
  Error("M23_PAIR_CHECKPOINT must name the 3A pair checkpoint");
fi;
if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated certificate");
fi;
if not IsBound(GAPInfo.SystemEnvironment.M23_CODE_REVISION) then
  Error("M23_CODE_REVISION must name the generating Git revision");
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;
Assert(0, checkpoint.schema_version = 2);
Assert(0, checkpoint.target_order = 3);
Assert(0, checkpoint.pair_orbit_count = 356);
Assert(0, checkpoint.macroblock_count = 11474);

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
targetClass := First(classes, class ->
  Order(Representative(class)) = checkpoint.target_order);;
Assert(0, Length(Filtered(classes, class ->
  Order(Representative(class)) = checkpoint.target_order)) = 1);
Assert(0, Size(targetClass) = checkpoint.target_class_size);
target := Representative(targetClass);;

# A fixed-first tuple fails to generate M23 exactly when all its entries lie
# in one of the maximal subgroups containing the fixed first entry.
incidence := M23BuildFixedTargetMaximalSubgroups(
  G, targetClass, target);;
Assert(0, Length(incidence.rows) = 7);
Assert(0, Length(incidence.subgroups) = 62);

targetElements := AsList(targetClass);;
maskIndex := NewDictionary(target, true);;
for element in targetElements do
  AddDictionary(maskIndex, element,
    M23FixedTargetIncidenceMask(incidence, element));
od;

MasksHaveCommonBit := function(masks)
  local bit;
  for bit in [1..Length(incidence.subgroups)] do
    if ForAll(masks, mask ->
        QuoInt(mask, 2 ^ (bit - 1)) mod 2 = 1) then
      return true;
    fi;
  od;
  return false;
end;;

orders := Set(List(classes, class -> Order(Representative(class))));;
innerByOrder := List(orders, order -> 0);;
generatingByOrder := List(orders, order -> 0);;
nonGeneratingByOrder := List(orders, order -> 0);;
nonGeneratingGroupOrders := [];;
totalInner := 0;;
totalGenerating := 0;;
totalNonGenerating := 0;;
maskDisagreements := 0;;
processedBlocks := 0;;
weightedInnerMass := 0;;

for ordinal in [1..checkpoint.macroblock_count] do
  block := M23DecodeMacroblock(checkpoint, ordinal);
  materialized := M23MaterializeMacroblock(G, classes, checkpoint, block);
  productOrder := Order(Representative(
    classes[block.natural_class_index]));
  orderIndex := Position(orders, productOrder);
  innerByOrder[orderIndex] := innerByOrder[orderIndex] +
    materialized.inner_class_count;
  totalInner := totalInner + materialized.inner_class_count;
  for tupleIndex in [1..Length(materialized.tuples)] do
    tuple := materialized.tuples[tupleIndex];
    weightedInnerMass := weightedInnerMass +
      1 / materialized.stabilizer_orders[tupleIndex];
    Assert(0, IsProductOneTuple(tuple));
    Assert(0, ForAll(tuple, entry -> entry in targetClass));
    firstTransporter := RepresentativeAction(G, tuple[1], target);
    Assert(0, firstTransporter <> fail);
    fixedTuple := SimultaneousConjugate(tuple, firstTransporter);
    Assert(0, fixedTuple[1] = target);
    masks := List(fixedTuple, entry -> LookupDictionary(maskIndex, entry));
    Assert(0, not fail in masks);
    maskGenerating := not MasksHaveCommonBit(masks);
    generatedGroup := Group(tuple);
    directGenerating := generatedGroup = G;
    if maskGenerating <> directGenerating then
      maskDisagreements := maskDisagreements + 1;
    fi;
    if directGenerating then
      totalGenerating := totalGenerating + 1;
      generatingByOrder[orderIndex] := generatingByOrder[orderIndex] + 1;
    else
      totalNonGenerating := totalNonGenerating + 1;
      nonGeneratingByOrder[orderIndex] :=
        nonGeneratingByOrder[orderIndex] + 1;
      AddSet(nonGeneratingGroupOrders, Size(generatedGroup));
    fi;
  od;
  processedBlocks := processedBlocks + 1;
od;

Assert(0, processedBlocks = 11474);
Assert(0, totalInner = totalGenerating + totalNonGenerating);
Assert(0, maskDisagreements = 0);
Assert(0, totalGenerating = 37296);

table := CharacterTable("M23");;
tableNames := List(ClassNames(table), LowercaseString);;
tablePosition := Position(tableNames, "3a");;
Assert(0, tablePosition <> fail);
tableClassSize := SizesConjugacyClasses(table)[tablePosition];;
Assert(0, tableClassSize = Size(targetClass));
characterSum := Sum(Irr(table), character ->
  character[tablePosition] ^ 4 / character[1] ^ 2);;
productOneTupleCount :=
  tableClassSize ^ 4 / Size(table) * characterSum;;
Assert(0, IsInt(productOneTupleCount));
Assert(0, weightedInnerMass = productOneTupleCount / Size(G));

pairHash := "not_recorded";;
if IsBound(GAPInfo.SystemEnvironment.M23_PAIR_SHA256) then
  pairHash := GAPInfo.SystemEnvironment.M23_PAIR_SHA256;
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
PrintTo(output,
  "# generated_by\tscripts/gap/certify_3a_inner_nielsen_total.g\n",
  "# code_revision\t", GAPInfo.SystemEnvironment.M23_CODE_REVISION, "\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# atlasrep_version\t", GAPInfo.PackagesInfo.atlasrep[1].Version, "\n",
  "# ctbllib_version\t", GAPInfo.PackagesInfo.ctbllib[1].Version, "\n",
  "# transgrp_version\t", GAPInfo.PackagesInfo.transgrp[1].Version, "\n",
  "# group\tMathieuGroup(23)\n",
  "# group_order\t", Size(G), "\n",
  "# target_class\t3A\n",
  "# target_class_size\t", Size(targetClass), "\n",
  "# source_pair_checkpoint_sha256\t", pairHash, "\n",
  "# generation_checks\tdirect Group(tuple)=M23 and fixed-first maximal-subgroup masks\n",
  "property\tvalue\n",
  "pair_orbit_count\t", checkpoint.pair_orbit_count, "\n",
  "pair_orbit_coverage_weight\t", checkpoint.pair_orbit_coverage_weight, "\n",
  "macroblock_count\t", checkpoint.macroblock_count, "\n",
  "materialized_inner_class_count\t", totalInner, "\n",
  "character_table_product_one_tuple_count\t", productOneTupleCount, "\n",
  "weighted_inner_orbit_mass\t", weightedInnerMass, "\n",
  "generating_inner_nielsen_count\t", totalGenerating, "\n",
  "nongenerating_inner_class_count\t", totalNonGenerating, "\n",
  "fixed_first_maximal_subgroups\t", Length(incidence.subgroups), "\n",
  "generation_mask_disagreements\t", maskDisagreements, "\n",
  "nongenerating_subgroup_orders\t",
    JoinStringsWithSeparator(List(nonGeneratingGroupOrders, String), ","), "\n",
  "\n",
  "pair_product_order\tinner_classes\tgenerating_inner_classes\t",
    "nongenerating_inner_classes\n");
for orderIndex in [1..Length(orders)] do
  if innerByOrder[orderIndex] > 0 then
    AppendTo(output,
      orders[orderIndex], "\t", innerByOrder[orderIndex], "\t",
      generatingByOrder[orderIndex], "\t",
      nonGeneratingByOrder[orderIndex], "\n");
  fi;
od;
QUIT;
