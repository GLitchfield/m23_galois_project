#!/usr/bin/env python3
"""Deterministic small-prime feasibility probe for the normalized 8A system."""

from __future__ import annotations

import argparse
import itertools


def trim(poly: list[int], p: int) -> list[int]:
    poly = [coefficient % p for coefficient in poly]
    while len(poly) > 1 and poly[-1] == 0:
        poly.pop()
    return poly


def add(left: list[int], right: list[int], p: int) -> list[int]:
    result = [0] * max(len(left), len(right))
    for index in range(len(result)):
        result[index] = ((left[index] if index < len(left) else 0)
                         + (right[index] if index < len(right) else 0)) % p
    return trim(result, p)


def multiply(left: list[int], right: list[int], p: int) -> list[int]:
    result = [0] * (len(left) + len(right) - 1)
    for i, a in enumerate(left):
        for j, b in enumerate(right):
            result[i + j] = (result[i + j] + a * b) % p
    return trim(result, p)


def power(poly: list[int], exponent: int, p: int) -> list[int]:
    result = [1]
    base = poly
    while exponent:
        if exponent & 1:
            result = multiply(result, base, p)
        base = multiply(base, base, p)
        exponent //= 2
    return result


def derivative(poly: list[int], p: int) -> list[int]:
    return trim([(index * poly[index]) % p for index in range(1, len(poly))] or [0], p)


def divide(numerator: list[int], denominator: list[int], p: int) -> tuple[list[int], list[int]]:
    numerator = trim(numerator[:], p)
    denominator = trim(denominator[:], p)
    if denominator == [0]:
        raise ZeroDivisionError
    quotient = [0] * max(1, len(numerator) - len(denominator) + 1)
    inverse = pow(denominator[-1], -1, p)
    while numerator != [0] and len(numerator) >= len(denominator):
        shift = len(numerator) - len(denominator)
        coefficient = numerator[-1] * inverse % p
        quotient[shift] = coefficient
        for index, value in enumerate(denominator):
            numerator[index + shift] = (numerator[index + shift] - coefficient * value) % p
        numerator = trim(numerator, p)
    return trim(quotient, p), numerator


def gcd(left: list[int], right: list[int], p: int) -> list[int]:
    left, right = trim(left, p), trim(right, p)
    while right != [0]:
        _, remainder = divide(left, right, p)
        left, right = right, remainder
    inverse = pow(left[-1], -1, p)
    return [(coefficient * inverse) % p for coefficient in left]


def squarefree(poly: list[int], p: int) -> bool:
    return len(gcd(poly, derivative(poly, p), p)) == 1


def linear(root: int, p: int) -> list[int]:
    return [(-root) % p, 1]


def probe(prime: int) -> tuple[int, int, int]:
    if prime < 3 or any(prime % divisor == 0 for divisor in range(2, int(prime**0.5) + 1)):
        raise ValueError(f"{prime} is not prime")
    raw_gcd8 = 0
    valid = 0
    tested = 0
    x4x12 = multiply(power([0, 1], 4, prime), power([-1, 1], 2, prime), prime)
    for alpha in range(1, prime):
        for a0, a1, b0, b1, c4, c2, c1 in itertools.product(range(prime), repeat=7):
            tested += 1
            a = [a0, a1, 1]
            b = [b0, b1, 1]
            if not squarefree(a, prime) or not squarefree(b, prime):
                continue
            if a0 == 0 or sum(a) % prime == 0:
                continue
            if len({c4, c2, c1}) != 3 or any(sum(coefficient * pow(c, index, prime)
                                                   for index, coefficient in enumerate(b)) % prime == 0
                                                for c in (c4, c2, c1)):
                continue
            p_poly = [(alpha * coefficient) % prime
                      for coefficient in multiply(power(a, 8, prime), x4x12, prime)]
            f_poly = power(b, 8, prime)
            for root, exponent in ((c4, 4), (c2, 2), (c1, 1)):
                f_poly = multiply(f_poly, power(linear(root, prime), exponent, prime), prime)
            if len(gcd(p_poly, f_poly, prime)) != 1:
                continue
            h = add(p_poly, f_poly, prime)
            repeated = gcd(h, derivative(h, prime), prime)
            if len(repeated) - 1 != 8:
                continue
            raw_gcd8 += 1
            if not squarefree(repeated, prime):
                continue
            quotient, remainder = divide(h, multiply(repeated, repeated, prime), prime)
            if remainder != [0] or len(quotient) - 1 != 7:
                continue
            if not squarefree(quotient, prime) or len(gcd(repeated, quotient, prime)) != 1:
                continue
            valid += 1
    return tested, raw_gcd8, valid


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prime", type=int, action="append", dest="primes")
    args = parser.parse_args()
    for prime in args.primes or [3]:
        tested, raw, valid = probe(prime)
        print(f"p={prime} tested={tested} raw_gcd8={raw} valid={valid}")


if __name__ == "__main__":
    main()
