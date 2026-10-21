Read("src/gap/m23_homogeneous_macroblocks.g");;
SizeScreen([1000000, 1000000]);;

M23_PAIR_BLOCK_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_PAIR_CHECKPOINT);
pairCheckpoint := M23_PAIR_BLOCK_CHECKPOINT;;
M23_SHARD_CHECKPOINT := fail;;
Read(GAPInfo.SystemEnvironment.M23_BRIDGE_CHECKPOINT);
bridgeCheckpoint := M23_SHARD_CHECKPOINT;;

G := MathieuGroup(23);;
classes := ConjugacyClasses(G);;
locator := M23BuildDirectPairLocator(G, classes, pairCheckpoint);;
seed := M23TranslateBridgeG41(bridgeCheckpoint.representatives[1]);;
started := Runtime();;
progressPath := fail;;
if IsBound(GAPInfo.SystemEnvironment.M23_PROGRESS_FILE) then
  progressPath := GAPInfo.SystemEnvironment.M23_PROGRESS_FILE;
  LoadPackage("io");
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tquotient_walk\t4\tstart\tlimit=2500\n");
fi;
bounded := M23BoundedDirectPairTwistOrbit(locator, seed, 2500,
  function(checked, discovered, classesFound)
    Print("elapsed_ms=", Runtime() - started, " checked_vertices=", checked,
      " discovered_vertices=", discovered, " discovered_classes=",
      classesFound, "\n");
    if progressPath <> fail then
      AppendTo(progressPath, IO_gettimeofday().tv_sec,
        "\tgap\tquotient_walk\t4\tprogress\tchecked=", checked,
        ",vertices=", discovered, ",classes=", classesFound, "\n");
    fi;
  end);;
Assert(0, bounded.closed);
Assert(0, bounded.discovered_class_count = 2456);
if progressPath <> fail then
  AppendTo(progressPath, IO_gettimeofday().tv_sec,
    "\tgap\tquotient_walk\t4\tdone\tvertices=",
    bounded.discovered_vertex_count, ",classes=",
    bounded.discovered_class_count, "\n");
fi;
Print("verified direct quotient closes the 2456-class component\n");
QUIT;
