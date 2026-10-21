IsProductOneTuple := function(tuple)
  return Product(tuple) = One(tuple[1]);
end;;

IsGeneratingTuple := function(group, tuple)
  return Group(tuple) = group;
end;;

HurwitzMove := function(tuple, index)
  local result, left, right;
  if index < 2 or index > Length(tuple) then
    Error("Hurwitz generator index must lie in [2, Length(tuple)]");
  fi;
  result := ShallowCopy(tuple);
  left := tuple[index - 1];
  right := tuple[index];
  result[index - 1] := left * right * left^-1;
  result[index] := left;
  return result;
end;;

InverseHurwitzMove := function(tuple, index)
  local result, left, right;
  if index < 2 or index > Length(tuple) then
    Error("Hurwitz generator index must lie in [2, Length(tuple)]");
  fi;
  result := ShallowCopy(tuple);
  left := tuple[index - 1];
  right := tuple[index];
  result[index - 1] := right;
  result[index] := right^-1 * left * right;
  return result;
end;;

ApplyHurwitzWord := function(tuple, word)
  local result, letter;
  result := tuple;
  for letter in word do
    if letter > 0 then
      result := HurwitzMove(result, letter);
    else
      result := InverseHurwitzMove(result, -letter);
    fi;
  od;
  return result;
end;;

PureBraidWords4 := rec(
  beta12 := [2, 2],
  beta13 := [-2, 3, 3, 2],
  beta14 := [-2, -3, 4, 4, 3, 2]
);;

PureBraidMove4Direct := function(tuple, generator)
  local s1, s2, s3, s4;
  if Length(tuple) <> 4 then
    Error("pure B4 moves require a tuple of length 4");
  fi;
  s1 := tuple[1]; s2 := tuple[2]; s3 := tuple[3]; s4 := tuple[4];
  if generator = 12 then
    return [s1^(s3*s4), s2^(s3*s4), s3, s4];
  elif generator = 13 then
    return [s1^(s2*s4), s2, s3^(s4*s2), s4];
  elif generator = 14 then
    return [s1^(s2*s3), s2, s3, s4^(s2*s3)];
  fi;
  Error("supported pure B4 generators are 12, 13, and 14");
end;;

SimultaneousConjugate := function(tuple, element)
  return List(tuple, entry -> entry^element);
end;;

Eta23Move4 := function(tuple)
  local s1, s2, s3, s4;
  s1 := tuple[1]; s2 := tuple[2]; s3 := tuple[3]; s4 := tuple[4];
  return [s1^s2, s3, s2^(s4^-1), s4];
end;;

Eta34Move4 := function(tuple)
  local s1, s2, s3, s4;
  s1 := tuple[1]; s2 := tuple[2]; s3 := tuple[3]; s4 := tuple[4];
  return [s1^(s4^-1), s2, s4^s2, s3];
end;;

Eta234Move4 := function(tuple)
  local s1, s2, s3, s4;
  s1 := tuple[1]; s2 := tuple[2]; s3 := tuple[3]; s4 := tuple[4];
  return [s1, s3^(s2^-1), s4^(s2^-1), s2];
end;;
