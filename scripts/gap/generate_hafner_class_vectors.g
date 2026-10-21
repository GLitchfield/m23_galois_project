if not IsBound(GAPInfo.SystemEnvironment.M23_OUTPUT) then
  Error("M23_OUTPUT must name the generated TSV file");
fi;
output := GAPInfo.SystemEnvironment.M23_OUTPUT;;
SizeScreen([100000, 100000]);;
table := CharacterTable("M23");;
names := ClassNames(table);;
characters := Irr(table);;
sizes := SizesConjugacyClasses(table);;
groupOrder := Size(table);;

# Columns: class names, published inner Nielsen count, published floor(n), source.
rows := [
  [["2A","2A","2A"], 0, 0],
  [["3A","3A","2A"], 0, 1],
  [["4A","4A","2A"], 0, 8],
  [["5A","5A","2A"], 0, 40],
  [["6A","6A","2A"], 0, 34],
  [["8A","8A","2A"], 28, 61],
  [["2A","2A","2A","2A"], 0, 19],
  [["3A","2A","2A","2A"], 0, 112],
  [["4A","2A","2A","2A"], 0, 378],
  [["5A","2A","2A","2A"], 0, 658],
  [["6A","2A","2A","2A"], 0, 547],
  [["8A","2A","2A","2A"], 0, 664],
  [["3A","3A","2A","2A"], 0, 1105],
  [["4A","4A","2A","2A"], 2456, 19048],
  [["5A","5A","2A","2A"], 30400, 83906],
  [["6A","6A","2A","2A"], 72528, 101811],
  [["8A","8A","2A","2A"], 198488, 228399],
  [["3A","3A","3A","2A"], 996, 12352],
  [["4A","4A","4A","2A"], 768528, 1298855],
  [["5A","5A","5A","2A"], 8569480, 12593829],
  [["6A","6A","6A","2A"], 21846222, 22398281],
  [["8A","8A","8A","2A"], 74725280, 75791456],
  [["3A","3A","3A","3A"], 37296, 155711],
  [["4A","4A","4A","4A"], 85607040, 102663428],
  [["5A","5A","5A","5A"], 1811840784, 2124083306],
  [["6A","6A","6A","6A"], 5004867456, 5020189817],
  [["8A","8A","8A","8A"], 25382467456, 25432112544]
];;

NormalizedStructureConstant := function(classNames)
  local positions, centralizers, length, sum, character;
  positions := List(classNames, name ->
    Position(names, LowercaseString(name)));
  if fail in positions then
    Error("unknown character-table class in ", classNames);
  fi;
  centralizers := List(positions, position -> groupOrder / sizes[position]);
  length := Length(positions);
  sum := Sum(characters, character ->
    Product(positions, position -> character[position]) /
    character[1]^(length - 2));
  return groupOrder^(length - 2) / Product(centralizers) * sum;
end;;

FloorPositiveRational := number ->
  QuoInt(NumeratorRat(number), DenominatorRat(number));;

JoinWithComma := function(strings)
  local result, position;
  result := strings[1];
  for position in [2..Length(strings)] do
    result := Concatenation(result, ",", strings[position]);
  od;
  return result;
end;;

PrintTo(output,
  "# generated_by\tscripts/gap/generate_hafner_class_vectors.g\n",
  "# gap_version\t", GAPInfo.Version, "\n",
  "# character_table\t", Identifier(table), "\n",
  "class_vector\tpublished_inner_nielsen_count\tcomputed_normalized_constant\tpublished_normalized_floor\tsource\n");

for row in rows do
  constant := NormalizedStructureConstant(row[1]);
  if FloorPositiveRational(constant) <> row[3] then
    Error("structure-constant mismatch for ", row[1], ": computed ",
      constant, ", published floor ", row[3]);
  fi;
  AppendTo(output,
    JoinWithComma(row[1]), "\t", row[2], "\t", constant, "\t",
    row[3], "\t", "Hafner 2022 tab:Data_4DimClassvectorsM23", "\n");
od;

QUIT;
