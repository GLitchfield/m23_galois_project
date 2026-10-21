Read("src/gap/nielsen.g");;
SizeScreen([1000000, 1000000]);;

if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;

a := (1,22,14)(2,13,9)(3,8,6)(7,16,21)(10,18,19)(11,23,12);;
h := (1,17)(3,21,7)(4,13)(5,22,15,23,9,16)
     (6,10,11,8,20,19)(12,14,18);;
b := h^-1 * a * h;;
input := [a, a^-1, b, b^-1];;

# A generating tuple from the certified (4A,4A,2A,2A) bridge.  The native
# kernel originally used only Seguin's (3A)^4 tuple; this second case exercises
# the exact class vector used by the production quotient walk.
input4a := [
  (1,12,11,8)(3,16,22,15)(4,20,7,17)(5,10,21,19)(9,14)(18,23),
  (4,17,18,5)(6,14,15,23)(7,12,8,9)(10,21)(11,16)(13,20,19,22),
  (1,8)(2,10)(5,21)(6,7)(11,15)(12,16)(13,20)(22,23),
  (2,10)(3,15)(4,19)(6,14)(7,18)(9,11)(16,20)(21,23)
];;
Assert(0, IsProductOneTuple(input4a));
Assert(0, List(input4a, Order) = [4, 4, 2, 2]);
Assert(0, Size(Group(input4a)) = 10200960);

M23PermutationImages := function(permutation)
  return JoinStringsWithSeparator(
    List([1..23], point -> String(point^permutation)), ",");
end;;

TupleRow := function(name, tuple)
  return Concatenation(name, "\t",
    JoinStringsWithSeparator(List(tuple, M23PermutationImages), "\t"), "\n");
end;;

PrintTo(GAPInfo.SystemEnvironment.M23_OUTPUT,
  "# generated_by\tscripts/gap/generate_native_kernel_fixture.g\n",
  "# convention\timages 1..23; GAP right-action composition\n",
  "name\tp1\tp2\tp3\tp4\n",
  TupleRow("input", input),
  TupleRow("hurwitz3", HurwitzMove(input, 3)),
  TupleRow("inverse_hurwitz3", InverseHurwitzMove(input, 3)),
  TupleRow("beta12", PureBraidMove4Direct(input, 12)),
  TupleRow("beta13", PureBraidMove4Direct(input, 13)),
  TupleRow("beta14", PureBraidMove4Direct(input, 14)),
  TupleRow("probe_beta12",
    PureBraidMove4Direct(HurwitzMove(input, 3), 12)),
  TupleRow("4a_input", input4a),
  TupleRow("4a_beta12", PureBraidMove4Direct(input4a, 12)),
  TupleRow("4a_beta13", PureBraidMove4Direct(input4a, 13)),
  TupleRow("4a_beta14", PureBraidMove4Direct(input4a, 14)));
QUIT;
