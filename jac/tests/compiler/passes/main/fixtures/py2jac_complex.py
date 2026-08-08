"""Fixture for py2jac complex literal conversion."""

def bare_j():
    return 1j

def bare_float_j():
    return 2.0j

def add_complex():
    return 1 + 2j

def negative_complex():
    return -1 - 2j

def complex_real_only():
    return 3 + 0j
