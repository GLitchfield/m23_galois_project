sym := CharacterTable("Symmetric", 23);;
sym_params := ClassParameters(sym);;
lambda8 := [ 8, 8, 4, 2, 1 ];
lambda2 := [ 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1 ];
sym8 := PositionProperty(sym_params, p -> p[2] = lambda8);;
sym2 := PositionProperty(sym_params, p -> p[2] = lambda2);;
sym_coeff := ClassMultiplicationCoefficient(sym, sym8, sym8, sym2);;
sym_sizes := SizesConjugacyClasses(sym);;
sym_mass := sym_coeff * sym_sizes[sym2] / Size(sym);;

m23 := CharacterTable("M23");;
m23_names := ClassNames(m23);;
m23_8a := Position(m23_names, "8a");;
m23_2a := Position(m23_names, "2a");;
m23_coeff := ClassMultiplicationCoefficient(m23, m23_8a, m23_8a, m23_2a);;
m23_sizes := SizesConjugacyClasses(m23);;
m23_mass := m23_coeff * m23_sizes[m23_2a] / Size(m23);;

Print("s23_class_8=", sym8, "\n");
Print("s23_class_2=", sym2, "\n");
Print("s23_structure_coefficient=", sym_coeff, "\n");
Print("s23_weighted_orbit_mass=", sym_mass, "\n");
Print("m23_class_8a=", m23_8a, "\n");
Print("m23_class_2a=", m23_2a, "\n");
Print("m23_structure_coefficient=", m23_coeff, "\n");
Print("m23_weighted_orbit_mass=", m23_mass, "\n");

if sym_mass <> 1024815269 / 1024 then
  Error("unexpected S23 passport mass");
fi;
if m23_mass <> 491 / 8 then
  Error("unexpected M23 refined passport mass");
fi;

QUIT;
