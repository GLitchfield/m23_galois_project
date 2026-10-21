#!/usr/bin/env python3
from verify_koenig_m23_artifacts import polynomial_bidegree, top_level_list_length


def main() -> None:
    assert top_level_list_length("/* header */ [ [1,2], [3,[4]], [] ]") == 3
    assert polynomial_bidegree("h:=t^97*x^2 + t*x^98 + 1;") == (97, 98)
    assert polynomial_bidegree("h:=t^4\\\n 6 + x^9\\\n 8;") == (46, 98)
    print("König artifact parser checks passed")


if __name__ == "__main__":
    main()
