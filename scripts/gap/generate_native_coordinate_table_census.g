if not IsBound(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT) then
  Error("M23_PAIR_CHECKPOINT must name a homogeneous pair checkpoint");
fi;
SizeScreen([1000000, 1000000]);;
if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
checkpoint := M23_PAIR_BLOCK_CHECKPOINT;;

rightPairRows := 0;;
for record in checkpoint.classes do
  inverseRecord := checkpoint.classes[record.inverse_class_index];
  if record.pair_orbit_count > 0 and record.class_size <> 1 then
    centralizerOrder := checkpoint.group_order / record.class_size;
    for stabilizerOrder in inverseRecord.stabilizer_sizes do
      rightPairRows := rightPairRows + centralizerOrder / stabilizerOrder;
    od;
  fi;
od;

# Current micro-checkpoint row layouts, excluding container overhead:
# target: fixed-second(23), class/pair IDs(8), normalizer(23), base pair(46)
# right: class ID(4), pair key(46), pair ID(4), relative transporter(23)
targetRowBytes := 100;;
rightRowBytes := 77;;
targetRawBytes := checkpoint.target_class_size * targetRowBytes;;
rightRawBytes := rightPairRows * rightRowBytes;;
checkpointHash := "unknown";;
if IsBound(GAPInfo.SystemEnvironment.M23_PAIR_SHA256) then
  checkpointHash := GAPInfo.SystemEnvironment.M23_PAIR_SHA256;
fi;

PrintTo(GAPInfo.SystemEnvironment.M23_OUTPUT,
  "# schema\tm23-native-coordinate-table-census-v1\n",
  "# source_checkpoint_sha256\t", checkpointHash, "\n",
  "target_order\ttarget_pair_rows\tright_pair_rows\t",
    "target_raw_bytes\tright_raw_bytes\ttotal_raw_bytes\n",
  checkpoint.target_order, "\t", checkpoint.target_class_size, "\t",
    rightPairRows, "\t", targetRawBytes, "\t", rightRawBytes, "\t",
    targetRawBytes + rightRawBytes, "\n");
QUIT;
