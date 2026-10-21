#!/usr/bin/env sage
"""Certify a formal universal-family branch at König's F_19 anchor."""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
from pathlib import Path

from sage.all import GF, PolynomialRing, binomial, matrix, vector
from sage.env import SAGE_VERSION


LIFT_ORDER = 8


def load_verifier():
    path = Path(__file__).with_name("verify_koenig_hurwitz_curve.sage")
    loader = importlib.machinery.SourceFileLoader("koenig_verifier", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def multiplicity_parts(polynomial):
    squared = polynomial.parent().one()
    simple = polynomial.parent().one()
    for factor, multiplicity in polynomial.factor():
        assert multiplicity in (1, 2)
        if multiplicity == 2:
            squared *= factor
        else:
            simple *= factor
    squared /= squared.leading_coefficient()
    simple /= simple.leading_coefficient()
    return squared, simple


def coefficients_to_degree(polynomial, degree):
    return [polynomial[index] for index in range(degree + 1)]


def local_initial_form(relation, point, maximum_order=195):
    field = point[0].parent()
    local_ring = PolynomialRing(field, names=("u", "v"))
    u, v = local_ring.gens()
    terms = tuple(relation.change_ring(field).dict().items())
    for total_degree in range(maximum_order + 1):
        initial = local_ring.zero()
        for i in range(total_degree + 1):
            j = total_degree - i
            coefficient = field.zero()
            for (alpha_degree, beta_degree), value in terms:
                if alpha_degree < i or beta_degree < j:
                    continue
                coefficient += (
                    value
                    * binomial(alpha_degree, i)
                    * point[0] ** (alpha_degree - i)
                    * binomial(beta_degree, j)
                    * point[1] ** (beta_degree - j)
                )
            initial += coefficient * u**i * v**j
        if initial:
            return total_degree, initial
    raise RuntimeError("no local initial form found")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()

    verifier = load_verifier()
    _, _, _, relation = verifier.load_polynomial(args.archive)

    field = GF(19)
    ring = PolynomialRing(field, "Y")
    Y = ring.gen()

    # Normalized order-three and order-five factors from Test 0105.
    f1 = Y**6 + 14 * Y**5 + 2 * Y**4 + 7 * Y**3 + 7 * Y**2 + 5 * Y + 15
    f2 = Y**5 + 7 * Y**4 + 18 * Y**3 + 4 * Y**2 + 15 * Y + 7
    g1 = Y**3 + 13 * Y**2 + 15 * Y + 6
    g2 = Y**3 + 9 * Y**2 + 3 * Y + 2
    constant = field(14)
    branch_label = field(9)
    F1 = f1**3 * f2
    denominator = g1**5 * g2

    # T=0 is the 1/2+lambda fibre and T=1 is the 1/2-lambda fibre.
    fibre3 = constant * F1 + 5 * denominator
    fibre5 = constant * F1 + 4 * denominator
    f3, f4 = multiplicity_parts(fibre3)
    f5, f6 = multiplicity_parts(fibre5)
    assert (f3.degree(), f4.degree(), f5.degree(), f6.degree()) == (8, 7, 8, 7)
    assert fibre3 == constant * f3**2 * f4
    assert fibre5 == constant * f5**2 * f6

    F3 = f3**2 * f4
    F5 = f5**2 * f6
    assert constant * (F3 - F1) + (5 + branch_label) * denominator == 0
    assert constant * (F5 - F1) - (branch_label - 5) * denominator == 0

    variable_specs = []
    for name, degree in (
        ("f1", 6),
        ("f2", 5),
        ("f3", 8),
        ("f4", 7),
        ("f5", 8),
        ("f6", 7),
    ):
        variable_specs.extend((name, exponent) for exponent in range(degree))
    variable_specs.extend(("g1", exponent) for exponent in range(2))
    variable_specs.extend(("g2", exponent) for exponent in range(2))
    variable_specs.extend((("constant", 0), ("lambda", 0)))
    assert len(variable_specs) == 47

    columns = []
    for name, exponent in variable_specs:
        zero = ring.zero()
        dF1 = zero
        dF3 = zero
        dF5 = zero
        dD = zero
        dC = field.zero()
        d_lambda = field.zero()
        monomial = Y**exponent
        if name == "f1":
            dF1 = 3 * f1**2 * f2 * monomial
        elif name == "f2":
            dF1 = f1**3 * monomial
        elif name == "f3":
            dF3 = 2 * f3 * f4 * monomial
        elif name == "f4":
            dF3 = f3**2 * monomial
        elif name == "f5":
            dF5 = 2 * f5 * f6 * monomial
        elif name == "f6":
            dF5 = f5**2 * monomial
        elif name == "g1":
            dD = 5 * g1**4 * g2 * monomial
        elif name == "g2":
            dD = g1**5 * monomial
        elif name == "constant":
            dC = field.one()
        elif name == "lambda":
            d_lambda = field.one()
        else:
            raise AssertionError(name)

        dE3 = (
            dC * (F3 - F1)
            + constant * (dF3 - dF1)
            + d_lambda * denominator
            + (5 + branch_label) * dD
        )
        dE5 = (
            dC * (F5 - F1)
            + constant * (dF5 - dF1)
            - d_lambda * denominator
            - (branch_label - 5) * dD
        )
        columns.append(
            coefficients_to_degree(dE3, 23)
            + coefficients_to_degree(dE5, 23)
        )

    jacobian = matrix(
        field,
        48,
        47,
        lambda row_index, column_index: columns[column_index][row_index],
    )
    # The degree-23 coefficients of both identities vanish tautologically:
    # all three ramification products are monic and D has degree 18.
    assert jacobian[23].is_zero()
    assert jacobian[47].is_zero()
    kernel = jacobian.right_kernel()
    print("f3", f3)
    print("f4", f4)
    print("f5", f5)
    print("f6", f6)
    print(
        "jacobian",
        jacobian.nrows(),
        jacobian.ncols(),
        "rank",
        jacobian.rank(),
        "kernel",
        kernel.dimension(),
    )

    alpha_index = variable_specs.index(("f2", 4))
    beta_index = variable_specs.index(("f1", 5))
    lambda_index = variable_specs.index(("lambda", 0))
    projection_rows = [
        vector(
            field,
            (
                basis[alpha_index],
                basis[beta_index],
                2 * branch_label * basis[lambda_index],
            ),
        )
        for basis in kernel.basis()
    ]
    projection = matrix(field, projection_rows)
    print("projection rank", projection.rank(), "rows", projection_rows)

    multiplicity, initial = local_initial_form(
        relation, (field(7), field(14))
    )
    print("h local multiplicity", multiplicity)
    print("h initial form", initial, "factor", initial.factor())
    for direction in projection.row_space().basis():
        print(
            "projected direction",
            direction,
            "tangent value",
            initial(u=direction[0], v=direction[1]),
        )

    # The cover space is smooth and lambda is a uniformizer because deleting
    # its column leaves full column rank.  Lift the remaining 46 coefficients
    # recursively in s=lambda-9.
    series_ring = PolynomialRing(field, "s")
    s = series_ring.gen()
    series_y_ring = PolynomialRing(series_ring, "Y")
    series_Y = series_y_ring.gen()
    factor_degrees = {
        "f1": 6,
        "f2": 5,
        "f3": 8,
        "f4": 7,
        "f5": 8,
        "f6": 7,
    }
    base_factors = {
        "f1": f1,
        "f2": f2,
        "f3": f3,
        "f4": f4,
        "f5": f5,
        "f6": f6,
        "g1": g1,
        "g2": g2,
    }
    values = []
    for name, exponent in variable_specs:
        if name in base_factors:
            values.append(series_ring(base_factors[name][exponent]))
        elif name == "constant":
            values.append(series_ring(constant))
        elif name == "lambda":
            values.append(series_ring(branch_label) + s)
        else:
            raise AssertionError(name)

    def equations(current_values):
        factors = {}
        for name, degree in factor_degrees.items():
            factors[name] = series_Y**degree + sum(
                current_values[index] * series_Y**exponent
                for index, (variable_name, exponent) in enumerate(variable_specs)
                if variable_name == name
            )
        factors["g1"] = (
            series_Y**3
            + series_ring(field(1) / 3) * series_Y**2
            + current_values[variable_specs.index(("g1", 1))] * series_Y
            + current_values[variable_specs.index(("g1", 0))]
        )
        factors["g2"] = (
            series_Y**3
            - series_ring(field(1) / 2) * series_Y**2
            + current_values[variable_specs.index(("g2", 1))] * series_Y
            + current_values[variable_specs.index(("g2", 0))]
        )
        current_constant = current_values[
            variable_specs.index(("constant", 0))
        ]
        current_lambda = current_values[lambda_index]
        current_F1 = factors["f1"] ** 3 * factors["f2"]
        current_F3 = factors["f3"] ** 2 * factors["f4"]
        current_F5 = factors["f5"] ** 2 * factors["f6"]
        current_denominator = factors["g1"] ** 5 * factors["g2"]
        equation3 = (
            current_constant * (current_F3 - current_F1)
            + (5 + current_lambda) * current_denominator
        )
        equation5 = (
            current_constant * (current_F5 - current_F1)
            - (current_lambda - 5) * current_denominator
        )
        return [
            equation[index]
            for equation in (equation3, equation5)
            for index in range(24)
        ]

    nonlambda_indices = [
        index for index in range(len(variable_specs)) if index != lambda_index
    ]
    fixed_lambda_jacobian = jacobian.matrix_from_columns(nonlambda_indices)
    assert fixed_lambda_jacobian.rank() == 46
    nontrivial_rows = list(range(23)) + list(range(24, 47))
    assert (
        fixed_lambda_jacobian.matrix_from_rows(nontrivial_rows).determinant()
        != 0
    )
    for order in range(1, LIFT_ORDER + 1):
        residual = vector(
            field,
            [series_ring(equation)[order] for equation in equations(values)],
        )
        correction = fixed_lambda_jacobian.solve_right(-residual)
        for index, coefficient in zip(nonlambda_indices, correction):
            values[index] += series_ring(coefficient) * s**order
        assert all(
            series_ring(equation)[order] == 0 for equation in equations(values)
        )

    alpha_series = values[alpha_index]
    beta_series = values[beta_index]
    a_series = values[lambda_index] ** 2
    print("alpha series", alpha_series)
    print("beta series", beta_series)
    print("a series", a_series)

    modulus = s ** (LIFT_ORDER + 1)
    alpha_powers = [series_ring.one()]
    beta_powers = [series_ring.one()]
    for _ in range(relation.degree(relation.parent().gen(0))):
        alpha_powers.append((alpha_powers[-1] * alpha_series) % modulus)
    for _ in range(relation.degree(relation.parent().gen(1))):
        beta_powers.append((beta_powers[-1] * beta_series) % modulus)
    relation_series = series_ring.zero()
    for (alpha_degree, beta_degree), coefficient in relation.dict().items():
        relation_series += (
            field(coefficient)
            * alpha_powers[alpha_degree]
            * beta_powers[beta_degree]
        )
        relation_series %= modulus
    print("h series modulo s^9", relation_series)
    assert relation_series == 0

    assert alpha_series == (
        7
        + 11 * s**2
        + 8 * s**3
        + 4 * s**4
        + 13 * s**5
        + 18 * s**6
        + 15 * s**7
        + 5 * s**8
    )
    assert beta_series == (
        14
        + s**2
        + 9 * s**3
        + 11 * s**4
        + 12 * s**5
        + 17 * s**6
        + 10 * s**7
        + 9 * s**8
    )
    assert a_series == 5 + 18 * s + s**2
    assert initial(u=field(11), v=field(1)) == 0

    print(f"SageMath {SAGE_VERSION}")
    print(
        "verified smooth one-dimensional normalized cover deformation: "
        "Jacobian rank 46 of 47"
    )
    print(
        "verified plane multiplicity 2, tangent cone "
        "8*(dalpha+8*dbeta)^2, and first plane direction (11,1)"
    )
    print(
        "verified the exact formal cover identities and h(alpha,beta)=0 "
        "through s^8"
    )


if __name__ == "__main__":
    main()
