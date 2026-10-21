#!/usr/bin/env python3

from partition_native_replay import partition_rows


def main() -> None:
    assert partition_rows([(i, 1) for i in range(1, 9)], 4) == [
        (1, 2, 2),
        (3, 4, 2),
        (5, 6, 2),
        (7, 8, 2),
    ]
    assert partition_rows([(1, 8), (2, 1), (3, 1), (4, 1)], 2) == [
        (1, 1, 8),
        (2, 4, 3),
    ]
    assert partition_rows([(1, 1), (2, 8), (3, 1), (4, 1)], 3) == [
        (1, 1, 1),
        (2, 2, 8),
        (3, 4, 2),
    ]
    try:
        partition_rows([(1, 1)], 2)
    except ValueError as error:
        assert "exceed" in str(error)
    else:
        raise AssertionError("too many replay workers were accepted")
    try:
        partition_rows([(1, 1), (3, 1)], 1)
    except ValueError as error:
        assert "contiguous" in str(error)
    else:
        raise AssertionError("noncontiguous certificate IDs were accepted")
    print("native replay work partition verified")


if __name__ == "__main__":
    main()
