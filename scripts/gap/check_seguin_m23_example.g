Read("src/gap/nielsen.g");;

# Seguin, Example 5.5. The multiplication below is exactly the GAP snippet
# printed in the paper; it avoids translating between conjugation conventions.
a := (1,22,14)(2,13,9)(3,8,6)(7,16,21)(10,18,19)(11,23,12);;
h := (1,17)(3,21,7)(4,13)(5,22,15,23,9,16)
     (6,10,11,8,20,19)(12,14,18);;
b := h^-1 * a * h;;
G := MathieuGroup(23);;
H := Group(a, b);;
classes := ConjugacyClasses(G);;
classIndex := PositionProperty(classes, class -> a in class);;
tuple := [a, a^-1, b, b^-1];;

Assert(0, Order(a) = 3 and Order(b) = 3);
Assert(0, Size(H) = 10200960 and H = G);
Assert(0, classIndex <> fail);
Assert(0, Size(classes[classIndex]) = 56672);
Assert(0, Size(Centralizer(G, a)) = 180);
Assert(0, ForAll(tuple, entry -> entry in classes[classIndex]));
Assert(0, IsProductOneTuple(tuple));
Assert(0, IsGeneratingTuple(G, tuple));

Print("property\tvalue\n");
Print("a_order\t", Order(a), "\n");
Print("b_order\t", Order(b), "\n");
Print("generated_group_order\t", Size(H), "\n");
Print("gap_class_index\t", classIndex, "\n");
Print("atlas_class\t3A\n");
Print("class_size\t", Size(classes[classIndex]), "\n");
Print("centralizer_size\t", Size(Centralizer(G, a)), "\n");
Print("cycle_shape\t1^5 3^6\n");
Print("tuple_product_one\ttrue\n");
Print("tuple_generates_m23\ttrue\n");
QUIT;
