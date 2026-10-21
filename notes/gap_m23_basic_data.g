G := MathieuGroup(23);;
Print("Size: ", Size(G), "\n");
Print("Transitivity degree on natural action: ", Transitivity(G, [1..23]), "\n");
Print("Is simple: ", IsSimpleGroup(G), "\n");
cc := ConjugacyClasses(G);;
Print("Conjugacy classes: ", Length(cc), "\n");
Print("Class sizes and element orders:\n");
for c in cc do
  Print(Size(c), " order ", Order(Representative(c)), " cycle ",
        CycleStructurePerm(Representative(c)), "\n");
od;
t := CharacterTable("M23");;
Print("\nCharacter table identifier: ", Identifier(t), "\n");
Print("Class names: ", ClassNames(t), "\n");
Print("Orders: ", OrdersClassRepresentatives(t), "\n");

QUIT;


